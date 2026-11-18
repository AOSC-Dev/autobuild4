#!/bin/bash
# 13-cmakeninja.sh: Builds cmake with Ninja
##@copyright GPL-2.0+

build_cmakeninja_probe(){
	[ -f "$SRCDIR"/CMakeLists.txt ]
}

build_cmakeninja_configure() {
    ABSHADOW=${ABSHADOW_CMAKE-$ABSHADOW}
	if bool "$ABSHADOW"
	then
		abinfo "Creating directory for shadow build ..."
		mkdir -pv "$BLDDIR" \
			|| abdie "Failed to create shadow build directory: $?."
		cd "$BLDDIR" \
			|| abdie "Failed to enter shadow build directory: $?."
	fi
	BUILD_START

	# FIXME: CMake does not add ENV{CPPFLAGS} to
	# CMAKE_${LANGUAGE}_FLAGS_INIT. We must either patch CMake or add
	# CPPFLAGS to CFLAGS and CXXFLAGS manually.
	#
	# https://cmake.org/cmake/help/v4.5/variable/CMAKE_LANG_FLAGS.html
	#
	# Upstream report has been under deliberation since 2012:
	#
	# https://gitlab.kitware.com/cmake/cmake/-/work_items/12928
	#
	# Re-visit if this changes.
	export CFLAGS="$CPPFLAGS $CFLAGS"
	export CXXFLAGS="$CPPFLAGS $CXXFLAGS"

	abinfo "Running CMakeLists.txt to generate Ninja Configuration ..."
	ab_tostringarray CMAKE_AFTER
	local CONFIGURE_CMD=(
		cmake "$SRCDIR"
		"${CMAKE_DEF[@]}" "${CMAKE_AFTER[@]}"
		-GNinja
	)
	ab_log_configuring_command "${CONFIGURE_CMD[@]}"
	"${CONFIGURE_CMD[@]}" || abdie "Failed to run CMakeLists.txt: $?."
}

build_cmakeninja_build() {
    BUILD_READY
    if bool "$ABUSECMAKEBUILD"; then
        abinfo "Building binaries ..."
        cmake --build . \
            || abdie "Failed to build binaries: $?."
    fi
}

build_cmakeninja_install() {
    if bool "$ABUSECMAKEBUILD"; then
        BUILD_FINAL
        abinfo "Installing binaries ..."
        DESTDIR="$PKGDIR" cmake --install . \
            || abdie "Failed to install binaries: $?."
    else
        abinfo "Building and installing binaries ..."
        ab_tostringarray MAKE_AFTER
		DESTDIR="$PKGDIR" \
			ninja $ABMK "${MAKE_AFTER[@]}" install \
			|| abdie "Failed to build and install binaries: $?."
    fi

    if bool "$ABSHADOW"; then
		cd "$SRCDIR" \
			|| abdie "Failed to return to source directory: $?."
	fi
}

ab_register_template cmakeninja -- cmake ninja
