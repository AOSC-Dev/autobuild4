#!/bin/bash
##proc/spiral.sh: Debian-compatible package name aliases lookup (Spiral)
##@copyright GPL-2.0+

if bool "$ABSPIRAL"; then
	__ABSPIRAL_PROVIDES=()
	if [[ "${#__AB_SONAMES[@]}" != 0 ]]; then
		abspiral_from_sonames "${__AB_SONAMES[@]}"
		for SPIRAL_PROV in "${__ABSPIRAL_PROVIDES_SONAMES[@]}"; do
			__ABSPIRAL_PROVIDES+=("${SPIRAL_PROV}")
		done
	fi
	if [ -d "$PKGDIR"/usr/lib/girepository-1.0 ]; then
                while read -r LINE; do
                    __ABSPIRAL_PROVIDES+=("$LINE")
                done < <( find "$PKGDIR"/usr/lib/girepository-1.0/ -name '*.typelib' -type f -printf '%f\n' | \
                   awk '{ sub(/\.typelib$/, "", $1); print "gir-" tolower($1) }' )
	fi
	if [ -d "$PKGDIR"/usr/lib/python"$ABPY2VER"/site-packages ]; then
                while read -r LINE; do
                    __ABSPIRAL_PROVIDES+=("$LINE")
                done < <( find "$PKGDIR"/usr/lib/python"$ABPY2VER"/site-packages -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | \
                   awk '{ split($1, x, "-"); gsub("_", "-", x[1]); print "python2-" tolower(x[1]); }' | sort -u )
                while read -r LINE; do
                    __ABSPIRAL_PROVIDES+=("$LINE")
                done < <( find "$PKGDIR"/usr/lib/python"$ABPY2VER"/site-packages -mindepth 1 -maxdepth 1 -type f -name "*.py" -printf '%f\n' | \
                   awk '{ split($1, x, "."); gsub("_", "-", x[1]); print "python2-" tolower(x[1]); }' | sort -u )
	fi
	if [ -d "$PKGDIR"/usr/lib/python"$ABPY3VER"/site-packages ]; then
                while read -r LINE; do
                    __ABSPIRAL_PROVIDES+=("$LINE")
                done < <( find "$PKGDIR"/usr/lib/python"$ABPY3VER"/site-packages -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | \
                   awk '{ split($1, x, "-"); gsub("_", "-", x[1]); print "python3-" tolower(x[1]); }' | sort -u )
                while read -r LINE; do
                    __ABSPIRAL_PROVIDES+=("$LINE")
                done < <( find "$PKGDIR"/usr/lib/python"$ABPY3VER"/site-packages -mindepth 1 -maxdepth 1 -type f -name "*.py" -printf '%f\n' | \
                   awk '{ split($1, x, "."); gsub("_", "-", x[1]); print "python3-" tolower(x[1]); }' | sort -u )
	fi
	if [[ "${#__ABSPIRAL_PROVIDES[@]}" != 0 ]]; then
		abdbg "Generated Debian-compatible (Spiral) provides: ${__ABSPIRAL_PROVIDES[*]}"
	else
		abdbg "No Debian-compatible (Spiral) provides generated"
	fi
fi
