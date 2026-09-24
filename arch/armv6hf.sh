#!/bin/bash
##arch/armv6hf.sh: Build definitions for ARMv6 (hard float).
##@copyright GPL-2.0+

# Retro: Overriding mainline definitions, and take more interest in reducing code size.
CFLAGS_COMMON_ARCH=('-ffunction-sections' '-fdata-sections')
CFLAGS_GCC_ARCH=('-fno-tree-ch')
LDFLAGS_COMMON_ARCH=('-Wl,--gc-sections')

CFLAGS_GCC_ARCH=('-march=armv6t2+vfpv2' '-mfloat-abi=hard' '-mtune=arm1176jz-s')
CFLAGS_CLANG_ARCH=('-mcpu=armv6' '-mthumb' '-mfpu=vfpv2' '-mfloat-abi=hard' '-mtune=arm1176jz-s')

# Enable Y2038 (largefile + time64) mitigation.
AB_FLAGS_Y2038=1
