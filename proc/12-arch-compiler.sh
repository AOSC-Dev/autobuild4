#!/bin/bash
##proc/compiler: A weird and broken way to select the compilers
##@copyright GPL-2.0+

# Wrapper TODO: accept $0 detection by checking ${HOSTTOOLPREFIX/abcross/abwrap}.
if [[ "$ABBUILD" == "$ABHOST" ]]; then
	if [ -d /opt/pseudo-multilib/bin ]; then
		export PATH="/opt/pseudo-multilib/bin:$PATH"
	else
		if bool "$USECLANG"; then
			export CC=clang CXX=clang++ OBJC=clang OBJCXX=clang++
		else
			export CC=gcc CXX=g++ OBJC=gcc OBJCXX=g++
		fi
	fi
elif [[ "$ABHOST" == "optenv32" ]]; then
	if bool "$USECLANG"; then
		# FIXME: LLVM must be patched to recognize libdirs and
		# includedirs of optenvs in order to get them to compile.
		abdie "Sorry, optenv targets currently can not handle USECLANG=1."
	else
		export CC=i686-aosc-linux-gnu-gcc CXX=i686-aosc-linux-gnu-g++ \
			OBJC=i686-aosc-linux-gnu-gcc OBJCXX=i686-aosc-linux-gnu-g++ \
			LD=i686-aosc-linux-gnu-ld
	fi
# Possible optenvx64 in the future.
elif [[ "$ABHOST" != 'noarch' ]]; then
    abdie "Cross-compilation is no longer supported."
fi
