#!/bin/bash
##arch/loongson2f.sh: Build definitions for Loongson 2F.
##@copyright GPL-2.0+

# Retro: Overriding mainline definitions, and take more interest in reducing code size.
CFLAGS_COMMON_ARCH=('-O2' '-fno-tree-ch' '-ffunction-sections' '-fdata-sections')
LDFLAGS_COMMON_ARCH=('-Wl,--gc-sections')

CFLAGS_COMMON_ARCH+=('-mabi=64' '-march=mips3')
CFLAGS_GCC_ARCH=('-mtune=loongson2f' '-mloongson-mmi' '-Wa,-mfix-loongson2f-nop')

# Override some LTO flags to avoid partition size errors during linkage.
CFLAGS_GCC_OPTI_LTO=("${CFLAGS_COMMON_ARCH_LTO[@]}" '-flto-partition=none')
LDFLAGS_GCC_OPTI_LTO=("${LDFLAGS_COMMON_ARCH_LTO[@]}" '-mxgot' '-flto-partition=none')

RUSTFLAGS_COMMON_ARCH=('-Ctarget-cpu=mips3' '-Ctarget-features=+xgot,-mips64r2')
RUSTFLAGS_COMMON_ARCH_LTO+=("-Clink-arg=-Wl,-z,notext")

# Position-independent executable buildmode is not available on any mips architecture.
# Removing for loongson2f target.
GOFLAGS=${GOFLAGS/-buildmode=pie/}
