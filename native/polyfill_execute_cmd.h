#include "unistd.h"
#include "command.h"
extern int executing_line_number();
extern volatile int last_command_exit_value;
extern int execute_command(COMMAND *);
extern int execute_shell_function(const char *, WORD_LIST *);
