#!/bin/bash
##arch/alpha.sh: Build definitions for DEC Alpha.
##@copyright GPL-2.0+

# Require FPU and use the new align-int ABI.
CFLAGS_COMMON_ARCH=('-march=68020' '-mtune=68020-60' '-mhard-float' '-malign-int')
# Retro: Overriding mainline definitions, and take more interest in reducing code size.
CFLAGS_COMMON_ARCH+=('-O2')
CFLAGS_GCC_ARCH=('-fno-tree-ch')

# Enable Y2038 (largefile + time64) mitigation.
AB_FLAGS_Y2038=1
