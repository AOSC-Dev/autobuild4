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
  SHELL_VAR **vars;

  rval = EXECUTION_SUCCESS;
  prctl(PR_SET_NAME, "autobuild");

  reset_internal_getopt();
  while ((opt = internal_getopt(list, "E:")) != -1) {
    switch (opt) {
      CASE_HELPOPT;
    case 'E':
      // TODO: other verbs
      printf("%s\n", list_optarg);
      evalstring(strdup("X=(1 2 3)\n"), "<>", 0);
      // autobuild_copy_variable(find_variable("X"), "XXX");
      evalstring(strdup("echo \"${XXX[@]}\"\n"), "<0>", 0);
      evalstring(strdup("ablog\n"), "<1>", 0);
      // parser_test("touch /root/123\n", "<builtin>");
      return 0;
      // internal_getopt(list, "i:o:");
      break;
    default:
      builtin_usage();
      return (EX_USAGE);
    }
  }
  list = loptend;
  if (!list) {
    builtin_usage();
    return (EX_USAGE);
  }
  rval = EXECUTION_SUCCESS;
  return (rval);
}

/* Called when `template' is enabled and loaded from the shared object.  If this
   function returns 0, the load fails. */
int autobuild_builtin_load(char *name) {
  register_all_native_functions();
  register_builtin_variables();
  return (1);
}

void autobuild_builtin_unload(char *name) {}

char *autobuild_doc[] = {"autobuild",
                         ""
                         "The next generation of autobuild for AOSC OS. \n"
                         "See GitHub wiki at AOSC-Dev/autobuild3 for "
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
