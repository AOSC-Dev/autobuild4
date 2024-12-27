file(GLOB test_dirs "${CMAKE_CURRENT_SOURCE_DIR}/*/autobuild")
file(GLOB test_scripts "${CMAKE_CURRENT_SOURCE_DIR}/test-*.sh")
file(
    WRITE
    "${CMAKE_CURRENT_BINARY_DIR}/ab4.sh"
    "AB=\"${CMAKE_SOURCE_DIR}\";echo \"$PWD\";enable -f \"${CMAKE_BINARY_DIR}\"/libautobuild.so autobuild;autobuild \"$@\""
)
file(
    WRITE
    "${CMAKE_CURRENT_BINARY_DIR}/ab4-prelude.sh"
    "AB=\"${CMAKE_SOURCE_DIR}\";echo \"$PWD\";enable -f \"${CMAKE_BINARY_DIR}\"/libautobuild.so autobuild"
)
# Unit tests
foreach(script IN LISTS test_scripts)
    get_filename_component(test_script_name "${script}" NAME)
    file(COPY "${script}" DESTINATION "${CMAKE_CURRENT_BINARY_DIR}" USE_SOURCE_PERMISSIONS)
    add_test(NAME "${test_script_name}" COMMAND bash -e "${CMAKE_CURRENT_BINARY_DIR}/${test_script_name}" WORKING_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}")
endforeach()
# Integration tests
foreach(dir IN LISTS test_dirs)
    get_filename_component(test_dir_path "${dir}" DIRECTORY)
    get_filename_component(test_dir_name "${test_dir_path}" NAME)
    set(test_scratch_space "${CMAKE_CURRENT_BINARY_DIR}/${test_dir_name}")
    file(COPY "${test_dir_path}" DESTINATION "${test_scratch_space}" USE_SOURCE_PERMISSIONS)
    add_test(NAME "${test_dir_name}" COMMAND bash "${CMAKE_CURRENT_BINARY_DIR}/ab4.sh" WORKING_DIRECTORY "${test_scratch_space}/${test_dir_name}")
endforeach()
