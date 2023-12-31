#!/bin/bash
##lib/builtins.sh: Built-in functions.
##@copyright GPL-2.0+

PATCHFLAGS=("-Np1" "-t")
RPATCHFLAGS=("-Rp1" "-t")

ab_apply_patches() {
	for i in "$@"; do
		if [[ -e $i ]];then
			abinfo "Applying patch $(basename "$i") ..."
			patch "${PATCHFLAGS[@]}" -i "$i" || abdie "Applying patch $i failed"
		fi
	done
}

ab_reverse_patches() {
	for i in "$@"; do
		if [[ -e $i ]];then
			abinfo "Reverting patch $(basename "$i") ..."
			patch "${RPATCHFLAGS[@]}" -i "$i" || abdie "Reverting patch $i failed"
		fi
	done
}

## ab_trim_args var
## Minimize the whitespace characters inside the variable "$var"
## NOTE: This function modifies the variable IN-PLACE and does not return any value.
## Example: ab_trim_args CFLAGS
ab_trim_args() {
	local arg
	declare -n arg="$1"
	arg="$(tr -s ' ' <<< "${arg}")"
}
