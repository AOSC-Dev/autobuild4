#!/bin/bash
##proc/spiral.sh: Debian-compatible package name aliases lookup (Spiral)
##@copyright GPL-2.0+

if bool "$ABSPIRAL"; then
	__ABSPIRAL_PROVIDES=()
	if [[ "${#__AB_SONAMES[@]}" != 0 ]]; then
		abspiral_from_sonames "$AB/data/lut_sonames" "${__AB_SONAMES[@]}"
		for SPIRAL_PROV in "${__ABSPIRAL_PROVIDES_SONAMES[@]}"; do
			__ABSPIRAL_PROVIDES+=("${SPIRAL_PROV}")
		done
	fi
	if [ -d "$PKGDIR"/usr/lib/girepository-1.0 ]; then
		for gir in `find "$PKGDIR"/usr/lib/girepository-1.0/ -type f`; do
			__ABSPIRAL_PROVIDES+=("$(echo gir1.2-$(basename $gir) | \
				sed -e 's|.typelib$||g' | \
				tr '[:upper:]' '[:lower:]')")
		done
	fi
	if [ -d "$PKGDIR"/usr/lib/python"$ABPY2VER"/site-packages ]; then
		for py2mod in `find "$PKGDIR"/usr/lib/python"$ABPY2VER"/site-packages -mindepth 1 -maxdepth 1 -type d`; do
			__ABSPIRAL_PROVIDES+=("$(echo python${ABPY2VER:0:1}-$(basename $py2mod | cut -f1 -d'-') | \
				sort -u | \
				sed -e 's|_|-|g' | \
				tr '[:upper:]' '[:lower:]')")
		done
		for py2mod in `find "$PKGDIR"/usr/lib/python"$ABPY2VER"/site-packages -mindepth 1 -maxdepth 1 -type f -name '*.py'`; do
			__ABSPIRAL_PROVIDES+=("$(echo python${ABPY2VER:0:1}-$(basename $py2mod | cut -f1 -d'.') | \
				sort -u | \
				sed -e 's|_|-|g' | \
				tr '[:upper:]' '[:lower:]')")
		done
	fi
	if [ -d "$PKGDIR"/usr/lib/python"$ABPY3VER"/site-packages ]; then
		for py3mod in `find "$PKGDIR"/usr/lib/python"$ABPY3VER"/site-packages -mindepth 1 -maxdepth 1 -type d`; do
			__ABSPIRAL_PROVIDES+=("$(echo python${ABPY3VER:0:1}-$(basename $py3mod | cut -f1 -d'-') | \
				sort -u | \
				sed -e 's|_|-|g' | \
				tr '[:upper:]' '[:lower:]')")
		done
		for py3mod in `find "$PKGDIR"/usr/lib/python"$ABPY3VER"/site-packages -mindepth 1 -maxdepth 1 -type f -name '*.py'`; do
			__ABSPIRAL_PROVIDES+=("$(echo python${ABPY3VER:0:1}-$(basename $py3mod | cut -f1 -d'.') | \
				sort -u | \
				sed -e 's|_|-|g' | \
				tr '[:upper:]' '[:lower:]')")
		done
	fi
	if [[ "${#__ABSPIRAL_PROVIDES[@]}" != 0 ]]; then
		abdbg "Generated Debian-compatible (Spiral) provides: ${__ABSPIRAL_PROVIDES[@]}"
	else
		abdbg "No Debian-compatible (Spiral) provides generated"
	fi
fi
