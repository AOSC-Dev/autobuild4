cmake_minimum_required(VERSION 3.12)
project(simple VERSION 0.0.0 LANGUAGES C)

include(GNUInstallDirs)

file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/data.txt" "Test Data")

install(FILES "${CMAKE_CURRENT_BINARY_DIR}/data.txt" DESTINATION "${CMAKE_INSTALL_FULL_SYSCONFDIR}")
