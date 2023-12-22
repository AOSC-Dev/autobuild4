#!/bin/bash
# 12-cmake.sh: Builds cmake stuff
##@copyright GPL-2.0+

build_cmake_probe(){
	[ -f "$SRCDIR"/CMakeLists.txt ]
}

build_cmake_configure() {
    ABSHADOW=${ABSHADOW_CMAKE-$ABSHADOW}
	if bool "$ABSHADOW"; then
		abinfo "Creating directory for shadow build ..."
		mkdir -pv "$BLDDIR" \
			|| abdie "Failed to create shadow build directory: $?."
		cd "$BLDDIR" \
			|| abdie "Failed to enter shadow build directory: $?."
	fi

    BUILD_START

	abinfo "Running CMakeLists.txt to generate Makefile ..."
    ab_tostringarray CMAKE_AFTER
	cmake "$SRCDIR" "${CMAKE_DEF[@]}" "${CMAKE_AFTER[@]}" \
			|| abdie "Failed to run CMakeLists.txt: $?."
}

build_cmake_build() {
    BUILD_READY

    ab_tostringarray MAKE_AFTER
    abinfo "Building binaries ..."
	if bool "$ABUSECMAKEBUILD"; then
        cmake --build . -- $ABMK "${MAKE_AFTER[@]}" \
            || abdie "Failed to build binaries: $?."
    else
	    make $ABMK "${MAKE_AFTER[@]}" \
		    || abdie "Failed to build binaries: $?."
    fi
}

build_cmake_install() {
    BUILD_FINAL
    if bool "$ABUSECMAKEBUILD"; then
	    abinfo "Installing binaries ..."
	    DESTDIR="$PKGDIR" cmake --install . \
		    || abdie "Failed to install binaries: $?."
    else
    	abinfo "Installing binaries ..."
	    make install \
		    DESTDIR="$PKGDIR" $ABMK "${MAKE_AFTER[@]}" \
		    || abdie "Failed to install binaries: $?."
    fi

    if bool "$ABSHADOW"; then
		cd "$SRCDIR" \
			|| abdie "Failed to return to source directory: $?."
	fi
}

ab_register_template cmake -- cmake make
