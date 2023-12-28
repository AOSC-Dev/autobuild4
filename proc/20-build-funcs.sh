#!/bin/bash
##proc/build_funcs: Loads the build/ functions
##@copyright GPL-2.0+

AB_TEMPLATES=()

# shellcheck disable=SC2317
ab_register_template() {
	local name="$1"
	if [ -z "$1" ]; then
        abdie "Internal error: No template specified"
	fi
	local _error=
	for fragment in "build_${1}_probe" "build_${1}_configure" "build_${1}_build" "build_${1}_install"; do
		if ! ab_typecheck -f "$fragment"; then
			aberr "Internal error: Template $1 does not have required function '$i'."
			_error=1
		fi
	done
	if [ "$_error" = 1 ]; then
		abdie "Internal error: Template ${name} contains error. Can't continue."
	fi
	if [ "$2" = '--' ]; then
		shift 2;
		for exe in "$@"; do
			if ! command -v "$exe" > /dev/null; then
				abdie "Template ${name} requires $exe but was not found on the system."
			fi
		done
	fi
	abdbg "Registered build template: ${name}"
    AB_TEMPLATES+=("${name}")
}

for i in "$AB/templates"/*.sh
do
	. "$i"
done

unset -f ab_register_template
