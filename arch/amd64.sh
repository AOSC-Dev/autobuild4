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
RUSTFLAGS_COMMON_ARCH=('-Ctarget-cpu=x86-64')

# HWCAPS subtargets in x86-64 are based on the microarchitecture levels
# defined in the x86-64 psABI[1]. As the base level, x86-64-v1 does not
# act as a HWCAPS subtarget.
#
# [1]: https://gitlab.com/x86-psABIs/x86-64-ABI/-/commit/77566eb03bc6a326811cb7e9a6b9396884b67c7c

# List of HWCAPS subtargets in x86-64:
#
# - x86-64-v2: CPUs with CMPXCHG16B, SSE3, SSSE3 and SSE4.2 extensions,
#   starting from Sandy Bridge.
# - x86-64-v3: CPUs with AVX, AVX2, BMI1, BMI2, and other miscellaneous
#   instructions, staring from Haswell. Also the most common one.
# - x86-64-v4: CPUs with AVX512 (AVX-512-F, AVX-512-BW, AVX-512-CD,
#   AVX-512-DQ and AVX-512-DL specifically). Few consumer-grade CPUs
#   supports this.
CFLAGS_HWCAPS_x86_64_v2=("${CFLAGS_COMMON_ARCH_BASE[@]}" "-march=x86-64-v2" "-mtune=generic" "-msse2" "-msse3" "-mssse3" "-msse4.2")
CFLAGS_HWCAPS_x86_64_v3=("${CFLAGS_COMMON_ARCH_BASE[@]}" "-march=x86-64-v3" "-mtune=generic" "-msse2" "-msse3" "-mssse3" "-msse4.2" "-mavx" "-mavx2")
CFLAGS_HWCAPS_x86_64_v4=("${CFLAGS_COMMON_ARCH_BASE[@]}" "-march=x86-64-v4" "-mtune=generic" "-msse2" "-msse3" "-mssse3" "-msse4.2" "-mavx" "-mavx2" "-mavx512f" "-mavx512bw" "-mavx512cd" "-mavx512dq" "-mavx512vl")

RUSTFLAGS_HWCAPS_x86_64_v2=("-Ctarget-cpu=x86-64-v2" "-Ctarget-feature=+sse2,+sse3,+ssse3,+sse4.2")
RUSTFLAGS_HWCAPS_x86_64_v3=("-Ctarget-cpu=x86-64-v3" "-Ctarget-feature=+sse2,+sse3,+ssse3,+sse4.2,+avx,+avx2")
RUSTFLAGS_HWCAPS_x86_64_v4=("-Ctarget-cpu=x86-64-v4" "-Ctarget-feature=+sse2,+sse3,+ssse3,+sse4.2,+avx,+avx2,+avx512f,+avx512bw,+avx512cd,+avx512dq,+avx512vl")

# CPPFLAGS must be set for function selection in preprocessing to work.
CPPFLAGS_HWCAPS_x86_64_v2=("-march=x86-64-v2" "-msse2" "-msse3" "-mssse3" "-msse4.2")
CPPFLAGS_HWCAPS_x86_64_v3=("-march=x86-64-v3" "-msse2" "-msse3" "-mssse3" "-msse4.2" "-mavx" "-mavx2")
CPPFLAGS_HWCAPS_x86_64_v4=("-march=x86-64-v4" "-msse2" "-msse3" "-mssse3" "-msse4.2" "-mavx" "-mavx2" "-mavx512f" "-mavx512bw" "-mavx512cd" "-mavx512dq" "-mavx512vl")
