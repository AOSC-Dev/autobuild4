#pragma once

struct Logger;
static struct Logger *logger = 0;

void register_all_native_functions();
void register_builtin_variables();
int start_proc_00();
