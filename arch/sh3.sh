#!/bin/bash
##arch/i486.sh: Build definitions for i486.
##@copyright GPL-2.0+

# Retro: Overriding mainline definitions, and take more interest in reducing code size.
CFLAGS_COMMON_ARCH=('-ffunction-sections' '-fdata-sections')
CFLAGS_GCC_ARCH=('-fno-tree-ch')
LDFLAGS_COMMON_ARCH=('-Wl,--gc-sections')

CFLAGS_COMMON_ARCH+=('-m3' '-ml' '-mieee')

# Enable Y2038 (largefile + time64) mitigation.
AB_FLAGS_Y2038=1
