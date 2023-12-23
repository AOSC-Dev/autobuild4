#!/bin/bash
# build/00-self.sh: Invokes `build` defs.
##@copyright GPL-2.0+

build_self_probe() {
	arch_findfile -2 build
}

build_self_configure() {
	true;
}

build_self_build() {
	BUILD_START
	arch_loadfile_strict -2 build

	cd "$SRCDIR"
}

build_self_install() {
	true;
}

ab_register_template self
