#!/bin/bash
##arch/i486.sh: Build definitions for i486.
##@copyright GPL-2.0+

# Retro: Overriding mainline definitions, and take more interest in reducing code size.
CFLAGS_COMMON_ARCH=('-O2' '-fno-tree-ch' '-ffunction-sections' '-fdata-sections' '-mno-omit-leaf-frame-pointer')
LDFLAGS_COMMON_ARCH=('-Wl,--gc-sections')

CPPFLAGS_COMMON_ARCH=('-D_TIME_BITS=64' '-D_FILE_OFFSET_BITS=64')
CFLAGS_COMMON_ARCH+=('-march=i486' '-mtune=generic')

RUSTFLAGS_COMMON_ARCH=('-Ctarget-cpu=i486' '-Clink-args=-latomic')
