#!/bin/bash
##proc/build_do: So we build it now
##@copyright GPL-2.0+

MIGRATE_REQUIRED=(AUTOTOOLS_DEF CMAKE_DEF MESON_DEF WAF_DEF QTPROJ_DEF MAKE_INSTALL_DEF)

for i in "${MIGRATE_REQUIRED[@]}"; do
    abmm_array_mine "$i"
done

if arch_findfile -2 prepare > /dev/null; then
    abinfo 'Running pre-build (prepare) script ...'
    arch_loadfile_strict -2 prepare
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

abinfo "${ABTYPE} > Running configure step ..."
"build_${ABTYPE}_configure" || abdie "Configure failed: $?."
abinfo "${ABTYPE} > Running build step ..."
"build_${ABTYPE}_build" || abdie "Build failed: $?."
abinfo "${ABTYPE} > Running install step ..."
"build_${ABTYPE}_install" || abdie "Install failed: $?."

cd "$SRCDIR" || abdie "Unable to cd $SRCDIR: $?."

[ -d "$PKGDIR" ] || abdie "50-build: Suspecting build failure due to missing PKGDIR."

if arch_findfile -2 beyond; then
    abinfo 'Running after-build (beyond) script ...'
    arch_loadfile_strict -2 beyond
fi

cd "$SRCDIR" || abdie "Unable to cd $SRCDIR: $?."

__overrides=
if arch_findfile -2 overrides __overrides && [ -d "${__overrides}" ]; then
    abinfo "Deploying files in overrides ..."
	cp -arvT "${__overrides}"/ "$PKGDIR/" || \
		abdie "Failed to deploy files in overrides: $?."
fi

cd "$SRCDIR" || abdie "Unable to cd $SRCDIR: $?."

unset -f BUILD_{START,READY,FINAL}
unset __overrides
for i in "${MIGRATE_REQUIRED[@]}"; do
    abmm_array_mine_remove "$i"
done
