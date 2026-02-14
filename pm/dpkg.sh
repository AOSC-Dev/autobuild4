#!/bin/bash
##dpkg: dpkg related functions.
##@copyright GPL-2.0+

DPKGDEBCOMP=()

# Use Zstd at the default level: 3 - see zstd(1).
DPKGDEBCOMP+=(-Zzstd -z3)

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
	_ver+="${VERSTAMP:-}"
	echo -n "$_ver"
}

dpkg_get_provides() {
	dpkg --robot -S "$@" | cut -d':' -f1 | sort -u 2>/dev/null
}

dpkgfield() {
	local _string_v="$2"
	local _ver="$(dpkgpkgver)"
	ab_tostringarray _string_v
	# first-pass: check for auto-deps notations
	for _v in "${_string_v[@]}"; do
		if [ "${_v}" = "@AB_AUTO_SO_DEPS@" ]; then
			if ! ((${#__AB_SO_DEPS})); then
				abdie "Auto dependency discovery requested, but no ELF dependency was found!" >&2
			fi
			local _data
			_data="$(dpkg_get_provides "${__AB_SO_DEPS[@]}")"
			abdbg "Auto dependency discovery found: ${_data}" >&2
			while read -r LINE; do
				_string_v+=("$LINE")
			done <<< "${_data}"
		fi
		if [ "${_v}" = "@AB_SPIRAL_PROVIDES@" ]; then
			for SPIRAL_PROV in "${__ABSPIRAL_PROVIDES[@]}"; do
				_string_v+=("${SPIRAL_PROV}_spiral")
			done
		fi
	done
	# second-pass: actually fill in the blanks
	local _buffer=()
	local _s_arch=()
	for _v in "${_string_v[@]}"; do
		if [[ "${_v}" = '@'* ]]; then
			continue
		elif [[ "${_v}" = "$PKGNAME" ]]; then
			# skip itself
			continue
		fi
		if ((VER_NONE_ALL)); then			# name-only
			name="${1/%_}"
			_buffer+=("${name/[<>=]=*}");
		elif [[ "${_v}" =~ [\<\>=]= ]]; then
			_buffer+=("$(abpm_debver "${_v}")")
		elif [[ "${_v}" =~ _spiral$ ]]; then
			# Remove _spiral marker, append version
			if [[ "${DPKG_ARCH%%_*}" == noarch ]] || [[ "${_v%_spiral}" = *:* ]]; then
				_buffer+=("$(abpm_debver "${_v%_spiral}==${PKGEPOCH_SPIRAL:-0}:${_ver#*:}")")
			else
				_s_arch+=($(abpm_deb_arch_name "${DPKG_ARCH%%_*}"))
				for _arch in "${_s_arch[@]}"; do
					_buffer+=("$(abpm_debver "${_v%_spiral}:${_arch}==${PKGEPOCH_SPIRAL:-0}:${_ver#*:}")")
				done
			fi
		elif ((VER_NONE)) || [[ "$_v" =~ _$ ]]; then
			_buffer+=("${_v%_}");
		else
			_buffer+=("$(abpm_debver "${_v}>=$(dpkg_getver "${_v}")")")
		fi
	done
	local _content="$(ab_join_elements _buffer $', ')"
	[ "${_content}" ] && echo "$1: ${_content}"
}

dpkgctrl() {
	local arch="${DPKG_ARCH%%_*}"
	[[ "$arch" == noarch ]] && arch=all
	echo "Package: $PKGNAME"
	echo "Version: $(dpkgpkgver)"
	echo "Architecture: $arch"
	[ "$PKGSEC" ] && echo "Section: $PKGSEC"
	echo "Maintainer: $MTER"
	echo "Installed-Size: $(du -s "$PKGDIR" | cut -f 1)"
	echo "Description: $PKGDES"
	echo "Description-md5: $(echo "$PKGDES" | md5sum | cut -d ' ' -f 1)"
	if ((PKGESS)); then
		echo "Essential: yes"
	else
		echo "Essential: no"
	fi

	dpkgfield Depends "$PKGDEP"
	dpkgfield Pre-Depends "$PKGPRDEP"
	VER_NONE=1 # We don't autofill versions in optional fields
	dpkgfield Recommends "$PKGRECOM"
	dpkgfield Replaces "$PKGREP"
	dpkgfield Conflicts "$PKGCONFL"

	if bool "$ABSPIRAL"; then
		PKGPROV+=" @AB_SPIRAL_PROVIDES@"
		if [[ "${arch}" = 'all' ]]; then
		    # Arch: all packages that has Spiral enabled must be marked as Multi-Arch: foreign,
			# otherwise dpkg will not allow them to satisfy dependencies for other architectures (e.g. loong64 vs loongarch64).
			echo "Multi-Arch: foreign"
		fi
	fi
	dpkgfield Provides "$PKGPROV"

	dpkgfield Suggests "$PKGSUG"
	local _pkgbreak
	_pkgbreak="$(ab_get_item_by_key __ABMODIFIERS PKGBREAK 1)"
	if [ "${_pkgbreak}" = '0' ]; then
		abwarn 'Not emitting PKGBREAK due to modifiers' >&2
	else
		dpkgfield Breaks "$PKGBREAK"
	fi
	if [ -e "$SRCDIR"/autobuild/extra-dpkg-control ]; then
		cat "$SRCDIR"/autobuild/extra-dpkg-control
	fi
	# Record last packager in control, we will switch to another variable
	# name for this field to differentiate between maintainers and
	# packagers for specific packages.
	echo "X-AOSC-Packager: ${PKGER:-$MTER}"
	echo "X-AOSC-Autobuild4-Version: ${AB4VERSION}"

	# Only write this field if it's not empty
	if [ ! -z "$PKGFTR" ]; then
		echo "X-AOSC-Features: ${PKGFTR}"
	fi

	echo "$DPKGXTRACTRL"
}

dpkgctrl_dbg() {
	local arch="${DPKG_ARCH%%_*}"
	[[ "$arch" == noarch ]] && arch=all
	echo "Package: $PKGNAME-dbg"
	echo "Version: $(dpkgpkgver)"
	echo "Architecture: $arch"
	echo "Section: debug"
	echo "Maintainer: $MTER"
	echo "Installed-Size: $(du -s "$SYMDIR" | cut -f 1)"
	echo "Description: Debug symbols for $PKGNAME"
	echo "Description-md5:  $(echo "Debug symbols for $PKGNAME" | md5sum | cut -d ' ' -f 1)"

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
		DEBIAN_FRONTEND=noninteractive \
			dpkg --force-confnew --auto-deconfigure -i "$i" \
		|| abdie "Failed to install $i: $?"
	done
}

pm_build_package() {
	local _file="${PKGNAME}_${PKGVER}-${PKGREL}${VERSTAMP:-}_${DPKG_ARCH%%_*}.deb"
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
	local _file="${PKGNAME}-dbg_${PKGVER}-${PKGREL}${VERSTAMP:-}_${DPKG_ARCH%%_*}.deb"
	mkdir -p "$SYMDIR"/DEBIAN \
			|| abdie "Failed to create DEBIAN directory for -dbg .deb metadata: $?."
		dpkgctrl_dbg > "$SYMDIR"/DEBIAN/control \
			|| abdie "Failed to generate -dbg .deb control metadata: $?."
	dpkg_deb_build "$SYMDIR" "${_file}" || abdie "Failed to build debug .deb package: $?."
	AB_PACKAGES+=("${_file}")
}
