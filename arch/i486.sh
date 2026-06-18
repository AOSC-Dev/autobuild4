#!/bin/bash
##arch/i486.sh: Build definitions for i486.
##@copyright GPL-2.0+

# Retro: Overriding mainline definitions, and take more interest in reducing code size.
CFLAGS_COMMON_ARCH=('-O2' '-ffunction-sections' '-fdata-sections' '-mno-omit-leaf-frame-pointer')
CFLAGS_GCC_ARCH=('-fno-tree-ch')
LDFLAGS_COMMON_ARCH=('-Wl,--gc-sections')

CFLAGS_COMMON_ARCH+=('-march=i486' '-mtune=generic')

RUSTFLAGS_COMMON_ARCH=('-Ctarget-cpu=i486' '-Clink-args=-latomic')

# Enable Y2038 (largefile + time64) mitigation.
AB_FLAGS_Y2038=1
