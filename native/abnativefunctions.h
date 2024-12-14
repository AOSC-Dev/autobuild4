#pragma once

#ifdef __cplusplus
extern "C" {
#endif

struct Logger;
extern struct Logger *logger;

void register_all_native_functions();
int register_builtin_variables();
int start_proc_00();
int dump_defines();
void disable_logger();
void set_custom_arch(const char *arch);

#ifdef __cplusplus
} // extern "C"

#include "logger.hpp"
static inline BaseLogger *get_logger() {
  return reinterpret_cast<BaseLogger *>(logger);
}
#endif
