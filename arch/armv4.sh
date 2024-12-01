#!/bin/bash
##arch/armv4.sh: Build definitions for ARMv4 (w/o THUMB).
##@copyright GPL-2.0+

# Retro: Overriding mainline definitions, and take more interest in reducing code size.
CFLAGS_COMMON_OPTI=('-Os' '-ffunction-sections' '-fdata-sections')
LDFLAGS_COMMON_OPTI=('-Wl,--gc-sections')

CFLAGS_COMMON_ARCH=('-march=armv4' '-mfloat-abi=soft')
CFLAGS_GCC_ARCH=('-mtune=strongarm110')
