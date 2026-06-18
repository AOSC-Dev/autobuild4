#!/bin/bash
##arch/armv6hf.sh: Build definitions for ARMv6 (hard float).
##@copyright GPL-2.0+

# Retro: Overriding mainline definitions, and take more interest in reducing code size.
CFLAGS_COMMON_ARCH=('-O2' '-ffunction-sections' '-fdata-sections')
CFLAGS_GCC_ARCH=('-fno-tree-ch')
LDFLAGS_COMMON_ARCH=('-Wl,--gc-sections')

CFLAGS_COMMON_ARCH+=('-march=armv6' '-mfloat-abi=hard')
CFLAGS_GCC_ARCH=('-mtune=arm1176jz-s')

# Enable Y2038 (largefile + time64) mitigation.
AB_FLAGS_Y2038=1
