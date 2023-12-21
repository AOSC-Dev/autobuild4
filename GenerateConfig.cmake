execute_process(
    COMMAND dpkg --print-architecture
    OUTPUT_VARIABLE AB_NATIVE_ARCH_NAME
    OUTPUT_STRIP_TRAILING_WHITESPACE
    RESULT_VARIABLE ERR_MESSAGE
)
if(ERR_MESSAGE)
    message(FATAL_ERROR "Unable to use dpkg to determine current CPU architecture: ${ERR_MESSAGE}")
endif()
set(AB_HEADER_COMMENT "This file is auto-generated")
configure_file(${AB_INPUT_FILE} ${AB_OUTPUT_FILE} @ONLY)
