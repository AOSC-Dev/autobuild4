#!/bin/bash
##arch/armv5te.sh: Build definitions for ARMv5TE (soft-float).
##@copyright GPL-2.0+

# Retro: Override mainline definitions and prioritise smaller binaries.
CFLAGS_COMMON_ARCH=('-ffunction-sections' '-fdata-sections')
CFLAGS_GCC_ARCH=('-fno-tree-ch')
LDFLAGS_COMMON_ARCH=('-Wl,--gc-sections')

CFLAGS_COMMON_ARCH+=('-march=armv5te' '-mfloat-abi=soft')
CFLAGS_GCC_ARCH+=('-mtune=arm926ej-s')

# Enable Y2038 (largefile + time64) mitigation.
AB_FLAGS_Y2038=1
