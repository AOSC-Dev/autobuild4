#!/bin/bash
##dpkg: dpkg related functions.
##@copyright GPL-2.0+

DPKGDEBCOMP=()

# Auto-select xz level, use lower compression level on "Retro" architectures.
if ab_match_archgroup retro; then
	DPKGDEBCOMP+=(-Zxz -z3 --threads-max=1)
# Only 2GiB of user-addressable memory.
elif ab_match_arch mips32r6el; then
	DPKGDEBCOMP+=(-Zxz -z6 --threads-max=1)
# Buggy NUMA implementation on SG2042? Causes dead locks.
elif ab_match_arch riscv64; then
	DPKGDEBCOMP+=(-Zxz -z6 --threads-max=1)
else
	DPKGDEBCOMP+=(-Zxz -z6)
fi

dpkg_deb_build() {
	dpkg-deb "${DPKGDEBCOMP[@]}" -b "$1" "$2"
}

dpkg_getver() {
	dpkg-query -f '${Version}' -W "$1" 2>/dev/null
}

dpkgpkgver() {
	local _ver=""
	((PKGEPOCH)) && _ver="$PKGEPOCH":
	_ver+="$PKGVER"
	if [ "$PKGREL" != 0 ]; then
		_ver+="-$PKGREL"
	fi
	echo -n "$_ver"
}

dpkgctrl() {
	local arch="${ABHOST%%\/*}"
	[[ "$arch" == noarch ]] && arch=all
	echo "Package: $PKGNAME"
	echo "Version: $(dpkgpkgver)"
	echo "Architecture: $arch"
	[ "$PKGSEC" ] && echo "Section: $PKGSEC"
	echo "Maintainer: $MTER"
	echo "Installed-Size: $(du -s "$PKGDIR" | cut -f 1)"
	echo "Description: $PKGDES"
	if ((PKGESS)); then
		echo "Essential: yes"
	else
		echo "Essential: no"
	fi
	# TODO: generate pkg control fields
	if [ -e "$SRCDIR"/autobuild/extra-dpkg-control ]; then
		cat "$SRCDIR"/autobuild/extra-dpkg-control
	fi
	# Record last packager in control, we will switch to another variable
	# name for this field to differentiate between maintainers and
	# packagers for specific packages.
	echo "X-AOSC-Packager: ${PKGER:-$MTER}"
	echo "X-AOSC-Autobuild4-Version: ${AB4VERSION}"
	echo "$DPKGXTRACTRL"
}

dpkgctrl_dbg() {
	local arch="${ABHOST%%\/*}"
	[[ "$arch" == noarch ]] && arch=all
	echo "Package: $PKGNAME-dbg"
	echo "Version: $(dpkgpkgver)"
	echo "Architecture: $arch"
	echo "Section: debug"
	echo "Maintainer: $MTER"
	echo "Installed-Size: $(du -s "$SYMDIR" | cut -f 1)"
	echo "Description: Debug symbols for $PKGNAME"
	echo "Depends: ${PKGNAME} (=$(dpkgpkgver))"
	# Record last packager in control, we will switch to another variable
	# name for this field to differentiate between maintainers and
	# packagers for specific packages.
	echo "X-AOSC-Packager: ${PKGER:-$MTER}"
	echo "X-AOSC-Autobuild4-Version: ${AB4VERSION}"
	echo "$DPKGXTRACTRL"
}

pm_install_all() {
	for i in "$@"; do
		dpkg --force-confnew --auto-deconfigure -i "$i" \
		|| abdie "Failed to install $i: $?"
	done
}

pm_build_package() {
	local _file="${PKGNAME}_${PKGVER}-${PKGREL}_${ABHOST%%\/*}.deb"
	mkdir -p "$PKGDIR"/DEBIAN \
		|| abdie "Failed to create DEBIAN directory for .deb metadata: $?."
	cp -rl "$SRCDIR"/abscripts/* "$PKGDIR"/DEBIAN \
		|| abdie "Failed to copy .deb scripts: $?."
	# Do not handle conffiles in stage2.
	if ! bool "$ABSTAGE2"; then
		if [ -e "$SRCDIR/autobuild/$ARCH/conffiles" ]; then
			cp -l "$SRCDIR"/autobuild/"$ARCH"/conffiles "$PKGDIR"/DEBIAN 2>/dev/null \
				|| abdie "Failed to copy conffiles: $?."
		elif [ -e "$SRCDIR/autobuild/conffiles" ]; then
			cp -l "$SRCDIR"/autobuild/conffiles "$PKGDIR"/DEBIAN 2>/dev/null \
				|| abdie "Failed to copy conffiles: $?."
		fi
	fi
	if [ -e "$SRCDIR/autobuild/triggers" ]; then
		cp -l "$SRCDIR"/autobuild/triggers "$PKGDIR"/DEBIAN 2>/dev/null \
			|| abdie "Failed to copy triggers: $?."
	fi
	dpkgctrl > "$PKGDIR"/DEBIAN/control || abdie "Failed to generate .deb control metadata: $?."
	dpkg_deb_build "$PKGDIR" "${_file}" || abdie "Failed to package .deb package: $?."
	mv "$PKGDIR"/DEBIAN "$SRCDIR"/ab-dpkg
	AB_PACKAGES+=("${_file}")
}

pm_build_debug_package() {
	local _file="${PKGNAME}-dbg_${PKGVER}-${PKGREL}_${ABHOST%%\/*}.deb"
	mkdir -p "$SYMDIR"/DEBIAN \
			|| abdie "Failed to create DEBIAN directory for -dbg .deb metadata: $?."
		dpkgctrl_dbg > "$SYMDIR"/DEBIAN/control \
			|| abdie "Failed to generate -dbg .deb control metadata: $?."
	dpkg_deb_build "$SYMDIR" "${_file}" || abdie "Failed to build debug .deb package: $?."
	AB_PACKAGES+=("${_file}")
}
