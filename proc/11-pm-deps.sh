#!/bin/bash
##proc/deps: We want to install the dependencies
##@copyright GPL-2.0+

pm_install_deps() {
    local _tmpdir
    _tmpdir="$(mktemp -d)"
    mkdir -p "${_tmpdir}"/debian/
    local _filtered=()
    for p in "$@"; do
        if [[ "$p" = "@"* ]]; then
            continue
        fi
        _filtered+=("$p")
    done
    abpm_dump_builddep_req "${_filtered[@]}" > "${_tmpdir}"/debian/control
    apt-get build-dep -y "${_tmpdir}"
    rm -rf "${_tmpdir}"
}

if bool "$ABBUILDDEPONLY"; then
	if ! bool "$VER_NONE"; then
		abdie "ABBUILDDEPONLY must be used with VER_NONE=1 (dependency version-agnostic). Aborting."
	fi
    pm_install_deps $BUILDDEP
else
	pm_install_deps $BUILDDEP $PKGDEP $PKGPRDEP $TESTDEP
fi
