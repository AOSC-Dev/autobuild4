#!/bin/bash
##20-qtproj.sh: Builds qmake stuff
##@copyright GPL-2.0+

build_qtproj_probe() {
	# find can't return 0 on non-matches, so let's do it in reverse
	if find . -maxdepth 1 -name '*.pro' -type f -exec 'false' '{}' '+'; then
		return 1;
	else
		return 0;
	fi
}

build_qtproj_configure() {
	BUILD_START
	[[ -v "QMAKEVER" ]] || abdie "qmake version unspecified. Set QMAKEVER=<version> to the corresponding Qt version."
	export QMAKE
	if [ "$QMAKEVER" -eq 6 ]; then
		QMAKE="qmake-qt6"
	elif [ "$QMAKEVER" -eq 5 ]; then
		QMAKE="qmake-qt5"
	elif [ "$QMAKEVER" -eq 4 ]; then
		QMAKE="qmake-qt4"
	else
		abdie "Unknown qmake version: ${QMAKEVER}."
	fi

	export QTPROJ_SPEC
	if bool "$USECLANG"; then
		QTPROJ_SPEC=" -spec linux-clang "
	else
		QTPROJ_SPEC=" -spec linux-g++ "
	fi

	ab_tostringarray QTPROJ_AFTER
	ab_typecheck -a QTPROJ_DEF
	abinfo "Running ${QMAKE} to generate Makefile ..."
	"/usr/bin/${QMAKE}" $QTPROJ_SPEC "${QTPROJ_DEF[@]}" "${QTPROJ_AFTER[@]}" \
		|| abdie "Failed while running qmake to generate Makefile: $?."
}

build_qtproj_build() {
	ab_tostringarray MAKE_AFTER
	BUILD_READY
	abinfo "Building binaries ..."
	make V=1 VERBOSE=1 $ABMK "${MAKE_AFTER[@]}" \
		|| abdie "Failed to build binaries: $?."
}

build_qtproj_install() {
	BUILD_FINAL
	abinfo "Installing binaries ..."
	make V=1 VERBOSE=1 INSTALL_ROOT="$PKGDIR" install \
		|| abdie "Failed to install binaries: $?."
}

ab_register_template -l qtproj -- qmake
