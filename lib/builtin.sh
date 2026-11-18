#!/bin/bash
##lib/builtins.sh: Built-in functions.
##@copyright GPL-2.0+

PATCHFLAGS=("-Np1" "-t")
RPATCHFLAGS=("-Rp1" "-t")

argprint(){ printf '%q ' "$@"; }

ab_apply_patches() {
	if ! bool "$ABPATCHLAX"; then
		PATCHFLAGS+=('-F0')
	fi
	for i in "$@"; do
		if [[ -e $i ]];then
			abinfo "Applying patch $(basename "$i") ..."
			patch "${PATCHFLAGS[@]}" -i "$i" || abdie "Applying patch $i failed"
		fi
	done
}

ab_reverse_patches() {
	if ! bool "$ABPATCHLAX"; then
		PATCHFLAGS+=('-F0')
	fi
	for i in "$@"; do
		if [[ -e $i ]];then
			abinfo "Reverting patch $(basename "$i") ..."
			patch "${RPATCHFLAGS[@]}" -i "$i" || abdie "Reverting patch $i failed"
		fi
	done
}

## ab_match_arch "match_pattern"
## Check whether current ABHOST matches the match_pattern
## Example: ab_match_arch "+(amd64|arm64)"
## See also: https://www.gnu.org/software/bash/manual/html_node/Pattern-Matching.html
ab_match_arch() {
	# Check whether the calling of function is illegal
	if [[ -z $1 ]]; then
		aberr "ab_match_arch() was called but no pattern was specified."
		abinfo "Usage: ab_match_arch \"match_pattern\""
		abdie "Misuse of ab_match_arch()! Refuse to proceed."
	fi
	if [[ ${ABHOST} = $1 ]]; then
		abinfo "Architecture $ABHOST matches $1: taking true branch."
		return 0
	else
		abinfo "Architecture $ABHOST mismatches $1: taking false branch."
		return 1
	fi
}

## ab_match_archgroup "group_match_pattern"
## Check whether current ABHOST is in a specific arch group, using bash pattern matching.
## See /sets/arch_groups/ for group information
## Example: ab_match_archgroup "+(mainline|ocaml_native)"
ab_match_archgroup() {
	# Check whether the calling of function is illegal
	if [[ -z $1 ]]; then
		aberr "ab_match_archgroup() was called but no group was specified."
		abinfo "Usage: ab_match_archgroup \"group_match_pattern\""
		abdie "Misuse of ab_match_archgroup()! Refuse to proceed."
	fi
	# A little more robustness here
	if ! ab_typecheck -a ABHOST_GROUP; then
		abwarn "Current ABHOST $ABHOST does not belong to any arch group."
		abwarn "Taking false branch."
		return 1
	fi
	for _grp in "${ABHOST_GROUP[@]}"; do
		if [[ ${_grp%%\/*} = $1 ]]; then
			abinfo "Member '${_grp}' in Architecture group '${ABHOST_GROUP[*]}' matches $1: taking true branch."
			return 0
		else
			abdbg "Member '${_grp}' in Architecture group '${ABHOST_GROUP[*]}' mismatches $1."
		fi
	done
	abinfo "All architecture group members '${ABHOST_GROUP[*]}' mismatches $1: taking false branch."
	return 1
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

## ab_log_configuring_command cmd...
## Log a command to configure the build
## Example: ab_log_configuring_command "${CONFIGURE_CMD[@]}"
ab_log_configuring_command() {
	local CMD_STRING
	if [[ $# -gt 1 ]]; then
		# log each argument on a line
		# with '\' as the line break
		CMD_STRING="$1"$' \\\n'
		shift
		while [[ $# -gt 1 ]]; do
			CMD_STRING+=$'\t'"$1"$' \\\n'
			shift
		done
		CMD_STRING+=$'\t'"$1"
	else
		CMD_STRING="$1"
	fi
	abdbg "== Command used to configure the build =="$'\n\n'"${CMD_STRING}"$'\n'
	abdbg "== End of command used to configure the build =="
}


function __ab_replace_string_build_expr() {
	sep='`'
	pattern=${1//$sep/\\$sep}
	replacement=${2//$sep/\\$sep}
	expr="s""$sep$pattern$sep$replacement$sep""g"
	abinfo "expression=$expr"
	echo "$expr"
}

function __ab_replace_string_misuse() {
help="Usage: ab_replace_string [options].. [--] {regexp replacement} input{..} {[output]}
Options:
	-E
		use extended regexp
	-e regexp replacement
		replace regexp with replacement, can repeat multiple times
	-i
		in place replace files, mutually exclusive with -o
	-o output
		output to file, mutually exclusive with -i
	--
		stop option parsing

all known options are parsed first
then if no -e specified, remain parameter 1 and 2 are taken as regexp and replacement
then if no -i or -o specified, remain parameter 1 and 2 are taken as input and output
else all remain parameters are taken as input
when multiple input exists and -o specified, output contains all input replaced and concatenated
"
	aberr "$1"
	abinfo "$help"
	abdie "Misuse of ab_replace_string()! Refuse to proceed."
}

## ab_replace_string
## Replace pattern in file
## Example: ab_replace_string %VER% 1.2.3 "$PKGDIR/autobuild/postinst.in" "$PKGDIR/autobuild/postinst"
## Example: ab_replace_string -e a b -e c d -- input
## Example: ab_replace_string -E -o output regex replaced input1 input2
function ab_replace_string() {
	expr_list=()
	sed_args=()
	argv=()
	dst=""
	in_place=0
	# parse argv
	while [[ $# -gt 0 ]]; do
		case $1 in
			-e)
				if [[ $# -lt 3 ]]; then
					__ab_replace_string_misuse "-e require 2 parameters"
				fi
				expr_list+=("$(__ab_replace_string_build_expr "$2" "$3")")
				shift 3
				;;
			-E)
				sed_args+=(-E)
				shift
				;;
			-o)
				dst="$2"
				shift 2
				;;
			-i)
				in_place=1
				shift
				;;
			--)
				shift
				argv+=("$@")
				break
				;;
			*)
				if [[ $1 == "-*" ]]; then
					# compatibility note, in case of future expansion
					abwarn "unknown option $1, treat as addtional parameter (consider use '--')"
				fi
				argv+=("$1")
				shift
				;;
		esac
	done

	# parse additional parameter
	if [[ 0 -eq ${#expr_list[@]} ]]; then
		# no pattern, find pattern in remain_argv
		if [[ ${#argv[@]} -lt 3 ]]; then
			__ab_replace_string_misuse "no pattern, require at least 3 parameters"
		fi
		expr_list+=("$(__ab_replace_string_build_expr "${argv[0]}" "${argv[1]}")")
		argv=("${argv[@]:2}")
	fi

	case ${#argv[@]} in
		0)
			__ab_replace_string_misuse "no input file, require at least 1 parameter"
			;;
		1)
			srcs=("${argv[0]}")
			in_place=1
			;;
		2)
			srcs=("${argv[0]}")
			dst="${argv[1]}"
			;;
		*)
			if [[ -z $dst && ! $in_place ]]; then
				__ab_replace_string_misuse "more than 3 files specified, enable either -i or -o option"
			fi
			srcs=("${argv[@]}")
			;;
	esac

	for e in "${expr_list[@]}"; do
		sed_args+=(-e "$e")
	done

	if [[ -e "$dst" ]]; then
		abinfo "destination already exist, clearing content"
		echo "" > "$dst"
	fi

	for src in "${srcs[@]}"; do
		tmp=$(mktemp "ab_replace_string.XXXXXXXX")

		abdbg "sed ${sed_args[*]} $src > $tmp"
		sed "${sed_args[@]}" "$src" > "$tmp"

		if cmp --silent -- "$src" "$tmp"; then
			abwarn "Replaced nothing, aborting ..."
			abinfo "Content of $src :"
			cat "$src"
			if [[ -n "$tmp" ]]; then
				rm "$tmp"
			fi
			abdie "Replaced nothing in $src"
		fi

		if [[ $in_place ]]; then
			cat "$tmp" > "$src"
		else
			cat "$tmp" >> "$dst"
		fi
		rm "$tmp"
	done
}
