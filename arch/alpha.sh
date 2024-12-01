#!/bin/bash
##arch/alpha.sh: Build definitions for DEC Alpha.
##@copyright GPL-2.0+
CFLAGS_COMMON_ARCH=('-mieee' '-mcpu=ev4')
# Retro: Overriding mainline definitions, and take more interest in reducing code size.
CFLAGS_COMMON_OPTI=('-Os')
# Retro: Clang: even smaller code size than -Os
CFLAGS_CLANG_OPTI=('-Oz')
