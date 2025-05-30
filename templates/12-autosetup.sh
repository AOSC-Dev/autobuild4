#!/bin/bash
# 12-autosetup.sh: Builds Autosetup sources
##@copyright GPL-2.0+

build_autosetup_probe(){
	[ -e "$SRCDIR"/autosetup/autosetup ] && \
		[ -e "$SRCDIR"/auto.def ] && \
		[ -e "$SRCDIR"/configure ]
}

build_autosetup_configure() {
	mkdir -vp "$BLDDIR" \
		|| abdie "Failed to create build directory: $?."
	cd "$BLDDIR" \
		|| abdie "Failed to enter build directory: $?."

	if [[ "x${AUTOTOOLS_TARGET[*]}" != "x" ]]
	then
		# $AUTOTOOLS_TARGET may be set internally by HWCAPS script.
		# do nothing.
		AUTOSETUP_TARGET=("${AUTOTOOLS_TARGET[@]}")
	elif [[ "$ABHOST" = optenv* ]]
	then
		AUTOSETUP_TARGET=("--host=${ARCH_TARGET[$ABHOST]}" "--target=${ARCH_TARGET[$ABHOST]}" "--build=${ARCH_TARGET[$ABHOST]}"
				  "CC=$CC" "CXX=$CXX" "OBJC=$OBJC" "OBJCXX=$OBJCXX" LD="$LD")
	elif [[ "$ABHOST" != "$ABBUILD" ]]
	then
		AUTOSETUP_TARGET=("--host=$HOST")
	else
		AUTOSETUP_TARGET=("--build=${ARCH_TARGET[$ARCH]}")
	fi

	BUILD_START
	abinfo "Running autosetup ..."
	ab_tostringarray AUTOSETUP_AFTER
	"$SRCDIR"/configure \
		"${AUTOSETUP_TARGET[@]}" "${AUTOSETUP_DEF[@]}" "${AUTOSETUP_AFTER[@]}" \
		|| abdie "Failed to run autosetup ..."
}

build_autosetup_build() {
	BUILD_READY
	cd "$BLDDIR" \
		|| abdie "Failed to enter build directory: $?."

	abinfo "Building binaries ..."
	make \
		|| abdie "Failed to build binaries: $?."
}

build_autosetup_install() {
    BUILD_FINAL
	abinfo "Installing binaries ..."
	make install DESTDIR="$PKGDIR" \
		|| abdie "Failed to install binaries: $?."
	cd "$SRCDIR" \
		|| abdie "Failed to return to source directory: $?."
}

ab_register_template autosetup -- tclsh
