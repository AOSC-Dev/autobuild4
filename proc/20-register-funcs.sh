#!/bin/bash
##proc/build_funcs: Loads the build/ functions
##@copyright GPL-2.0+

AB_TEMPLATES=()
AB_FILTERS=()

# shellcheck disable=SC2317
ab_register_filter() {
	local name="$1"
	if [ -z "$1" ]; then
		abdie "Internal error: No template specified"
	fi
	local _filter_name="filter_${name}"
	if ! ab_typecheck -f "${_filter_name}"; then
		aberr "Internal error: Filter ${name} does not have required function '${_filter_name}'."
	fi
	abdbg "Registered filter: ${name}"
	AB_FILTERS+=("${_filter_name}")
}

abtpl_check_exe() {
	for exe in "$@"; do
		if ! command -v "$exe" > /dev/null; then
			abdie "Template ${name} requires $exe but was not found on the system."
		fi
	done
}

# shellcheck disable=SC2317
ab_register_template() {
	local delayed_check=0
	if [ "$1" = "-l" ]; then
	    # delayed check
		delayed_check=1
        shift
	fi
	local name="$1"
	if [ -z "$1" ]; then
        abdie "Internal error: No template specified"
	fi
	local _error=
	for fragment in "build_${1}_probe" "build_${1}_configure" "build_${1}_build" "build_${1}_install"; do
		if ! ab_typecheck -f "$fragment"; then
			aberr "Internal error: Template $1 does not have required function '${fragment}'."
			_error=1
		fi
	done
	if [ "$_error" = 1 ]; then
		abdie "Internal error: Template ${name} contains error. Can't continue."
	fi
	tmp_function() {
		abtpl_check_exe "${bins[@]}"
	}
	if [ "$2" = '--' ]; then
		shift 2;
		if ((delayed_check)); then
		    local bins=("$@")
			abfp_lambda tmp_function "build_${1}_check" -- name bins
		else
			name="${name}" abtpl_check_exe "$@"
		fi
	fi
	abdbg "Registered build template: ${name}"
    AB_TEMPLATES+=("${name}")
}

for i in "$AB/templates"/*.sh "$AB/filters"/*.sh
do
	# shellcheck disable=SC1090
	. "$i"
done

unset -f ab_register_template ab_register_filter
