#include <fstream>
#include <memory>
#include <string>
#include <unordered_map>
#include <vector>

#include "bashinterface.hpp"
#include "common.hpp"
#include "stdwrapper.hpp"

extern "C" {
#include "bashincludes.h"
// unexported functions
extern void with_input_from_string PARAMS((char *, const char *));
extern int line_number;
extern int remember_on_history;
extern volatile int last_command_exit_value;
}

Diagnostic autobuild_get_backtrace() {
  SHELL_VAR *funcname_v, *bash_source_v, *bash_lineno_v;
  ARRAY *funcname_a, *bash_source_a, *bash_lineno_a;
  ARRAY_ELEMENT *funcname_cursor, *bash_source_cursor, *bash_lineno_cursor;
  Diagnostic diag{.level = LogLevel::Error};

  GET_ARRAY_FROM_VAR("FUNCNAME", funcname_v, funcname_a);
  GET_ARRAY_FROM_VAR("BASH_SOURCE", bash_source_v, bash_source_a);
  GET_ARRAY_FROM_VAR("BASH_LINENO", bash_lineno_v, bash_lineno_a);

  funcname_cursor = funcname_a->head;
  bash_lineno_cursor = bash_lineno_a->head;
  bash_source_cursor = bash_source_a->head;
  size_t max_depth = bash_lineno_a->num_elements + 1;
  diag.frames.reserve(max_depth);

  // printf("last error: %d\n", line_number);

  // reverse order, most recent call last
  while (bash_lineno_cursor != NULL && bash_lineno_cursor->next != NULL &&
         max_depth > 0) {
    auto lineno_str = bash_lineno_cursor->value;
    auto source_str = bash_source_cursor->value;
    auto func_str = funcname_cursor->value;
    auto lineno = lineno_str ? atoi(lineno_str) : 0;
    diag.frames.push_back({
        .file = source_str ? source_str : "",
        .function = func_str ? func_str : "",
        .line = (lineno > 0) ? static_cast<uintptr_t>(lineno) : 0,
    });

    funcname_cursor = funcname_cursor->next;
    bash_lineno_cursor = bash_lineno_cursor->next;
    bash_source_cursor = bash_source_cursor->next;
    max_depth--;
  }

  diag.message =
      "Command exited with " + std::to_string(last_command_exit_value);
  return diag;
}

void autobuild_register_builtins(
    std::unordered_map<const char *, builtin_func_t> functions) {
  // add the number for the new builtins
  size_t total_builtins = num_shell_builtins + functions.size();
  // requires one extra sentinel slot at the end
  struct builtin *new_shell_builtins = static_cast<struct builtin *>(
      calloc(total_builtins + 1, sizeof(struct builtin)));
  auto new_builtins = std::vector<struct builtin>{};
  new_builtins.reserve(functions.size() + 1);
  for (const auto &[name, function] : functions) {
    // generate the new builtin descriptor
    char *stub_doc[] = {const_cast<char *>(name), const_cast<char *>(""), NULL};
    struct builtin descriptor {
      .name = const_cast<char *>(name), .function = function,
      .flags = BUILTIN_ENABLED, .long_doc = stub_doc, .short_doc = name,
    };
    new_builtins.push_back(descriptor);
  }
  // copy the existing builtins
  memcpy(new_shell_builtins, shell_builtins,
         total_builtins * sizeof(struct builtin));
  // copy the new builtins to the end of the array
  memcpy(&(new_shell_builtins[num_shell_builtins]), new_builtins.data(),
         sizeof(struct builtin) * new_builtins.size());
  if (shell_builtins != static_shell_builtins) {
    free(shell_builtins);
  }
  // swap the pointers
  shell_builtins = new_shell_builtins;
  num_shell_builtins = total_builtins;
  initialize_shell_builtins();
}

int autobuild_bool(const char *value) {
  const size_t len = strlen(value);
  if (len == 1) {
    const unsigned char c = value[0];
    switch (c) {
    case '0':
    case 'n':
    case 'N':
    case 'f':
    case 'F':
      return 0;
    case '1':
    case 'y':
    case 'Y':
    case 't':
    case 'T':
      return 1;
    default:
      return 2;
    }
  }
  if (len == 5 && strncmp(value, "false", 5) == 0) {
    return 0;
  } else if (len == 4 && strncmp(value, "true", 4) == 0) {
    return 1;
  } else if (len == 3 && strncmp(value, "yes", 3) == 0) {
    return 1;
  } else if (len == 2 && strncmp(value, "no", 2) == 0) {
    return 0;
  }
  return 2;
}

SHELL_VAR *autobuild_copy_variable(SHELL_VAR *src, const char *dst_name) {
  constexpr int att_type_mask =
      att_array | att_function | att_integer | att_assoc;
  if (!src) {
    return {};
  }
  const int src_types = src->attributes;
  auto *dst = find_variable(dst_name);
  if (!dst) {
    if (src_types & att_array) {
      dst = make_new_array_variable((char *)dst_name);
    } else {
      dst = bind_variable(dst_name, src->name, 0);
    }
  }
  if ((src_types & att_type_mask) == (dst->attributes & att_type_mask)) {
    return {};
  }
  if (src_types & att_array) {
    ARRAY *src_cells = array_cell(src);
    ARRAY *dst_cells = array_cell(dst);
    array_flush(dst_cells);
    dst_cells = array_copy(src_cells);
    return dst;
  } else if (src_types & att_assoc) {
    HASH_TABLE *src_cells = assoc_cell(src);
    HASH_TABLE *dst_cells = assoc_cell(dst);
    assoc_flush(dst_cells);
    dst_cells = assoc_copy(src_cells);
    return dst;
  }
  const char *args[3]{"-n", dst_name, nullptr};
  auto options = std::unique_ptr<WORD_LIST, decltype(&dispose_words)>{
      strvec_to_word_list((char **)args, true, 0), &dispose_words};
  declare_builtin(options.get());
  return dst;
}

int autobuild_copy_variable_value(const char *src_name, const char *dst_name) {
  SHELL_VAR *src = find_variable(src_name);
  if (!src) {
    return 1;
  }
  SHELL_VAR *dst = autobuild_copy_variable(src, dst_name);
  if (!dst) {
    return 1;
  }
  return 0;
}

int autobuild_get_variable_with_suffix(const std::string name,
                                       const std::vector<std::string> aliases) {
  bool found = false;
  for (auto it = aliases.begin(); it != aliases.end(); it++) {
    const std::string var_name = name + "__" + *it;
    auto *target = find_variable(var_name.c_str());
    if (target) {
      if (found) {
        return 1;
      }
      autobuild_copy_variable(target, name.c_str());
      // the first element in the aliases is the arch name
      // which should be considered an exact match
      if (it == aliases.begin())
        break;
      found = true;
      continue;
    }
  }
  return 0;
}

int autobuild_load_file(const char *filename, bool validate_only) {
  if (validate_only) {
    std::ifstream file(filename);
    if (!file.is_open()) {
      return 1;
    }
    std::string input((std::istreambuf_iterator<char>(file)),
                      (std::istreambuf_iterator<char>()));
    file.close();
    return evalstring(strdup(input.c_str()), filename,
                      SEVAL_NOHIST | SEVAL_PARSEONLY);
  }
  return source_file(filename, true);
}

int autobuild_switch_strict_mode(const bool enable) {
  set_minus_o_option(enable ? '-' : '+', const_cast<char *>("errexit"));
  set_minus_o_option(enable ? '-' : '+', const_cast<char *>("errtrace"));
  const char *args[4]{"diag_print_backtrace", "ERR", "EXIT", nullptr};
  if (!enable)
    args[0] = "-";
  auto options = std::unique_ptr<WORD_LIST, decltype(&dispose_words)>{
      strvec_to_word_list((char **)args, true, 0), &dispose_words};
  return trap_builtin(options.get());
}

int autobuild_load_all_from_directory(const char *directory) {
  std::vector<std::string> files;
  for (fs::directory_iterator it(directory); it != fs::directory_iterator();
       it++) {
    if (it->is_regular_file()) {
      files.push_back(it->path().string());
    }
  }
  // list the files in the directory in alphabetical order
  // instead of the file system order
  std::sort(files.begin(), files.end());
  for (const auto &file : files) {
    if (autobuild_load_file(file.c_str(), false)) {
      return 1;
    }
  }
  return 0;
}
