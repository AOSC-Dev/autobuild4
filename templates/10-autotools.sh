#!/bin/bash
# 10-autotools.sh: Builds GNU autotools stuff
##@copyright GPL-2.0+

build_autotools_probe() {
	[ -x "${configure=$SRCDIR/configure}" ] || \
		[ -x "$SRCDIR"/autogen.sh ] || \
		[ -x "$SRCDIR"/bootstrap ] || \
		[ -f "$SRCDIR"/configure.ac ]
}

build_autotools_update_base() {
	abinfo "Copying replacement autotools base files ..."
	# Adapted from redhat-rpm-config.
	# https://src.fedoraproject.org/rpms/redhat-rpm-config/blob/rawhide/f/macros#_192
	# Note: config.guess and config.sub provided by the 'config' package.
	find "$SRCDIR" '(' -name config.guess -o -name config.sub ')' \
		-execdir 'cp' '-v' '/usr/bin/{}' '{}' ';' \
		|| abdie "Failed to copy replacement: $?.";
}

build_autotools_regenerate() {
	abinfo "Re-generating Autotools scripts ..."
	[ -x "$SRCDIR"/bootstrap ] && ! [ -e "$SRCDIR"/autogen.sh ] \
		&& ln -sv "$SRCDIR"/bootstrap "$SRCDIR"/autogen.sh
	if [[ -x "$SRCDIR"/bootstrap && ! -d "$SRCDIR"/bootstrap ]]; then
		"$SRCDIR/bootstrap" \
			|| abdie "Reconfiguration failed: $?."
	elif ! bool "$ABNOAUTOGEN" && \
		[[ -x "$SRCDIR"/autogen.sh && ! -d "$SRCDIR"/autogen.sh ]]; then
		NOCONFIGURE=1 "$SRCDIR/autogen.sh" \
			|| abdie "Reconfiguration failed: $?."
	elif [ -e "$SRCDIR"/configure.ac ] || [ -e "$SRCDIR"/configure.in ]; then
		autoreconf -fvis 2>&1 || abdie "Reconfiguration failed: $?."
	else
		abdie 'Necessary files not found for script regeneration - non-standard Autotools source?'
	fi
}

build_autotools_configure() {
	export ABSHADOW
	export FORCE_UNSAFE_CONFIGURE=1

	if bool "$ABCONFIGHACK"
	then
		build_autotools_update_base
	fi

	if bool "$RECONF"
	then
		build_autotools_regenerate
	fi

	if bool "$ABSHADOW"
	then
		abinfo "Creating directory for shadow build ..."
		mkdir -pv "$BLDDIR" \
			|| abdie "Failed to create shadow build directory: $?."
		cd "$BLDDIR" \
			|| abdie "Failed to enter shadow build directory: $?."
	fi

	if [[ "$ABHOST" = "optenv32" ]]
	then
		AUTOTOOLS_TARGET=("--host=${ARCH_TARGET[$ABHOST]}" "--target=${ARCH_TARGET[$ABHOST]}")
	elif [[ "$ABHOST" != "$ABBUILD" ]]
	then
		AUTOTOOLS_TARGET=("--host=$HOST")
	else
		AUTOTOOLS_TARGET=("--build=${ARCH_TARGET[$ARCH]}")
	fi

	BUILD_START
	ab_tostringarray AUTOTOOLS_AFTER
	abinfo "Running configure ..."
	local AUTOTOOLS_OPTION_CHECKING
	if bool "$AUTOTOOLS_STRICT"; then
		AUTOTOOLS_OPTION_CHECKING="--enable-option-checking=fatal"
	fi
	$ABCONFWRAPPER \
	${configure:="$SRCDIR"/configure} \
			"${AUTOTOOLS_TARGET[@]}" "${AUTOTOOLS_DEF[@]}" "${AUTOTOOLS_AFTER[@]}" \
			"$AUTOTOOLS_OPTION_CHECKING" \
			|| abdie "Failed to run configure: $?."
}

build_autotools_build() {
	BUILD_READY
	ab_tostringarray MAKE_AFTER
	abinfo "Building binaries ..."
	make V=1 VERBOSE=1 \
		$ABMK "${MAKE_AFTER[@]}" \
		|| abdie "Failed to build binaries: $?."
}

build_autotools_install() {
    BUILD_FINAL
	abinfo "Installing binaries ..."
	make install V=1 VERBOSE=1 \
		BUILDROOT="$PKGDIR" DESTDIR="$PKGDIR" "${MAKE_AFTER[@]}" \
		|| abdie "Failed to install binaries: $?."

	if bool "$ABSHADOW"
	then
		cd "$SRCDIR" \
			|| abdie "Unable to return to source directory: $?."
	fi
}

ab_register_template autotools -- autoconf automake autoreconf
