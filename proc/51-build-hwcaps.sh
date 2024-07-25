#!/bin/bash
##proc/build_do: So we build it now
##@copyright GPL-2.0+

# See if HWCAPS is active.
if ! bool "$AB_HWCAPS_ACTIVE" ; then
	abinfo "HWCAPS is not active. Skipping builds for HWCAPS subtargtes."
	unset -f BUILD_{START,READY,FINAL}
	unset __overrides
	for i in "${MIGRATE_REQUIRED[@]}"; do
		abmm_array_mine_remove "$i"
	done
	return
fi

# We might need to do something specific to builds for HWCAPS subtargtes.
# If none of these scripts exists, set up BLDDIR and PKGDIR, and invoke
# the build templates.
# If ABTYPE == self, and no HWCAPS build scripts exist, bail out.
HWCAPS_PREPARE=
HWCAPS_BUILD=
HWCAPS_BEYOND=

if [ -e "$SRCDIR"/autobuild/hwcaps/prepare ] ; then
	abinfo "Using prepare script for HWCAPS subtargtes."
	HWCAPS_PREPARE=hwcaps/prepare
fi

# Even if probed ABTYPE != self, use the build script unconditionally.
if [ -e "$SRCDIR"/autobuild/hwcaps/build-"$ARCH" ] ; then
	abinfo "Detected custom build script for HWCAPS subtargets of $ARCH."
	HWCAPS_BUILD=hwcaps/build-"$ARCH"
	export ABTYPE=self
elif [ -e "$SRCDIR"/autobuild/hwcaps/build ] ; then
	abinfo "Detected custom build script for HWCAPS subtargets."
	HWCAPS_BUILD=hwcaps/build
	export ABTYPE=self
fi

if [ "$ABTYPE" = "self" ] && [ -z "$HWCAPS_BUILD" ] ; then
	abdie "HWCAPS build is enabled, and this project uses a custom build script. \
		You need to supply a custom build script at autobuild/hwcaps/build-$ARCH."
fi

if [ -e "$SRCDIR"/autobuild/hwcaps/beyond ] ; then
	abinfo "Using beyond script for HWCAPS subtargtes."
	HWCAPS_BEYOND=hwcaps/beyond
fi

# Save BLDDIR and PKGDIR.
export OLD_BLDDIR="$BLDDIR"
export OLD_PKGDIR="$PKGDIR"

# If an in-house build script is used, do not run it for every subtarget.
if [ "$ABTYPE" != "self" ] ; then
for cap in "${HWCAPS[@]}" ; do
	# Set each build flags for the current subtarget
	flags=(CPPFLAGS CFLAGS CXXFLAGS LDFLAGS OBJCFLAGS OBJCXXFLAGS RUSTFLAGS)
	# Files to cleanup before each run. This has to be done if ABSHADOW=0.
	files=(CMakeFiles CMakeCache.txt config.status)
	for flag in "${flags[@]}" ; do
		var="${flag}_HWCAPS_${cap//-/_}[*]"
		export $flag="${!var}"
	done

	if ! bool "$ABSHADOW" ; then
		abinfo "[$cap] Cleaning up ..."
		for f in "${files[@]}" ; do
			rm -rf $f &>/dev/null || true
		done
	else
		# Set a dedicated BLDDIR for each subtarget.
		export BLDDIR="$SRCDIR/abbuild-hwcaps-$cap"
	fi
	export PKGDIR="$SRCDIR/abdist-hwcaps-$cap"

	abinfo "Building for HWCAPS subtarget $cap ..."
	if arch_findfile hwcaps/prepare > /dev/null; then
		abinfo 'Running pre-build (prepare) script ...'
		arch_loadfile_strict hwcaps/prepare
	fi

	cd "$SRCDIR"
	if ab_typecheck -f "build_${ABTYPE}_check"; then
		abinfo "${ABTYPE} > Running check step ..."
		"build_${ABTYPE}_check"
	fi

	if ab_typecheck -f "build_${ABTYPE}_audit"; then
		abinfo "${ABTYPE} > Running audit step ..."
		"build_${ABTYPE}_audit" || abdie "Audit failed: $?."
	fi
	# Trick autotools into thinking that we are performing a cross
	# compilation. The resulting $cross_compiling is `maybe', thus
	# skipping a test run.
	# This problem was observed on a non x86-64-v4 machine, while
	# building gmp.
	# mpfr requires $cross_compiling = yes. So we have to do the real
	# trick by using the generic target for --build.
	if ! bool "$AB_HWCAPS_REALLY_CROSSING" ; then
		export AUTOTOOLS_TARGET=("--host=${ARCH_TARGET[$ARCH]}")
	else
		generic_triple="${ARCH_TARGET[$ARCH]}"
		generic_triple="${generic_triple/aosc/unknown}"
		export AUTOTOOLS_TARGET=("--host=${ARCH_TARGET[$ARCH]}" "--build=${generic_triple}")
	fi

	abinfo "[$cap] ${ABTYPE} > Running configure step ..."
	"build_${ABTYPE}_configure" || abdie "Configure failed: $?."
	abinfo "[$cap] ${ABTYPE} > Running build step ..."
	"build_${ABTYPE}_build" || abdie "Build failed: $?."
	abinfo "[$cap] ${ABTYPE} > Running install step ..."
	"build_${ABTYPE}_install" || abdie "Install failed: $?."

	cd "$SRCDIR" || abdie "Unable to cd $SRCDIR: $?."

	if arch_findfile hwcaps/beyond; then
		abinfo 'Running after-build (beyond) script ...'
		arch_loadfile_strict hwcaps/beyond
	fi
	[ -d "$PKGDIR" ] || abdie "51-build-hwcaps: Suspecting build failure due to missing PKGDIR."
	abinfo "[$cap] Harvesting libraries ..."
	files=($(find "$PKGDIR"/"$LIBDIR" -maxdepth 1 -type f,l -name 'lib*.so.*'))
	if [ "${#files[@]}" -lt "1" ] ; then
		abdie "$cap: This build did not produce any libraries. How strange is that!"
	fi
	for f in "${files[@]}" ; do
		install -Dvm755 -t "$OLD_PKGDIR"/usr/lib/glibc-hwcaps/"$cap"/ "$f"
	done
done # for cap in "${HWCAPS[@]}" ; do
else # if [ "$ABTYPE" != "self" ] ; then
	if arch_findfile hwcaps/prepare ; then
		abinfo "[$cap] Running custom prepare script ..."
		arch_loadfile_strict hwcaps/prepare || abdie "Failed to run custom build script: $?."
	fi
	abinfo "[$cap] Running custom build script ..."
	arch_loadfile_strict hwcaps/$(basename $HWCAPS_BUILD) || abdie "Failed to run custom build script: $?."

	if arch_findfile hwcaps/beyond; then
		abinfo 'Running after-build (beyond) script ...'
		arch_loadfile_strict hwcaps/beyond
	fi

	if [ ! -d "$PKGDIR"/usr/lib/glibc-hwcaps ] ; then
		abdie "Hold on! No libraries installed into PKGDIR/usr/lib/glibc-hwcaps. Check your build script."
	fi
fi # if [ "$ABTYPE" != "self" ] ; then

cd "$SRCDIR" || abdie "Unable to cd $SRCDIR: $?."

# Set PKGDIR back to its original value.
export PKGDIR="$OLD_PKGDIR"

unset -f BUILD_{START,READY,FINAL}
unset __overrides
for i in "${MIGRATE_REQUIRED[@]}"; do
	abmm_array_mine_remove "$i"
done
