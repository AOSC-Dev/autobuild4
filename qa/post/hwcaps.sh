#!/bin/bash
# qa/post/hwcaps.sh: QA checks for HWCAPS builds
if ! bool "$AB_HWCAPS_ACTIVE" ; then
	# Can't run this QA if HWCAPS is not active.
	return
fi

# Check if $PKGDIR/$LIBDIR exists
if [ ! -d "$PKGDIR"/"$LIBDIR"/glibc-hwcaps ] ; then
	aberr "QA (E331): \`glibc-hwcaps' directory not found in PKGDIR/$LIBDIR!" | \
		tee -a "$SRCDIR"/abqaerr.log
	return
fi

# Check if any HWCAPS subdirectory exists
hwcaps_subdirs=()
for tgt in "${HWCAPS[@]}" ; do
	dir="$PKGDIR"/"$LIBDIR"/glibc-hwcaps/"$tgt"
	if [ -d "$dir" ] ; then
		hwcaps_subdirs+=("$dir")
	fi
done
if [ "${#hwcaps_subdirs[@]}" -lt 1 ] ; then
	aberr "QA (E332): None of the HWCAPS subtargets have the corresponding subdirectory installed." | \
		tee -a "$SRCDIR"/abqaerr.log
	return
fi

# Check if any files present in $PKGDIR/$LIBDIR/glibc-hwcaps.
FILES=($(find "$PKGDIR"/"$LIBDIR"/glibc-hwcaps -maxdepth 1 -type f,l))
if [ "${#FILES[@]}" -ge 1 ] ; then
	IFS=$'\n'
	aberr "QA (E333): Stray file(s) found in the glibc-hwcaps directory:\n\n${FILES[*]}\n" | \
		tee -a "$SRCDIR"/abqaerr.log
	unset IFS
fi

# Check if all installed libraries have correct permissions
badfiles=()
for tgt in "${hwcaps_subdirs[@]}" ; do
	FILES=($(find $tgt -type f,l -name '*.so.*' -not -perm /111))
	# Non executable .so files found
	for f in "${FILES[@]}" ; do
		# Check if it is an ELF file by checking its magic
		read -N4 content < $f
		if [ "$content" == $'\x7fELF' ] ; then
			badfiles+=("$f")
		fi
	done
done
if [ "${#badfiles[@]}" -ge 1 ] ; then
	IFS=$'\n'
	aberr "QA (E333): Non-executable shared object(s) found in glibc-hwcaps subdirectories:\n\n${badfiles[*]}\n" | \
		tee -a "$SRCDIR"/abqaerr.log
	unset IFS
fi
