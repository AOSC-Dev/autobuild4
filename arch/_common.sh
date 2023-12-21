#!/bin/bash
##arch/_common.sh: Common arch defs for all ab arches, defines-mutable.
##@copyright GPL-2.0+

# C Compiler Flags.
CFLAGS_COMMON=('-pipe' '-Wno-error')
CFLAGS_COMMON_OPTI=('-O2')
CFLAGS_COMMON_DEBUG=('-O0')	# not that frequently used since autotools know it.
CFLAGS_GCC=()
CFLAGS_GCC_OPTI=('-fira-loop-pressure' '-fira-hoist-pressure' '-ftree-vectorize')
CFLAGS_GCC_OPTI_LTO=('-flto=auto')
CFLAGS_GCC_DEBUG=('-Og')		# note: not enabled for clang
# CFLAGS_CLANG='-fno-integrated-as ' # GNU as has compatibility issue with clang on ARMv8.[01]
CFLAGS_CLANG_OPTI_LTO=('-flto')
CFLAGS_DBG_SYM=('-ggdb')  # Appended when ABSPLITDBG is turned on
# C Specific Flags.
CFLAGS_COMMON_WEIRD=()
# What to add for C++ Compiler Flags.
CXXFLAGS_GCC_OPTI=("-fdeclone-ctor-dtor" "-ftree-vectorize")
CXXFLAGS_COMMON_WEIRD=()
CXXFLAGS_COMMON_PERMISSIVE=("-fpermissive")
# Preprocesser Flags.
CPPFLAGS_COMMON=("-D_GLIBCXX_ASSERTIONS")
# OBJC Flags.
OBJCFLAGS_COMMON_WEIRD=()
# OBJCXX Flags.
OBJCXXFLAGS_COMMON_WEIRD=()
OBJCXXFLAGS_COMMON_PERMISSIVE=('-fpermissive')
# RUST Flags.
RUSTFLAGS_COMMON=()
RUSTFLAGS_COMMON_OPTI=('-Ccodegen-units=1' '-Copt-level=3')
RUSTFLAGS_COMMON_WEIRD=()
# Use clang + lld for processing LTO
RUSTFLAGS_COMMON_OPTI_LTO=(
    '-Cembed-bitcode=yes' '-Clinker-plugin-lto' '-Clinker=clang'
    '-Clink-arg=-flto' '-Clink-arg=-fuse-ld=lld' '-Clink-arg=-Wl,-build-id=sha1'
    '-Clink-arg=-Wl,--lto-O3'
)
# Linker Flags. (actually passed to your CC, just FYI)
# LDFLAGS writing helpers:
# ld_arg(){ printf %s '-Wl'; local IFS=,; printf %s "$*"; }
# ld_path(){ local path=$(arch_lib "$@"); ld_arg "$path"; echo -n " -L$path"; }
LDFLAGS_COMMON=("-Wl,-O1,--sort-common,--as-needed" "-Wl,-build-id=sha1")
#LDFLAGS_COMMON_OPTI='-Wl,--relax '	# on some arches this interfere with debugging, therefore put into OPTI.
# temporarily disabled because this breaks core-devel/glibc build (-r cannot be used together with --relax).
# investigation advised.
LDFLAGS_COMMON_OPTI_LTO=("-flto" "-fuse-linker-plugin")
LDFLAGS_COMMON_OPTI_NOLTO=('-fno-lto' '-fuse-linker-plugin')
# LDFLAGS_COMMON_CROSS_BASE=('-Wl,-rpath' '-Wl,/usr/lib' "-Wl,-rpath-link $(ld_path)")
