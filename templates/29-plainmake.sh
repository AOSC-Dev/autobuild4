#!/bin/bash
##29-plainmake.sh: Build those pkgs that comes with a Makefile
##@copyright GPL-2.0+
build_plainmake_probe(){
	false;
}

build_plainmake_configure() {
	abwarn 'The plainmake template is not reliable.'
	abwarn 'Please avoid using ABTYPE=plainmake and write a custom build script instead.'
	abwarn 'This template maybe removed in a future release of autobuild.'
	BUILD_START
	if [ -e "$BUILD_PLAINMAKE_DOTCONFIG" ]; then
		abinfo 'Copying .config file as defined in $BUILD_PLAINMAKE_DOTCONFIG ...'
		cp -v "$BUILD_PLAINMAKE_DOTCONFIG" "$SRCDIR/.config" \
			|| abdie "Failed to copy .config file: $?."
	fi
}

build_plainmake_build(){
	BUILD_READY
	ab_tostringarray MAKE_AFTER
	abinfo "Building binaries using Makefile ..."
	make V=1 VERBOSE=1 $ABMK "${MAKE_AFTER[@]}" \
		|| abdie "Failed to build binaries: $?."
}

build_plainmake_install(){
	BUILD_FINAL
	abinfo "Installing binaries ..."
	make install \
		V=1 VERBOSE=1 \
		BUILDROOT="$PKGDIR" DESTDIR="$PKGDIR" \
		"${MAKE_INSTALL_DEF[@]}" "${MAKE_AFTER[@]}" \
		|| abdie "Failed to install binaries: $?."
}

ab_register_template plainmake -- make
