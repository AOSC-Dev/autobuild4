#!/bin/bash
##arch/armv7hf.sh: Build definitions for ARMv7 (hard float, w/ NEON).
##@copyright GPL-2.0+

# Retro: Overriding mainline definitions, and take more interest in reducing code size.
CFLAGS_COMMON_ARCH=('-O2' '-fno-tree-ch' '-ffunction-sections' '-fdata-sections')
LDFLAGS_COMMON_ARCH=('-Wl,--gc-sections')

CFLAGS_COMMON_ARCH+=('-march=armv7-a' '-mfloat-abi=hard' '-mfpu=neon' '-mthumb')
CFLAGS_GCC_ARCH=('-mtune=cortex-a7')
