#!/bin/bash
##arch/loongarch64.sh: Build definitions for LoongArch targets.
##@copyright GPL-2.0+

CFLAGS_GCC_ARCH=('-mabi=lp64d' '-march=loongarch64' '-mtune=la464' '-mlsx')

# FIXME: +lsx feature is broken as of LLVM 17.0.6, awaiting full vector
# implementation.
RUSTFLAGS_COMMON_ARCH=('-Ctarget-cpu=generic-la64' '-Ctarget-feature=-lsx,+d' '-Clink-arg=-mabi=lp64d')
