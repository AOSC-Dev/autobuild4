#!/bin/bash
# 12-meson.sh: Builds Meson sources
##@copyright GPL-2.0+
abtryexe meson

build_meson_probe(){
	[ -e "$SRCDIR"/meson.build ]
}

build_meson_configure() {
	ab_tostringarray MESON_AFTER
	mkdir "$BLDDIR" \
		|| abdie "Failed to create build directory: $?."
	BUILD_START
	abinfo "Running Meson ..."
	meson setup "${MESON_DEF[@]}" "${MESON_AFTER[@]}" \
			"$SRCDIR" "$BLDDIR" \
			|| abdie "Failed to run Meson ..."
}

build_meson_build() {
	BUILD_READY
	cd "$BLDDIR" \
		|| abdie "Failed to enter build directory: $?."
	abinfo "Building binaries ..."
	ninja \
		|| abdie "Failed to run build binaries: $?."
}

build_meson_install() {
    BUILD_FINAL
	abinfo "Installing binaries ..."
	DESTDIR="$PKGDIR" ninja install \
		|| abdie "Failed to install binaries: $?."
	cd "$SRCDIR" \
		|| abdie "Failed to return to source directory: $?."
}

ab_register_template meson -- meson
