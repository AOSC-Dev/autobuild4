#include "unistd.h"
#include "command.h"

typedef struct variable SHELL_VAR;
extern int executing_line_number();
extern volatile int last_command_exit_value;
extern int execute_command(COMMAND *);
extern int execute_shell_function(SHELL_VAR *, WORD_LIST *);
