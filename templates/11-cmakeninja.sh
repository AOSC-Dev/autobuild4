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

	abinfo "Running CMakeLists.txt to generate Ninja Configuration ..."
    ab_tostringarray CMAKE_AFTER
	cmake "$SRCDIR" "${CMAKE_DEF[@]}" "${CMAKE_AFTER[@]}" -GNinja \
			|| abdie "Failed to run CMakeLists.txt: $?."
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
