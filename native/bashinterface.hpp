#pragma once

#include <cstdint>
#include <memory>
#include <string>
#include <unordered_map>
#include <vector>

#include "common.hpp"

// forward declaration for word_list
typedef struct word_list WORD_LIST;
typedef int (*builtin_func_t)(WORD_LIST *);
typedef struct variable SHELL_VAR;

Diagnostic autobuild_get_backtrace();
int autobuild_bool(const char *value);
int autobuild_load_file(const char *filename, bool validate_only);
int autobuild_get_variable_with_suffix(const std::string &name,
                                       const std::vector<std::string> &aliases);
void autobuild_register_builtins(
    const std::unordered_map<const char *, builtin_func_t>& functions);
int autobuild_switch_strict_mode(const bool enable);
int autobuild_copy_variable_value(const char *src_name, const char *dst_name);
SHELL_VAR *autobuild_copy_variable(SHELL_VAR *src, const char *dst_name,
                                   bool reference = true);
int autobuild_load_all_from_directory(const char *directory);
void *autobuild_get_utility_variable(const char *name);
bool autobuild_set_utility_variable(const char *name, void *value);

class ABStrictModeGuard {
  inline ABStrictModeGuard() { autobuild_switch_strict_mode(true); }
  inline ~ABStrictModeGuard() { autobuild_switch_strict_mode(false); }
};
