cmake_minimum_required(VERSION 3.12)
project(autobuild VERSION 4.0.0 HOMEPAGE_URL "https://github.com/AOSC-Dev/autobuild3" LANGUAGES C CXX)

include(GNUInstallDirs)
include(CheckIncludeFile)
include(CheckIncludeFileCXX)

# find bash includes
find_path(BASH_INCLUDE NAMES bashansi.h PATH_SUFFIXES bash)
find_path(BASH_INNER_INCLUDE NAMES ansi_stdlib.h PATH_SUFFIXES bash/include)

IF("${BASH_INCLUDE}" STREQUAL "BASH_INCLUDE-NOTFOUND")
  message(FATAL_ERROR "Unable to find Bash include files")
ENDIF()

IF("${BASH_INNER_INCLUDE}" STREQUAL "BASH_INNER_INCLUDE-NOTFOUND")
  message(FATAL_ERROR "Unable to find Bash inner include files")
ENDIF()

check_include_file("elf.h" HAS_ELF_H)

if (NOT HAS_ELF_H)
  message(FATAL_ERROR "elf.h is not found in the system")
endif()

find_package(nlohmann_json 3.8 REQUIRED)
check_include_file_cxx("filesystem" HAS_STD_FS)
check_include_file_cxx("format" HAS_STD_FMT)

if (HAS_STD_FMT)
  set(CMAKE_CXX_STANDARD 20)
elseif (HAS_STD_FS)
  set(CMAKE_CXX_STANDARD 17)
else ()
  set(CMAKE_CXX_STANDARD 11)
endif()

set(CMAKE_C_STANDARD 99)
set(CMAKE_C_STANDARD_REQUIRED   YES)
set(CMAKE_CXX_STANDARD_REQUIRED YES)

if (NOT CMAKE_BUILD_TYPE STREQUAL "Debug")
  set(CMAKE_INTERPROCEDURAL_OPTIMIZATION ON)
endif()

set(COMMON_SRC
  bashincludes.h
  bashinterface.cpp
  bashinterface.hpp
  abnativefunctions.cpp
  abnativefunctions.h
  abnativeelf.cpp
  logger.hpp
  logger.cpp
  pm.hpp
  pm.cpp
  ${CMAKE_CURRENT_BINARY_DIR}/abconfig.h
)

add_custom_command(
  OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/abconfig.h
  COMMAND cmake
    -DAB_INPUT_FILE="${CMAKE_CURRENT_SOURCE_DIR}/config.h.in"
    -DAB_OUTPUT_FILE="${CMAKE_CURRENT_BINARY_DIR}/abconfig.h"
    -DAB_VERSION="${PROJECT_VERSION}"
    -DAB_URL="${PROJECT_HOMEPAGE_URL}"
    -P "${CMAKE_CURRENT_SOURCE_DIR}/GenerateConfig.cmake"
  DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/config.h.in ${CMAKE_CURRENT_SOURCE_DIR}/GenerateConfig.cmake
)

add_library(autobuild SHARED ${COMMON_SRC} autobuild.c)
target_include_directories(autobuild PRIVATE "${BASH_INCLUDE}" "${BASH_INNER_INCLUDE}" "${CMAKE_CURRENT_BINARY_DIR}")
target_link_libraries(autobuild PRIVATE nlohmann_json::nlohmann_json)
target_precompile_headers(autobuild PRIVATE $<$<COMPILE_LANGUAGE:CXX>:${CMAKE_CURRENT_SOURCE_DIR}/logger.hpp ${CMAKE_CURRENT_SOURCE_DIR}/stdwrapper.hpp>)

if (NOT HAS_STD_FS)
  message(STATUS "Target STL does not have filesystem support, falling back to Boost")
  find_package(Boost 1.72 COMPONENTS filesystem REQUIRED)
  target_link_libraries(autobuild PRIVATE Boost::filesystem)
else()
  message(STATUS "Using std::filesystem")
  target_compile_definitions(autobuild PRIVATE HAS_STD_FS)
endif()

if (NOT HAS_STD_FMT)
  message(STATUS "Target STL does not have format support, falling back to fmtlib")
  find_package(fmt 8.0.0 REQUIRED)
  target_link_libraries(autobuild PRIVATE fmt::fmt)
else()
message(STATUS "Using std::format")
  target_compile_definitions(autobuild PRIVATE HAS_STD_FMT)
endif()

set(AB_INSTALL_PREFIX "${CMAKE_INSTALL_LIBDIR}/autobuild4")
install(PROGRAMS ab4.sh DESTINATION "${CMAKE_INSTALL_BINDIR}" RENAME autobuild)
install(TARGETS autobuild LIBRARY DESTINATION "${AB_INSTALL_PREFIX}")
install(DIRECTORY filters proc qa sets templates DESTINATION "${AB_INSTALL_PREFIX}")
install(DIRECTORY etc/autobuild DESTINATION "${CMAKE_INSTALL_SYSCONFDIR}")
