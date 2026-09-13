#!/bin/bash
##arch/alpha.sh: Build definitions for DEC Alpha.
##@copyright GPL-2.0+

# Retro: Overriding mainline definitions, and take more interest in reducing code size.
CFLAGS_COMMON_ARCH=('-ffunction-sections' '-fdata-sections')
CFLAGS_GCC_ARCH=('-fno-tree-ch')
LDFLAGS_COMMON_ARCH=('-Wl,--gc-sections')

# Retro: Overriding mainline definitions, and take more interest in reducing code size.
CFLAGS_COMMON_ARCH+=('-mieee' '-mcpu=ev4' '-mtune=ev67')

# NOTE: Despite the stack growing downwards, they hardcoded
# FRAME_GROWS_DOWNWARD to 0, so no stack protector support.
AB_FLAGS_SSP=0
