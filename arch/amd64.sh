#!/bin/bash
##arch/amd64.sh: Build definitions for amd64.
##@copyright GPL-2.0+

# This architecture has glibc HWCAPS support.
HAS_HWCAPS=1
HWCAPS=('x86-64-v2' 'x86-64-v3' 'x86-64-v4')

# CFLAGS without -march and μarch specific tuning.
CFLAGS_COMMON_ARCH_BASE=('-fomit-frame-pointer')

# Default -march and μarch specific tuning.
# No need to reference CFLAGS_COMMON_ARCH_BASE, it will be concatenated.
CFLAGS_COMMON_ARCH=('-march=x86-64' '-mtune=sandybridge' '-msse2')

# TODO What about Rust libraries?
RUSTFLAGS_COMMON_ARCH=('-Ctarget-cpu=x86-64')

CFLAGS_HWCAPS_x86_64_v2=("${CFLAGS_COMMON_ARCH_BASE[@]}" "-march=x86-64-v2" "-mtune=sandybridge" "-msse2" "-msse4.2")
CFLAGS_HWCAPS_x86_64_v3=("${CFLAGS_COMMON_ARCH_BASE[@]}" "-march=x86-64-v3" "-mtune=haswell" "-msse2" "-msse4.2" "-mavx2")
# TBD: Which -mtune to be chosen for x86_64 v4?
CFLAGS_HWCAPS_x86_64_v4=("${CFLAGS_COMMON_ARCH_BASE[@]}" "-march=x86-64-v4" "-mtune=generic" "-msse2" "-msse4.2" "-mavx2" "-mavx512f" "-mavx512bw" "-mavx512cd" "-mavx512dq" "-mavx512vl")
