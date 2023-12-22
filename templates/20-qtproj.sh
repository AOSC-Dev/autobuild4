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
	export QT_SELECT
	[ "$QT_SELECT" ] ||
	if bool "$USEQT5"; then
		abwarn "\$USEQT5 is now deprecated. Use QT_SELECT=5."
		QT_SELECT=5
	elif bool "$USEQT4"; then
		abwarn "\$USEQT4 is now deprecated. Use QT_SELECT=4."
		QT_SELECT=4
	else
		abicu "Qt version unspecified => default."
		QT_SELECT=default
	fi

	BUILD_START
	ab_tostringarray QTPROJ_AFTER
	ab_typecheck -a QTPROJ_DEF
	abinfo "Running qmake to generate Makefile ..."
	"$QTPREFIX/bin/qmake" "${QTPROJ_DEF[@]}" "${QTPROJ_AFTER[@]}" \
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

ab_register_template qtproj -- qmake
