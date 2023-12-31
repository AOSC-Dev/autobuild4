#!/bin/bash
##lib/builtins.sh: Built-in functions.
##@copyright GPL-2.0+

# alternative path link prio [path2 link2 prio2 ..]
alternative() {
    addalt() {
        echo "update-alternatives --install $(argprint "$@") --quiet" >> abscripts/postinst
        cat << EOF >> abscripts/prerm
if [ "\$1" != "upgrade" ]; then
	update-alternatives --remove $(argprint "$2" "$3")
fi
EOF
    }

    while (($#)); do addalt "$1" "$(basename "$1")" "$2" "$3"; shift 3 || break; done;
}

scriptlet_alternative() {
    local _altFile
    _altFile="$(arch_findfile -2 alternatives || true)"
    if [ -z "$_altFile" ]; then
        abinfo "No alternatives file found."
        return 0
    fi

    abinfo "Taking alternatives file: ${_altFile}"
    echo "#>start 01-alternatives" >> abscripts/postinst
	echo "#>start 01-alternatives" >> abscripts/prerm
    load_strict "${_altFile}"
    echo "#>end 01-alternatives" >> abscripts/postinst
	echo "#>end 01-alternatives" >> abscripts/prerm

    unset -f alternative
}

scriptlet_pax() {
    # shellcheck disable=SC2317
    abpaxctl() {
        local paxflags="$1"
        shift
        echo "if [ -x /usr/bin/paxctl-ng ]; then" >> abscripts/postinst
        for i in "$@"; do
            echo "  /usr/bin/paxctl-ng -v -$paxflags \"$i\"" >> abscripts/postinst
        done
        echo "fi" >> abscripts/postinst
    }
    local _paxFile
    _paxFile="$(arch_findfile -2 pax || true)"
    if [ -z "$_paxFile" ]; then
        abinfo "No pax file found."
        return 0
    fi

    abinfo "Taking pax file: ${_paxFile}"
    echo "#>start 02-pax" >> abscripts/postinst
    load_strict "${_paxFile}"
    echo "#>end 02-pax" >> abscripts/postinst
}

scriptlet_usergroup() {
    # user LOGIN UID GID HOME COMMENT SHELL [GROUPS..]
    # shellcheck disable=SC2317
    user() {
        local _numeric_gid=${usermaps["$3"]}
        if [ -z "$_numeric_gid" ]; then
            _numeric_gid="$3"
        fi
        echo "u    $1  $2:$_numeric_gid \"$5\" $4  $6"
        shift 6
        for i in "$@"; do
            echo "m    $1  $i"
        done
    }
    # group NAME GID
    # shellcheck disable=SC2317
    group() {
        usermaps["$1"]="$2"
        echo "g    $1  $2"
    }
    if [ ! -e autobuild/usergroup ]; then
        abinfo "No usergroup file found."
        return 0
    fi
    declare -A usermaps
    aberr "API removed: user and group commands are removed in Autobuild4"
    abinfo "Please use systemd-sysusers instead. See sysusers.d(5) for more information."
    abinfo "You may use the following auto-generated configuration file as a start:"
    echo '#Type Name       ID                  GECOS              Home directory Shell'
    load_strict autobuild/usergroup
    unset usermaps
    return 1
}
