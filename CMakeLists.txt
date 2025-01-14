cmake_minimum_required(VERSION 3.12)
project(autobuild VERSION 4.7.7 HOMEPAGE_URL "https://github.com/AOSC-Dev/autobuild4" LANGUAGES C CXX)

include(GNUInstallDirs)
include(CheckTypeSize)

option(AB4_REGENERATE_SPRIAL_DATA "Whether to re-generate Autobuild Spiral (Debian/Ubuntu) compatibility data" OFF)

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
set(CMAKE_EXTRA_INCLUDE_FILES format)
set(CMAKE_REQUIRED_FLAGS "-std=c++20")
check_type_size("std::format_error" STD_FMT LANGUAGE CXX)
set(CMAKE_REQUIRED_FLAGS "-std=c++17")
set(CMAKE_EXTRA_INCLUDE_FILES filesystem)
check_type_size("std::filesystem::path" STD_FS LANGUAGE CXX)

find_package(PkgConfig)
pkg_check_modules(LIBELF libelf)

if (HAVE_STD_FMT)
  set(CMAKE_CXX_STANDARD 20)
elseif (HAVE_STD_FS)
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
  native/bashincludes.h
  native/bashinterface.cpp
  native/bashinterface.hpp
  native/abnativefunctions.cpp
  native/abnativefunctions.h
  native/abnativeelf.cpp
  native/abjsondata.cpp
  native/abjsondata.hpp
  native/abserialize.cpp
  native/abserialize.hpp
  native/abspiral.cpp
  native/abspiral.hpp
  native/abspiral_data.cpp
  native/logger.hpp
  native/logger.cpp
  native/pm.hpp
  native/pm.cpp
  ${CMAKE_CURRENT_BINARY_DIR}/abconfig.h
)
set_property(SOURCE native/abspiral_data.cpp APPEND PROPERTY OBJECT_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/data/lut_sonames.cpp.inc")

set(AB_INSTALL_PREFIX "${CMAKE_INSTALL_FULL_LIBDIR}/autobuild4")

add_custom_command(
  OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/abconfig.h
  COMMAND cmake
    -DAB_INPUT_FILE="${CMAKE_CURRENT_SOURCE_DIR}/config.h.in"
    -DAB_OUTPUT_FILE="${CMAKE_CURRENT_BINARY_DIR}/abconfig.h"
    -DAB_VERSION="${PROJECT_VERSION}"
    -DAB_URL="${PROJECT_HOMEPAGE_URL}"
    -DAB_INSTALL_PREFIX="${AB_INSTALL_PREFIX}"
    -P "${CMAKE_CURRENT_SOURCE_DIR}/cmake/GenerateConfig.cmake"
  DEPENDS
    ${CMAKE_CURRENT_SOURCE_DIR}/config.h.in
    ${CMAKE_CURRENT_SOURCE_DIR}/cmake/GenerateConfig.cmake
)

set(SPRIAL_DATA_FILE "${CMAKE_CURRENT_SOURCE_DIR}/data/lut_sonames.cpp.inc")
if (AB4_REGENERATE_SPRIAL_DATA)
  find_package(Python3 COMPONENTS Interpreter REQUIRED)
  add_custom_command(
    OUTPUT "${SPRIAL_DATA_FILE}"
    COMMAND "${Python3_EXECUTABLE}"
      "${CMAKE_CURRENT_SOURCE_DIR}/build_spiral_lut.py"
    DEPENDS
      "${CMAKE_CURRENT_SOURCE_DIR}/build_spiral_lut.py"
  )
endif()

add_library(autobuild SHARED ${COMMON_SRC} native/autobuild.c)
target_include_directories(autobuild PRIVATE "${BASH_INCLUDE}" "${BASH_INNER_INCLUDE}" "${CMAKE_CURRENT_BINARY_DIR}")
target_link_libraries(autobuild PRIVATE nlohmann_json::nlohmann_json)
target_precompile_headers(autobuild PRIVATE
  $<$<COMPILE_LANGUAGE:CXX>:${CMAKE_CURRENT_SOURCE_DIR}/native/logger.hpp
  ${CMAKE_CURRENT_SOURCE_DIR}/native/stdwrapper.hpp>
)

if (NOT HAVE_STD_FS)
  message(STATUS "Target STL does not have filesystem support, falling back to Boost")
  find_package(Boost 1.72 COMPONENTS filesystem REQUIRED)
  target_link_libraries(autobuild PRIVATE Boost::filesystem)
else()
  message(STATUS "Using std::filesystem")
  target_compile_definitions(autobuild PRIVATE HAS_STD_FS)
endif()

if (NOT HAVE_STD_FMT)
  message(STATUS "Target STL does not have format support, falling back to fmtlib")
  find_package(fmt 8.0.0 REQUIRED)
  target_link_libraries(autobuild PRIVATE fmt::fmt)
else()
message(STATUS "Using std::format")
  target_compile_definitions(autobuild PRIVATE HAS_STD_FMT)
endif()

add_subdirectory(externals/eternal)
target_link_libraries(autobuild PRIVATE eternal)

enable_testing()
add_subdirectory(tests)

if (NOT LIBELF_FOUND)
  message(STATUS "libelf not found on the system, falling back to external version")
  include(ExternalProject)
  ExternalProject_Add(
    elfutils
    URL "https://sourceware.org/elfutils/ftp/0.192/elfutils-0.192.tar.bz2"
    URL_HASH SHA512=543188f5f2cfe5bc7955a878416c5f252edff9926754e5de0c6c57b132f21d9285c9b29e41281e93baad11d4ae7efbbf93580c114579c182103565fe99bd3909
    CONFIGURE_COMMAND "./configure" "CC=${CMAKE_C_COMPILER}" "CFLAGS=${CMAKE_C_FLAGS}"
    DOWNLOAD_EXTRACT_TIMESTAMP YES
    BUILD_IN_SOURCE YES
    BUILD_COMMAND bash -ec "make -C lib && make -C libelf libelf_pic.a libelf.a"
    INSTALL_COMMAND ""
  )
  ExternalProject_Get_property(elfutils SOURCE_DIR)
  target_include_directories(autobuild PRIVATE "${SOURCE_DIR}/libelf" "${SOURCE_DIR}/lib")
  target_link_libraries(autobuild PRIVATE "${SOURCE_DIR}/libelf/libelf_pic.a")
  add_dependencies(autobuild elfutils)
else()
  target_include_directories(autobuild PRIVATE "${LIBELF_INCLUDE_DIRS}")
  target_link_directories(autobuild PRIVATE "${LIBELF_LIBRARY_DIRS}")
  target_link_libraries(autobuild PRIVATE "${LIBELF_LINK_LIBRARIES}")
endif()

file(READ "${CMAKE_CURRENT_SOURCE_DIR}/ab4.sh.in" ab4_prefix_file)
string(CONFIGURE "${ab4_prefix_file}" ab4_prefix_file @ONLY)
file(GENERATE OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/ab4.sh" CONTENT "${ab4_prefix_file}")

install(PROGRAMS "${CMAKE_CURRENT_BINARY_DIR}/ab4.sh" DESTINATION "${CMAKE_INSTALL_BINDIR}" RENAME autobuild)
install(TARGETS autobuild LIBRARY DESTINATION "${AB_INSTALL_PREFIX}")
install(DIRECTORY arch filters helpers lib pm proc qa sets templates DESTINATION "${AB_INSTALL_PREFIX}")
install(DIRECTORY etc/autobuild DESTINATION "${CMAKE_INSTALL_FULL_SYSCONFDIR}")
