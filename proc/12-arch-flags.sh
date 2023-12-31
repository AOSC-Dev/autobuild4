#!/bin/bash
##proc/flags: makes *FLAGS from arch/
##@copyright GPL-2.0+


ab_arch_setflags() {
    local AB_FLAGS_FEATURES=(LTO PERMISSIVE)
    local AB_FLAGS_TYPES=('' _OPTI _ARCH)
    local flagtypes=(LDFLAGS CFLAGS CPPFLAGS CXXFLAGS OBJCFLAGS OBJCXXFLAGS RUSTFLAGS)
    local features=('')
    local _cc
    _cc="$(basename "$CC")"
    _cc="${_cc%%-*}"
    _cc="${_cc^^}"

    for feature in "${AB_FLAGS_FEATURES[@]}"; do
        if (("USE$feature")); then
            features+=("$feature")
        elif (("NO$feature")); then
            features+=("NO$feature")
        fi
    done

    for flagtype in "${flagtypes[@]}"; do
        declare -a "$flagtype"
        for suffix in "${AB_FLAGS_TYPES[@]}"; do
            for f in "${features[@]}"; do
                for cc in "${_cc}" 'COMMON'; do
                    local flagname="${flagtype}_${cc}${suffix}${f}"
                    if abisarray "${flagname}"; then
                        ab_concatarray "${flagtype}" "${flagname}"
                    fi
                done
            done
        done
    done
}

ab_arch_setflags
