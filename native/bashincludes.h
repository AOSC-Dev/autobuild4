// bash includes, order sensitive
// must be included using the following order
// clang-format off
#include "builtins.h"
#include "bashansi.h"
#include "command.h"
#include "shell.h"
#include "general.h"
#include "builtins/bashgetopt.h"
#include "variables.h"
#include "builtins/common.h"
#include "builtins/builtext.h"
#include "version.h"
#if DEFAULT_COMPAT_LEVEL > 51
#include "execute_cmd.h"
#else
#include "polyfill_execute_cmd.h"
#endif
#include "config.h"
// clang-format on

// from unexported trap.h
extern int running_trap;
extern int trap_saved_exit_value;
