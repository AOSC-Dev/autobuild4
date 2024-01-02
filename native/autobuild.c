#ifndef _GNU_SOURCE
#define _GNU_SOURCE 1
#endif

#ifndef _DEFAULT_SOURCE
#define _DEFAULT_SOURCE 1
#endif

#include <stdio.h>
#include <sys/prctl.h>

#include "abnativefunctions.h"
#include "bashincludes.h"

int autobuild_builtin(WORD_LIST *list) {
  int opt, rval;

  rval = EXECUTION_SUCCESS;
  prctl(PR_SET_NAME, "autobuild");

  reset_internal_getopt();
  while ((opt = internal_getopt(list, "E:")) != -1) {
    switch (opt) {
      CASE_HELPOPT;
    case 'E':
      // TODO: tools
      return 0;
    default:
      builtin_usage();
      return (EX_USAGE);
    }
  }
  list = loptend;
  if (!list) {
    return start_proc_00();
  }
  rval = EXECUTION_SUCCESS;
  return (rval);
}

/* Called when `template' is enabled and loaded from the shared object.  If this
   function returns 0, the load fails. */
int autobuild_builtin_load(char *name) {
  if (register_builtin_variables() != 0) {
    return 0;
  }
  register_all_native_functions();
  return (1);
}

void autobuild_builtin_unload(char *name) {}

char *autobuild_doc[] = {"autobuild",
                         "The next generation of autobuild for AOSC OS. \n"
                         "See GitHub wiki at AOSC-Dev/autobuild4 for "
                         "information on usage and hacking.",
                         (char *)NULL};

struct builtin autobuild_struct = {
    "autobuild",       /* builtin name */
    autobuild_builtin, /* function implementing the builtin */
    BUILTIN_ENABLED,   /* initial flags for builtin */
    autobuild_doc,     /* array of long documentation strings. */
    "autobuild",       /* usage synopsis; becomes short_doc */
    NULL               /* reserved for internal use */
};
