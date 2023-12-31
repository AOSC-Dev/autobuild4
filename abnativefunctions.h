#pragma once

#ifdef __cplusplus
extern "C" {
#endif

struct Logger;
static struct Logger *logger = 0;

void register_all_native_functions();
void register_builtin_variables();
int start_proc_00();

#ifdef __cplusplus
} // extern "C"

#include "logger.hpp"
static inline BaseLogger *get_logger() {
  return reinterpret_cast<BaseLogger *>(logger);
}
#endif
