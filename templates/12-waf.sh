#!/bin/bash
##12-waf.sh: Builds WAF stuff
##@copyright GPL-2.0+

build_waf_probe() {
	[ -f "$SRCDIR"/waf ]
}

build_waf_configure() {
    BUILD_START
	abinfo "Running Waf script(s) ..."
    ab_tostringarray WAF_AFTER
	"$PYTHON" waf configure "${WAF_DEF[@]}" "${WAF_AFTER[@]}" \
		|| abdie "Failed to run Waf script(s): $?."
}

build_waf_build() {
	BUILD_READY
	abinfo "Building binaries ..."
    ab_tostringarray MAKE_AFTER
	"$PYTHON" waf build ${ABMK} "${MAKE_AFTER[@]}" "${MAKEFLAGS[@]}" \
		|| abdie "Failed to build binaries: $?."
}

build_waf_install() {
    BUILD_FINAL
	abinfo "Installing binaries ..."
	"$PYTHON" waf install --destdir="${PKGDIR}" \
		|| abdie "Failed to install binaries: $?."
}

ab_register_template waf -- "$PYTHON"
