#!/bin/bash
##15-python.sh: Builds Python stuff
##@copyright GPL-2.0+

build_python_probe() {
	[ -f "$SRCDIR"/setup.py ]
}

build_python_configure() {
	BUILD_START
	true;
}

build_python_build() {
	for PYTHON in "$(bool "$NOPYTHON2" || command -v python2 || command -v python || echo)" \
	"$(bool "$NOPYTHON3" || command -v python3 || echo)"; do
		[ "$PYTHON" ] || continue
		BUILD_READY
		abinfo "Building Python (PyPI) package using $PYTHON ..."
		"$PYTHON" "$SRCDIR"/setup.py build \
			|| abdie "Failed to build Python (PyPI) package using ${PYTHON}: $?."
		BUILD_FINAL
		abinfo "Installing Python (PyPI) package using $PYTHON ..."
		"$PYTHON" "$SRCDIR"/setup.py install \
			--prefix=/usr --root="$PKGDIR" --optimize=1 \
			|| abdie "Failed to install Python (PyPI) package using ${PYTHON}: $?."
		abinfo "Cleaning Python (PyPI) package source tree ..."
		bool "$NOPYTHONCLEAN" \
			|| ( "$PYTHON" "$SRCDIR"/setup.py clean \
				|| abdie "Failed to clean up Python (PyPI) package source tree: $?." ) \
			|| true
	done
}

build_python_install() {
	true;
}

ab_register_template python -- python2 python3
