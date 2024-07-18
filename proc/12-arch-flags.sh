#!/bin/bash
##proc/flags: makes *FLAGS from arch/
##@copyright GPL-2.0+


ab_arch_setflags() {
    local AB_FLAGS_FEATURES=(LTO PERMISSIVE)
    local AB_FLAGS_TYPES=('' _OPTI _ARCH_BASE _ARCH)
    local flagtypes=(LDFLAGS CFLAGS CPPFLAGS CXXFLAGS OBJCFLAGS OBJCXXFLAGS RUSTFLAGS)
    local features=('')
    local hwcaps=()
    local _cc
    local hwcaps_active=0
    _cc="$(basename "$CC")"
    _cc="${_cc%%-*}"
    _cc="${_cc^^}"

    if bool "$HAS_HWCAPS" ; then
        # Packager can enable it.
        abdbg "This architecture has HWCAPS support."
        if ! bool "$AB_HWCAPS" ; then
            abdbg "HWCAPS is disabled for the current package."
        else
            hwcaps+=("${HWCAPS[@]}")
            abdbg "HWCAPS subtargets: ${hwcaps[@]}"
            if [ "${#hwcaps[@]}" -lt 1 ] ; then
                abdie "HWCAPS support is enabled for $ARCH, but no subtargets specified. Please check ${AB}/arch/$ARCH.sh."
            fi
            hwcaps_active=1
        fi
    fi
    for feature in "${AB_FLAGS_FEATURES[@]}"; do
        if (("USE$feature")); then
            features+=("_$feature")
        elif (("NO$feature")); then
            features+=("_NO$feature")
        else
            features+=("_$feature")
        fi
    done

    for flagtype in "${flagtypes[@]}"; do
        declare "_${flagtype}"=""  # initialize the variable
        declare -a "_${flagtype}"  # convert to an array
        if bool "$hwcaps_active" ; then
            for cap in "${hwcaps[@]}" ; do
                declare "_${flagtype}_HWCAPS_${cap//-/_}"=""
                declare -a "_${flagtype}_HWCAPS_${cap//-/_}"
            done
        fi
        for suffix in "${AB_FLAGS_TYPES[@]}"; do
            for f in "${features[@]}"; do
                for cc in "${_cc}" 'COMMON'; do
                    local flagname="${flagtype}_${cc}${suffix}${f}"
                    if abisarray "${flagname}"; then
                        ab_concatarray "_${flagtype}" "${flagname}"
                    fi
                done
            done
            if [ "$suffix" = "_ARCH_BASE" ] && bool "$hwcaps_active"; then
                # Inject HWCAPS flags arrays now.
                # _COMMON_ARCH includes default arch.specific tunes.
                for cap in "${HWCAPS[@]}" ; do
                    if abisarray "_${flagtype}_HWCAPS_${cap//-/_}" ; then
                        var="_${flagtype}[@]"
                        arr=("${!var}")
                        # Make a copy of _${flagtype}[@].
                        ab_concatarray "_${flagtype}_HWCAPS_${cap//-/_}" "_${flagtype}"
                        # If defined, concatenate the temporary array with the defined array.
                        if abisarray "${flagtype}_HWCAPS_${cap//-/_}" ; then
                            ab_concatarray "_${flagtype}_HWCAPS_${cap//-/_}" "${flagtype}_HWCAPS_${cap//-/_}"
                        fi
                    fi
                done
            fi
        done
        # merge flags if needed
        case "${flagtype}" in
            CXXFLAGS|OBJCFLAGS)
            ab_concatarray "_${flagtype}" _CFLAGS
            ;;
            OBJCXXFLAGS)
            ab_concatarray "_${flagtype}" _CXXFLAGS
            ;;
        esac
        # convert to string
        declare -n _tmp="_${flagtype}"
        export "${flagtype}"="${_tmp[*]}"
        abdbg "${flagtype}=${_tmp[*]}"

    # Do the same thing if HWCAPS is enabled
    if bool "$hwcaps_active" ; then
        for cap in "${hwcaps[@]}" ; do
        case "${flagtype}" in
            CXXFLAGS|OBJCFLAGS)
            ab_concatarray "_${flagtype}_HWCAPS_${cap//-/_}" "_CFLAGS_HWCAPS_${cap//-/_}"
            ;;
            OBJCXXFLAGS)
            ab_concatarray "_${flagtype}_HWCAPS_${cap//-/_}" "_CXXFLAGS_HWCAPS_${cap//-/_}"
            ;;
        esac
        declare -n _tmp="_${flagtype}_HWCAPS_${cap//-/_}"
        unset "${flagtype}_HWCAPS_${cap//-/_}"
        export "${flagtype}_HWCAPS_${cap//-/_}"="${_tmp[*]}"
        abdbg "${flagtype}_HWCAPS_${cap//-/_}"="${_tmp[*]}"
        done

    fi
    done
    export AB_HWCAPS_ACTIVE=$hwcaps_active
}

ab_arch_setflags
