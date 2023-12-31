#!/bin/bash
##arch/loongarch64.sh: Build definitions for Loongson 3A/B 5000.
##@copyright GPL-2.0+

CFLAGS_GCC_ARCH=('-mabi=lp64d' '-march=loongarch64' '-mtune=la464' '-mlsx' '-flto-partition=none')

RUSTFLAGS_COMMON_ARCH=('-Ctarget-cpu=generic-la64' '-Ctarget-feature=+lsx,+d' '-Clink-arg=-mabi=lp64d')
