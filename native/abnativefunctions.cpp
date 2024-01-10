#include "logger.hpp"

#include "abconfig.h"
#include "abjsondata.hpp"
#include "abnativeelf.hpp"
#include "abnativefunctions.h"
#include "abserialize.hpp"
#include "bashinterface.hpp"
#include "pm.hpp"
#include "stdwrapper.hpp"
#include "threadpool.hpp"

#include <cassert>
#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <iostream>
#include <memory>
#include <random>
#include <string>
#include <unistd.h>
#include <unordered_set>

extern "C" {
#include "bashincludes.h"
}

#ifdef ALT_ARRAY_IMPLEMENTATION
#error Bash compiled with ALT_ARRAY_IMPLEMENTATION is not supported
#endif
struct Logger *logger = nullptr;

static inline void cleanup_command(COMMAND **cmd) {
  if (*cmd != nullptr) {
    dispose_command(*cmd);
  }
}

static bool set_registered_flag() {
  if (find_variable("__ABNR"))
    return true;
  auto *flag_var =
      bind_global_variable("__ABNR", const_cast<char *>("__ABNR"), ASS_FORCE);
  flag_var->attributes |= att_invisible | att_nounset | att_readonly;
  return false;
}

static inline char *get_argv1(WORD_LIST *list) {
  if (!list)
    return nullptr;
  const WORD_DESC *wd = list->word;
  if (!wd)
    return nullptr;
  return wd->word;
}

static inline std::string get_all_args(WORD_LIST *list) {
  if (!list)
    return std::string();
  std::string args{};
  args.reserve(16);
  while (list) {
    const auto *word = get_argv1(list);
    if (!word)
      continue;
    args += word;
    if (list->next)
      args += " ";
    list = list->next;
  }
  return args;
}

static inline std::vector<std::string> get_all_args_vector(WORD_LIST *list) {
  if (!list)
    return {};
  std::vector<std::string> args{};
  args.reserve(16);
  for (; list; list = list->next) {
    const auto *word = get_argv1(list);
    if (!word)
      continue;
    args.push_back(word);
  }
  return args;
}

static inline std::string get_self_path() {
  auto *path_var = find_variable("AB");
  if (!path_var) {
    return {};
  }
  const char *path = path_var->value;
  const std::string ab_path{path};
  return ab_path;
}

static inline bool set_self_path() {
  fs::path ab_path = ab_install_prefix;
  if (!fs::exists(ab_path)) {
    return false;
  }

  return bind_global_variable("AB", const_cast<char *>(ab_path.c_str()),
                              ASS_FORCE) != nullptr;
}

static inline std::string string_to_uppercase(const std::string &str) {
  std::string result{str};
  std::transform(result.begin(), result.end(), result.begin(), ::toupper);
  return result;
}

static inline std::string arch_findfile_maybe_stage2(std::string &path,
                                                     bool is_stage2) {
  auto test_path_stage2 = path + ".stage2";
  if (is_stage2 && access(test_path_stage2.c_str(), F_OK) == 0) {
    return test_path_stage2;
  }
  if (access(path.c_str(), F_OK) == 0) {
    if (is_stage2) {
      get_logger()->warning(fmt::format(
          "Unable to find stage2 {0}, falling back to normal defines ...",
          path));
    }
    return path;
  }
  return {};
}

static inline std::string arch_findfile_inner(const std::string &path,
                                              bool stage2_aware) {
  const auto defines_path = std::string{"autobuild/"};
  // find arch-specific directory first
  const auto *arch_name = find_variable("ABHOST");
  const auto *stage2_v = find_variable("ABSTAGE2");
  const bool is_stage2 =
      stage2_aware && (stage2_v ? autobuild_bool(stage2_v->value) : false);
  if (arch_name && arch_name->value) {
    auto test_path = defines_path + arch_name->value + "/" + path;
    const auto result = arch_findfile_maybe_stage2(test_path, is_stage2);
    if (!result.empty()) {
      return result;
    }
  }

  // then try the ABHOST_GROUP
  const auto *ag_v = find_variable("ABHOST_GROUP");
  if (!ag_v || !(ag_v->attributes & att_array))
    return "";
  const auto *ag_a = array_cell(ag_v);
  for (ARRAY_ELEMENT *ae = element_forw(ag_a->head); ae != ag_a->head;
       ae = element_forw(ae)) {
    auto test_path = defines_path + ae->value + "/" + path;
    const auto result = arch_findfile_maybe_stage2(test_path, is_stage2);
    // TODO: check if the group name is ambiguous
    if (!result.empty()) {
      return result;
    }
  }

  // lastly, try to find the file in the standard location
  {
    auto test_path = defines_path + path;
    const auto result = arch_findfile_maybe_stage2(test_path, is_stage2);
    if (!result.empty()) {
      return result;
    }
  }
  // not found
  return {};
}

static inline void bash_array_push(ARRAY *array, char *value) {
  auto *new_ae = array_create_element(array->num_elements, value);
  // new element is the last element of the array (tail of the linked-list)
  new_ae->prev = array->lastref;
  if (array->lastref) {
    new_ae->next = array->lastref->next;
    array->lastref->next = new_ae;
  } else {
    array->head->next = new_ae;
    new_ae->next = array->head;
  }
  array->lastref = new_ae;
  array->num_elements++;
}

static int ab_bool(WORD_LIST *list) {
  char *argv1 = get_argv1(list);
  if (!argv1)
    return 2;
  const int result = autobuild_bool(argv1);
  switch (result) {
  // bash returns 1 for false, 0 for true
  // so we need to reverse the result
  case 0:
    return 1;
  case 1:
    return 0;
  default:
    return 2;
  }
}

static int ab_isarray(WORD_LIST *list) {
  char *argv1 = get_argv1(list);
  if (!argv1)
    return 1;
  const auto *var = find_variable(argv1);
  // the return value is 0 (true in bash terms) if the variable is an array, 1
  // (false in bash terms) otherwise
  if (!var)
    return 1;
  if (var->attributes & att_array)
    return 0;
  return 1;
}

static int ab_isdefined(WORD_LIST *list) {
  char *argv1 = get_argv1(list);
  if (!argv1)
    return 1;
  const auto *var = find_variable(argv1);
  // the return value is 0 (true in bash terms) if the variable is an array, 1
  // (false in bash terms) otherwise
  // if the variable is invisible, then it's undefined as well
  if (!var || var->attributes & att_invisible)
    return 1;
  return 0;
}

static int ab_load_strict(WORD_LIST *list) {
  char *argv1 = get_argv1(list);
  if (!argv1)
    return 1;
  const int result = autobuild_load_file(argv1, true);
  if (result)
    return result;
  return autobuild_load_file(argv1, false);
}

static int ab_print_backtrace(WORD_LIST *list) {
  if (last_command_exit_value != 0) {
    get_logger()->logDiagnostic(autobuild_get_backtrace());
    return last_command_exit_value;
  }
  return 0;
}

int setup_default_env_variables() {
  if (!getenv("SHELL")) {
    char bash_path[4096]{};
    if (!readlink("/proc/self/exe", bash_path, 4096)) {
      assert("Failed to readlink /proc/self/exe");
    }
    setenv("SHELL", bash_path, true);
  }

  setenv("AB4VERSION", ab_version, true);
  // TODO: set the correct HOME variable

  setenv("TZ", "UTC", true);

  return 0;
}

int ab_filter_args(WORD_LIST *list) {
  char *argv1 = get_argv1(list);
  if (!argv1)
    return 1;
  auto to_remove = std::unordered_set<std::string>{};
  to_remove.reserve(8);
  // start with the second argument
  for (WORD_LIST *list_iter = list->next; list_iter;
       list_iter = list_iter->next) {
    char *pattern = get_argv1(list_iter);
    if (!pattern)
      continue;
    to_remove.emplace(pattern);
  }
  const auto *var = find_variable(argv1);
  // the return value is 0 (true in bash terms) if the variable is an array, 1
  // (false in bash terms) otherwise
  if (!var)
    return 1;
  if (!array_p(var))
    return 1;
  auto *var_a = array_cell(var);
  for (ARRAY_ELEMENT *ae = element_forw(var_a->head); ae != var_a->head;
       ae = element_forw(ae)) {
    if (to_remove.find(ae->value) == to_remove.end())
      continue;

    // delete the element from the array (double-linked-list)
    ae->prev->next = ae->next;
    ae->next->prev = ae->prev;
    var_a->num_elements--;

    if (ae->next != var_a->head) {
      var_a->lastref = ae->next;
    } else if (ae->prev != var_a->head) {
      var_a->lastref = ae->prev;
    } else {
      // invalidate the lastref pointer
      var_a->lastref = nullptr;
    }
    array_dispose_element(ae);
  }
  return 0;
}

constexpr const char *ab_get_current_architecture() {
  static_assert(native_arch_name && native_arch_name[0],
                "native_arch_name is undefined or empty");
  return native_arch_name;
}

static int abinfo(WORD_LIST *list) {
  const auto message = get_all_args(list);
  get_logger()->info(message);
  return 0;
}

static int abwarn(WORD_LIST *list) {
  const auto message = get_all_args(list);
  get_logger()->warning(message);
  return 0;
}

static int aberr(WORD_LIST *list) {
  const auto message = get_all_args(list);
  get_logger()->error(message);
  return 0;
}

static int abdbg(WORD_LIST *list) {
  const auto message = get_all_args(list);
  get_logger()->debug(message);
  return 0;
}

static int abdie(WORD_LIST *list) {
  const auto message = get_argv1(list);
  const auto exit_value = list ? get_argv1(list->next) : nullptr;
  const int real_exit_code =
      running_trap ? trap_saved_exit_value : last_command_exit_value;
  // do nothing if we are in a trap and the exit value is 0
  // we want to continue the execution if no errors occurred
  if (running_trap && trap_saved_exit_value == 0)
    return 0;
  const int exit_code = exit_value ? std::atoi(exit_value)
                                   : (real_exit_code ? real_exit_code : 1);

  auto *log = reinterpret_cast<BaseLogger *>(logger);

  const auto diag = autobuild_get_backtrace();
  log->logDiagnostic(diag);
  log->logException(message ? message : std::string());

  // reset the traps to avoid double-triggering
  autobuild_switch_strict_mode(false);
  exit_shell(exit_code);
  return exit_code;
}

static void register_logger_from_env() {
  auto *var = find_variable_tempenv("ABREPORTER");
  if (!var || !var->value) {
    logger = reinterpret_cast<Logger *>(new PlainLogger());
    return;
  }
  const char *reporter = var->value;
  if (strncmp(reporter, "color", 5) == 0) {
    logger = reinterpret_cast<Logger *>(new ColorfulLogger());
    return;
  } else if (strncmp(reporter, "json", 4) == 0) {
    logger = reinterpret_cast<Logger *>(new JsonLogger());
    return;
  }
  logger = reinterpret_cast<Logger *>(new PlainLogger());
}

static int set_arch_variables() {
  const std::string ab_path = get_self_path();
  if (ab_path.empty() && (!set_self_path())) {
    return 1;
  }
  // read targets
  auto map_table = jsondata_get_arch_targets(ab_path);
  auto *arch_target_var =
      make_new_assoc_variable(const_cast<char *>("ARCH_TARGET"));
  auto *arch_target_var_h = assoc_cell(arch_target_var);
  for (auto &it : map_table) {
    assoc_insert(arch_target_var_h, const_cast<char *>(it.first.c_str()),
                 const_cast<char *>(it.second.c_str()));
  }

  // set ARCH variables
  constexpr const auto this_arch = ab_get_current_architecture();
  // ARCH=$(abdetectarch)
  bind_global_variable("ARCH", const_cast<char *>(this_arch), ASS_NOEVAL);
  // ABHOST=ARCH
  bind_global_variable("ABHOST", const_cast<char *>(this_arch), ASS_NOEVAL);
  // ABBUILD=ARCH
  bind_global_variable("ABBUILD", const_cast<char *>(this_arch), ASS_NOEVAL);

  const std::string arch_triple = map_table[this_arch];
  // set HOST
  // HOST=${ARCH_TARGET["$ABHOST"]}
  bind_global_variable("HOST", const_cast<char *>(arch_triple.c_str()),
                       ASS_NOEVAL);
  // set BUILD
  // BUILD=${ARCH_TARGET["$ABBUILD"]}
  bind_global_variable("BUILD", const_cast<char *>(arch_triple.c_str()),
                       ASS_NOEVAL);

  // set ABHOST_GROUP
  auto *arch_groups_v =
      make_new_array_variable(const_cast<char *>("ABHOST_GROUP"));
  auto arch_groups_table = jsondata_get_arch_groups(ab_path, this_arch);
  auto *arch_groups_a = array_cell(arch_groups_v);
  for (auto &it : arch_groups_table) {
    bash_array_push(arch_groups_a, const_cast<char *>(it.c_str()));
  }

  return 0;
}

static inline int arch_loadvar_inner(const std::string &var_name) {
  std::vector<std::string> aliases{};
  aliases.reserve(4);
  const auto arch_v = find_variable("ARCH");
  // ARCH can't be an array
  if (!arch_v || arch_v->attributes & att_array)
    return 1;
  const auto ag_v = find_variable("ABHOST_GROUP");
  // ABHOST_GROUP needs to be an array
  if (!ag_v || !(ag_v->attributes & att_array))
    return 1;
  aliases.emplace_back(string_to_uppercase(arch_v->value));
  const auto ag_a = array_cell(ag_v);
  for (ARRAY_ELEMENT *ae = element_forw(ag_a->head); ae != ag_a->head;
       ae = element_forw(ae)) {
    aliases.emplace_back(string_to_uppercase(ae->value));
  }

  const int result = autobuild_get_variable_with_suffix(var_name, aliases);
  if (result != 0) {
    const auto logger = get_logger();
    logger->error(fmt::format(
        "Refusing to assign {0} to group-specific variable {0}__{1}\n"
        "... because it is already assigned to {0}__{2}",
        var_name, aliases[2], aliases[1]));
    logger->info(
        fmt::format("Current ABHOST {0} belongs to the following groups:",
                    ab_get_current_architecture()));
    logger->info(fmt::format(
        "Add the more specific {0}__{1} instead to suppress the conflict.",
        var_name, string_to_uppercase(ab_get_current_architecture())));
    logger->logException(
        "Ambiguous architecture group variable detected! Refuse to proceed.");
    return 1;
  }
  return 0;
}

static int arch_loadvar(WORD_LIST *list) {
  const auto name = get_argv1(list);
  if (!name)
    return 0;
  arch_loadvar_inner(name);

  return 0;
}

static int arch_loaddefines(WORD_LIST *list) {
  // parse args
  int opt = 0;
  bool stage2_aware = false;
  reset_internal_getopt();
  while ((opt = internal_getopt(list, const_cast<char *>("2"))) != -1) {
    switch (opt) {
    case '2':
      stage2_aware = true;
      break;
    default:
      return 1;
    }
  }
  const auto *argv1 = get_argv1(loptend);
  if (!argv1)
    return 1;

  // load exported variables list
  const std::string ab_path = get_self_path();
  if (ab_path.empty()) {
    return 1;
  }
  std::vector<std::string> exported_vars = jsondata_get_exported_vars(ab_path);

  // load the defines file
  const auto defines_path = arch_findfile_inner(argv1, stage2_aware);
  if (defines_path.empty())
    return 127;
  const int result = autobuild_load_file(defines_path.c_str(), false);
  if (result != 0)
    return result;
  // load the actual variables from the current context
  for (const auto &var : exported_vars) {
    arch_loadvar_inner(var);
  }
  return 0;
}

static int arch_loadfile_strict(WORD_LIST *list) {
  // parse args
  int opt = 0;
  bool stage2_aware = false;
  reset_internal_getopt();
  while ((opt = internal_getopt(list, const_cast<char *>("2"))) != -1) {
    switch (opt) {
    case '2':
      stage2_aware = true;
      break;
    default:
      return 1;
    }
  }
  const auto *argv1 = get_argv1(loptend);
  if (!argv1)
    return 1;
  const auto filepath = arch_findfile_inner(argv1, stage2_aware);
  if (filepath.empty())
    return 127;
  return autobuild_load_file(filepath.c_str(), false);
}

static int arch_loadfile(WORD_LIST *list) {
  auto *log = reinterpret_cast<BaseLogger *>(logger);
  log->warning(
      "arch_loadfile is deprecated. Use arch_loadfile_strict instead.");
  return arch_loadfile_strict(list);
}

static int ab_read_listing_file(WORD_LIST *list) {
  const auto *filename = get_argv1(list);
  if (!filename)
    return 1;
  auto *result_varname = get_argv1(list->next);
  if (!result_varname)
    return 1;

  auto file = std::ifstream(filename);
  if (!file.is_open())
    return 1;
  std::string line;
  std::vector<std::string> lines{};
  while (std::getline(file, line)) {
    // TODO: trim whitespaces
    if (line.front() == '#')
      continue;
    lines.emplace_back(line);
  }
  file.close();
  const auto *result_var = make_new_array_variable(result_varname);
  auto *result_var_a = array_cell(result_var);
  for (const auto &line : lines) {
    bash_array_push(result_var_a, const_cast<char *>(line.c_str()));
  }
  return 0;
}

static int ab_tostringarray(WORD_LIST *list) {
  const auto *varname = get_argv1(list);
  if (!varname)
    return 1;

  auto *result_var = find_variable(varname);
  if (!result_var)
    return 1;
  // already an array, nothing to do
  if (result_var->attributes & att_array)
    return 0;
  // FIXME: does not work for assoc vars
  if (result_var->attributes & att_assoc)
    return 4;

  // convert the string to an array
  // save the string value first
  auto oldval =
      std::unique_ptr<char, decltype(&free)>(strdup(result_var->value), &free);
  free(result_var->value);
  // override the value to an array
  result_var->value = reinterpret_cast<char *>(array_create());
  // override the attributes to be an array type
  result_var->attributes |= att_array;
  // split the string into array elements
  assign_array_var_from_string(result_var, oldval.get(), 0);
  return 0;
}

static int abcopyvar(WORD_LIST *list) {
  const auto *src = get_argv1(list);
  if (!src)
    return 1;
  const auto *dst = get_argv1(list->next);
  if (!dst)
    return 1;
  // TODO: handle errors
  return autobuild_copy_variable_value(src, dst);
}

static int arch_findfile(WORD_LIST *list) {
  // parse args
  int opt = 0;
  bool stage2_aware = false;
  reset_internal_getopt();
  while ((opt = internal_getopt(list, const_cast<char *>("2"))) != -1) {
    switch (opt) {
    case '2':
      stage2_aware = true;
      break;
    default:
      return 1;
    }
  }
  const auto *argv1 = get_argv1(loptend);
  if (!argv1)
    return EX_BADUSAGE;
  const auto *out_varname = get_argv1(loptend->next);
  const auto filepath = arch_findfile_inner(argv1, stage2_aware);
  if (filepath.empty())
    return 127;
  // check only mode
  if (!out_varname)
    return 0;
  const auto *out_var = bind_variable(
      out_varname, const_cast<char *>(filepath.c_str()), ASS_FORCE);
  if (!out_var)
    return EX_BADASSIGN;
  return 0;
}

static int ab_concatarray(WORD_LIST *list) {
  const auto *dst = get_argv1(list);
  if (!dst)
    return 1;
  const auto *dst_v = find_variable(dst);
  if (!dst_v || !(dst_v->attributes & att_array))
    return 1;
  const auto *src = get_argv1(list->next);
  if (!src)
    return 1;
  const auto *src_v = find_variable(src);
  if (!src_v || !(src_v->attributes & att_array))
    return 1;
  auto *dst_a = array_cell(dst_v);
  const auto *src_a = array_cell(src_v);
  for (ARRAY_ELEMENT *ae = element_forw(src_a->head); ae != src_a->head;
       ae = element_forw(ae)) {
    bash_array_push(dst_a, ae->value);
  }
  return 0;
}

static int ab_typecheck(WORD_LIST *list) {
  int opt{};
  int expected_type = 0;
  reset_internal_getopt();
  while ((opt = internal_getopt(list, const_cast<char *>("ahsif"))) != -1) {
    switch (opt) {
    case 'a':
      expected_type |= att_array;
      break;
    case 'h':
      expected_type |= att_assoc;
      break;
    case 's':
      expected_type |= 0;
      break;
    case 'i':
      expected_type |= att_integer;
      break;
    case 'f':
      expected_type |= att_function;
      break;
    default:
      return 1;
    }
  }

  const auto *varname = get_argv1(loptend);
  if (!varname)
    return 1;
  auto *var = find_variable(varname);
  if (!var) {
    // find the name in the function context
    var = find_function(varname);
  }
  if (!var)
    return 1;
  if (var->attributes & expected_type)
    return 0;
  return 1;
}

static int abpm_dump_builddep_req(WORD_LIST *list) {
  std::mt19937_64 rng(std::random_device{}());
  std::cout << fmt::format("Source: ab4-satdep-{}\nBuild-Depends:\n", rng());
  for (; list != nullptr; list = list->next) {
    const auto converted = autobuild_to_deb_version(list->word->word);
    if (converted.empty()) {
      return 1;
    }
    std::cout << " " << converted << ",\n";
  }
  return 0;
}

static int abpm_genver(WORD_LIST *list) {
  const auto argv1 = get_argv1(list);
  if (!argv1)
    return EX_BADUSAGE;
  std::cout << autobuild_to_deb_version(argv1);
  return 0;
}

static int abelf_elf_copy_to_symdir(WORD_LIST *list) {
  const auto *src = get_argv1(list);
  if (!src)
    return EX_BADUSAGE;
  WORD_LIST *lists = list->next;
  const auto *buildid = get_argv1(lists);
  if (!buildid)
    return EX_BADUSAGE;
  lists = lists->next;
  const auto *symdir = get_argv1(lists);
  if (!symdir)
    return EX_BADUSAGE;

  return elf_copy_to_symdir(src, symdir, buildid);
}

static int abelf_copy_dbg(WORD_LIST *list) {
  const auto *src = get_argv1(list);
  if (!src)
    return EX_BADUSAGE;
  WORD_LIST *lists = list->next;
  const auto *dst = get_argv1(lists);
  if (!dst)
    return EX_BADUSAGE;
  GuardedSet<std::string> symbols{};
  int ret = elf_copy_debug_symbols(src, dst, AB_ELF_USE_EU_STRIP, symbols);
  if (ret < 0)
    return 10;
  return 0;
}

static int abelf_copy_dbg_parallel(WORD_LIST *list) {
  constexpr const char *varname = "__AB_SO_DEPS";
  int flags = AB_ELF_FIND_SO_DEPS;

  reset_internal_getopt();
  int opt = 0;
  while ((opt = internal_getopt(list, const_cast<char *>("exr"))) != -1) {
    switch (opt) {
    case 'x':
      flags |= AB_ELF_STRIP_ONLY;
      break;
    case 'r':
      flags |= AB_ELF_CHECK_ONLY;
      break;
    case 'e':
      flags |= AB_ELF_USE_EU_STRIP;
      break;
    default:
      return 1;
    }
  }

  auto args = get_all_args_vector(loptend);
  if (args.empty())
    return EX_BADUSAGE;
  const auto dst = args.erase(args.end() - 1);
  std::unordered_set<std::string> so_deps{};
  int ret = elf_copy_debug_symbols_parallel(args, dst->c_str(), so_deps, flags);
  if (ret < 0)
    return 10;
  // copy the data to the bash variable
  auto *var = make_new_array_variable(const_cast<char *>(varname));
  var->attributes |= att_readonly;
  auto *var_a = array_cell(var);
  for (const auto &so_dep : so_deps) {
    array_push(var_a, const_cast<char *>(so_dep.c_str()));
  }
  return 0;
}

static int abpm_aosc_archive(WORD_LIST *list) {
  const auto *package_name = get_argv1(list);
  if (!package_name)
    return 1;
  list = list->next;
  const auto *version = get_argv1(list);
  if (!version)
    return 1;
  list = list->next;
  const auto *release = get_argv1(list);
  if (!release)
    return 1;
  list = list->next;
  const auto *arch = get_argv1(list);
  if (!arch)
    return 1;

  fs::path path{"/debs"};
  const std::string package_name_str{package_name};
  const std::string package_filename =
      fmt::format("{0}_{1}_{2}_{3}.deb", package_name, version, release, arch);
  std::string prefix{package_name[0]};
  if (package_name_str.size() > 3 && package_name_str.substr(0, 3) == "lib") {
    prefix = package_name_str.substr(0, 4);
  }
  path /= prefix;
  fs::create_directories(path);
  path /= package_filename;
  fs::copy(package_filename, path, fs::copy_options::overwrite_existing);
  std::cout << fmt::format("'{0}' -> '{1}'", package_filename, path.string())
            << std::endl;
  return 0;
}

static int abpm_aosc_archive_new(WORD_LIST *list) {
  const auto *packages = get_argv1(list);
  if (!packages)
    return 1;
  const auto *packages_v = find_variable(packages);
  if (!packages_v || !(packages_v->attributes & att_array))
    return 1;
  const auto *packages_a = array_cell(packages_v);
  for (ARRAY_ELEMENT *ae = element_forw(packages_a->head);
       ae != packages_a->head; ae = element_forw(ae)) {
    // each element is a package name
    char *package_name = ae->value;
    const std::string package_name_str{package_name};
    std::string prefix{package_name[0]};
    if (package_name_str.size() > 3 && package_name_str.substr(0, 3) == "lib") {
      prefix = package_name_str.substr(0, 4);
    }
    fs::path path{"/debs"};
    path /= prefix;
    fs::create_directories(path);
    path /= package_name;
    fs::copy(package_name, path, fs::copy_options::overwrite_existing);
    std::cout << fmt::format("'{0}' -> '{1}'", package_name, path.string())
              << std::endl;
  }
  return 0;
}

static inline COMMAND *generate_function_call(char *name, char *arg) {
  char *args[] = {name, arg, nullptr};
  WORD_LIST *list = strvec_to_word_list(static_cast<char **>(args), true, 0);
  SIMPLE_COM *conn = (SIMPLE_COM *)calloc(1, sizeof(SIMPLE_COM));
  *conn = SIMPLE_COM{
      .flags = 0,
      .line = 0,
      .words = list,
      .redirects = nullptr,
  };
  COMMAND *command = (COMMAND *)calloc(1, sizeof(COMMAND));
  *command = COMMAND{
      .type = cm_simple,
      .flags = 0,
      .redirects = nullptr,
      .value = {.Simple = conn},
  };
  return command;
}

class ShellThreadPool : public ThreadPool<char *, int> {
public:
  ShellThreadPool(char *func_name)
      : ThreadPool<char *, int>([&](auto arg) {
          COMMAND *call = generate_function_call(func_name_, arg);
          return execute_command(call);
        }),
        func_name_(func_name) {}

private:
  char *func_name_;
};

static int abpp_parallelize(WORD_LIST *list) {
  auto *src = get_argv1(list);
  if (!src)
    return 1;
  SHELL_VAR *var = find_function(src);
  if (!var || !(var->attributes & att_function)) {
    return 1;
  }
  // protect the variable from being unset
  var->attributes |= (att_nounset | att_readonly);
  ShellThreadPool thread_pool(src);
  for (list = list->next; list; list = list->next) {
    thread_pool.enqueue(get_argv1(list));
  }

  if (thread_pool.has_error())
    return 1;

  return 0;
}

static std::mutex ab_gil{};

static int abpp_gil(WORD_LIST *list) {
  constexpr WORD_LIST empty_list{};
  const auto *func_name = get_argv1(list);
  if (!func_name)
    return EX_BADUSAGE;
  SHELL_VAR *func_v = find_function(func_name);
  if (!func_v)
    return EX_BADSYNTAX;
  const auto *func_f = function_cell(func_v);
  if (!func_f)
    return EX_BADSYNTAX;
  auto *args = list->next;
  if (!args)
    args = const_cast<WORD_LIST *>(&empty_list);
  // protect the context using GIL
  std::lock_guard<std::mutex> gil_guard{ab_gil};
  return execute_shell_function(func_v, args);
}

struct abfp_lambda_env {
  uint8_t magic0;
  uint8_t magic1;
  uint8_t magic2;
  uint8_t zero;
  std::vector<SHELL_VAR *> *vars;
};

static int abfp_lambda_restore(WORD_LIST *list) {
  const auto *env_name = get_argv1(list);
  if (!env_name)
    return EX_BADUSAGE;
  auto *env_ptr_var = find_global_variable(env_name);
  if (!env_ptr_var || !(env_ptr_var->attributes & att_special)) {
    return EX_BADUSAGE;
  }
  auto *env_ptr = reinterpret_cast<abfp_lambda_env *>(env_ptr_var->value);
  if (env_ptr->magic0 != 'E' || env_ptr->magic1 != 'N' ||
      env_ptr->magic2 != 'V' || env_ptr->zero != 0x00) {
    return EX_BADASSIGN;
  }
  // find current context (from variables.c:all_local_variables)
  VAR_CONTEXT *vc;
  for (vc = shell_variables; vc != nullptr; vc = vc->down) {
    if (vc_isfuncenv(vc) && vc->scope == variable_context) {
      break;
    }
  }
  if (vc == nullptr) {
    return EX_BADASSIGN;
  }
  // move variables from env_ptr to current context
  for (auto *var : *env_ptr->vars) {
    var->context = variable_context;
    var->attributes |= att_local;
    if (!shell_variables->table)
      shell_variables->table = hash_create(4);
    BUCKET_CONTENTS *elem =
        hash_insert(strdup(var->name), shell_variables->table, HASH_NOSRCH);
    elem->data = var;
  }
  // clean up the storage variable
  delete env_ptr->vars;
  delete env_ptr;
  env_ptr_var->value = nullptr;
  env_ptr_var->attributes |= att_nofree;
  env_ptr_var->attributes &= ~att_nounset;
  unbind_variable(env_name);
  env_ptr_var = nullptr;

  return 0;
}

static int abfp_lambda(WORD_LIST *list) {
  constexpr const char *tmp_var_name = "__abfp_lambda_tmp_var__";
  const auto *orig_func_name = get_argv1(list);
  if (!orig_func_name)
    return EX_BADUSAGE;
  auto *orig_func = find_function(orig_func_name);
  if (!orig_func || !(orig_func->attributes & att_function)) {
    return EX_BADUSAGE;
  }
  list = list->next;
  const auto *new_func_name = get_argv1(list);
  if (!new_func_name)
    return EX_BADUSAGE;
  auto *orig_func_f = function_cell(orig_func);
  auto *vars = new std::vector<SHELL_VAR *>{};
  for (list = list->next; list; list = list->next) {
    const auto captured = get_argv1(list);
    if (!captured)
      continue;
    if (memcmp(captured, "--", 2) == 0) {
      continue;
    }
    auto *captured_var = find_variable(captured);
    auto *copied = autobuild_copy_variable(captured_var, tmp_var_name, false);
    if (!copied) {
      delete vars;
      return EX_BADASSIGN;
    }
    SHELL_VAR *recreated = (SHELL_VAR *)calloc(1, sizeof(SHELL_VAR));
    recreated->name = strdup(captured);
    recreated->value = copied->value;
    recreated->attributes = copied->attributes;
    // disconnect the variable from the scope
    copied->attributes |= att_nofree;
    unbind_variable(tmp_var_name);
    vars->push_back(recreated);
  }

  abfp_lambda_env *env = new abfp_lambda_env{
      .magic0 = 'E',
      .magic1 = 'N',
      .magic2 = 'V',
      .zero = 0x00,
      .vars = vars,
  };
  std::mt19937_64 rng(std::random_device{}());
  const std::string env_name = fmt::format("__abfp_env__{:2x}", rng());
  char *env_name_str = const_cast<char *>(env_name.c_str());
  auto *env_ptr_var = bind_global_variable(env_name_str, nullptr, 0);
  env_ptr_var->value = reinterpret_cast<char *>(env);
  env_ptr_var->attributes |= (att_special | att_readonly | att_nounset);

  // patch in a new function call at the function prologue
  COMMAND *retore_call = generate_function_call(
      const_cast<char *>("abfp_lambda_restore"), env_name_str);
  CONNECTION *conn = (CONNECTION *)calloc(1, sizeof(CONNECTION));
  conn->first = retore_call;
  conn->second = orig_func_f;
  conn->connector = ';';
  __attribute__((cleanup(cleanup_command))) COMMAND *connector =
      (COMMAND *)calloc(1, sizeof(COMMAND));
  connector->type = cm_connection;
  connector->flags = 0;
  connector->redirects = nullptr;
  connector->value = {.Connection = conn};

  // null the original function to avoid `COMMAND`s getting freed
  orig_func->value = nullptr;
  unbind_func(orig_func_name);
  bind_function(new_func_name, connector);
  return 0;
}

static int abmm_array_mine(WORD_LIST *list) {
  const auto *array_name = get_argv1(list);
  if (!array_name)
    return EX_BADUSAGE;
  auto *array_var = find_variable(array_name);
  if (!array_var || !(array_var->attributes & att_array)) {
    return EX_BADUSAGE;
  }
  auto *array = array_cell(array_var);
  if (array->num_elements < 1)
    return EX_BADASSIGN;
  auto *trip_mine = array_create_element(
      0, const_cast<char *>("---PLEASE_MIGRATE_TO_ARRAY---"));
  // we create an intentionally broken reference to trip_mine
  // so bash will break when it tries to convert it to a string
  array->lastref = trip_mine;
  trip_mine->next = array->head;
  return 0;
}

static int abmm_array_mine_remove(WORD_LIST *list) {
  const auto *array_name = get_argv1(list);
  if (!array_name)
    return EX_BADUSAGE;
  auto *array_var = find_variable(array_name);
  if (!array_var || !(array_var->attributes & att_array)) {
    return EX_BADUSAGE;
  }
  auto *array = array_cell(array_var);
  if (array->num_elements < 1)
    return EX_BADASSIGN;
  auto *trip_mine = array->lastref;
  array->lastref = trip_mine->next;
  trip_mine->next = nullptr;
  array_dispose_element(trip_mine);
  return 0;
}

static int ab_join_elements(WORD_LIST *list) {
  const auto *array_name = get_argv1(list);
  if (!array_name)
    return EX_BADUSAGE;
  list = list->next;
  const auto *sep_ = get_argv1(list);
  if (!sep_)
    return EX_BADUSAGE;
  auto *array_var = find_variable(array_name);
  if (!array_var || !(array_var->attributes & att_array)) {
    return EX_BADUSAGE;
  }
  auto *array = array_cell(array_var);
  for (ARRAY_ELEMENT *ae = element_forw(array->head); ae != array->head;
       ae = element_forw(ae)) {
    if (array->head == element_forw(ae)) {
      printf("%s", ae->value);
      continue;
    }
    printf("%s%s", ae->value, sep_);
  }
  return 0;
}

static int ab_parse_set_modifiers(WORD_LIST *list) {
  // accepts no arguments
  // accepted modifiers (as of now) are:
  // STAGE2 PKGBREAK
  const char *modifiers_string = getenv("ABMODIFIERS");
  if (!modifiers_string)
    return 0;
  struct ab_modifier {
    std::string name;
    bool enabled;
  };
  std::vector<ab_modifier> modifiers;
  uint8_t state = 0;
  std::string modifier_name{};
  for (const char *modifier = modifiers_string; *modifier; modifier++) {
    switch (*modifier) {
    case '+':
      state = 1;
      continue;
    case '-':
      state = 2;
      continue;
    default:
      break;
    }
    if (state == 0) {
      return EX_BADASSIGN;
    }
    if (*modifier == ',') {
      if (modifier_name.empty()) {
        return EX_BADASSIGN;
      }
      modifiers.push_back(
          {std::move(modifier_name), state == 1 ? true : false});
      modifier_name.clear();
      state = 0;
      continue;
    }
    modifier_name.push_back(*modifier);
  }
  // last element:
  if (!modifier_name.empty()) {
    modifiers.push_back({modifier_name, state == 1 ? true : false});
  }

  SHELL_VAR *hash_var =
      make_new_assoc_variable(const_cast<char *>("__ABMODIFIERS"));
  if (!hash_var)
    assert("Unable to allocate memory for __ABMODIFIERS");
  hash_var->attributes |= (att_readonly | att_nofree | att_nounset);
  auto *hash = assoc_cell(hash_var);
  auto *logger = get_logger();
  for (const auto &modifier : modifiers) {
    const std::string name = string_to_uppercase(modifier.name);
    logger->info(
        fmt::format("Setting modifier {0} to {1}", name, modifier.enabled));
    if (name == "STAGE2" && modifier.enabled) {
      // compatibility with old versions of autobuild
      setenv("ABSTAGE2", "1", 1);
    }
    auto *elem = hash_insert(strdup(name.c_str()), hash, 0);
    elem->data = (char *)(modifier.enabled ? "1" : "0");
  }
  return 0;
}

static int ab_dump_variables(const std::vector<std::string> &names) {
  std::cout << autobuild_serialized_variables(names) << std::endl;
  return 0;
}

extern "C" {
void register_all_native_functions() {
  if (set_registered_flag())
    return;
  const std::unordered_map<const char *, builtin_func_t> functions{
      {"bool", ab_bool},
      {"abisarray", ab_isarray},
      {"abisdefined", ab_isdefined},
      {"load_strict", ab_load_strict},
      {"diag_print_backtrace", ab_print_backtrace},
      // previously in base.sh
      {"abinfo", abinfo},
      {"abwarn", abwarn},
      {"aberr", aberr},
      {"abdbg", abdbg},
      {"abdie", abdie},
      // previously in arch.sh
      {"arch_loadvar", arch_loadvar},
      {"arch_loaddefines", arch_loaddefines},
      {"arch_loadfile", arch_loadfile},
      {"arch_loadfile_strict", arch_loadfile_strict},
      {"arch_findfile", arch_findfile},
      {"abcopyvar", abcopyvar},
      {"ab_concatarray", ab_concatarray},
      // previously in elf.sh
      {"elf_install_symfile", abelf_elf_copy_to_symdir},
      {"elf_copydbg", abelf_copy_dbg},
      // new stuff
      {"autobuild-aoscarchive", abpm_aosc_archive},
      {"ab_remove_args", ab_filter_args},
      {"ab_read_list", ab_read_listing_file},
      {"ab_tostringarray", ab_tostringarray},
      {"ab_typecheck", ab_typecheck},
      {"ab_join_elements", ab_join_elements},
      {"ab_parse_set_modifiers", ab_parse_set_modifiers},
      {"abelf_copy_dbg_parallel", abelf_copy_dbg_parallel},
      {"abpm_aosc_archive", abpm_aosc_archive_new},
      {"abpm_debver", abpm_genver},
      {"abpm_dump_builddep_req", abpm_dump_builddep_req},
      {"abpp_parallelize", abpp_parallelize},
      {"abpp_gil", abpp_gil},
      {"abfp_lambda", abfp_lambda},
      {"abfp_lambda_restore", abfp_lambda_restore},
      {"abmm_array_mine", abmm_array_mine},
      {"abmm_array_mine_remove", abmm_array_mine_remove}};

  // Initialize logger
  if (!logger)
    register_logger_from_env();

  autobuild_register_builtins(functions);
}

int register_builtin_variables() {
  int ret = 0;
  // Initialize logger
  if (!logger)
    register_logger_from_env();
  if ((ret = setup_default_env_variables())) {
    get_logger()->error(
        fmt::format("Failed to setup default env variables: {0}", ret));
    return ret;
  }
  if ((ret = set_arch_variables())) {
    get_logger()->error(fmt::format(
        "Failed to setup default architecture variables: {0}", ret));
    return ret;
  }
  return 0;
}

int start_proc_00() {
  autobuild_switch_strict_mode(true);
  const std::string self_path = get_self_path() + "/proc";
  return autobuild_load_all_from_directory(self_path.c_str());
}

int dump_defines() {
  const std::vector<std::string> names =
      jsondata_get_exported_vars(get_self_path());
  constexpr const char *precond_scripts[] = {"00-python-defines.sh",
                                             "01-core-defines.sh"};
  for (const auto &script : precond_scripts) {
    const std::string path = get_self_path() + "/proc/" + script;
    const int ret = autobuild_load_file(path.c_str(), false);
    if (ret != 0) {
      get_logger()->error(fmt::format("Failed to load {0}: {1}", path, ret));
      return ret;
    }
  }
  return ab_dump_variables(names);
}
} // extern "C"
