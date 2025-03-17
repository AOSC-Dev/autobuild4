#!/bin/bash
##gettext.sh: Make sure Gettext related variables are defined
##@copyright GPL-2.0+

# NOTE: Avoid using TEXTDOMAIN to prevent unexpected usage of Gettext (yes,
#       bash scripts are i18n capable).
# NOTE: Maintainers have to explicitly define the available languages.
# NOTE: Maintainers have to explicitly define the source files used to
#       generate the PO template file.

# Skip if we are in stage 2 mode (since we may not have Gettext tools and
# other tools that is required by this).
bool $ABSTAGE2 && return 0

gettext_notdefined=()

if ! [ -d "$SRCDIR"/autobuild/po ] ; then
	# We don't have PO files. Skip this check.
	return 0
fi

# Check if a template file exists.
gettext_potfiles=("$(find "$SRCDIR"/autobuild/po -name '*.pot' -print "%P\\n")")
if [ "${#gettext_potfiles[@]}" -lt 1 ] ; then
	aberr "QA (E404): Missing PO Template file in autobuild/po!" | tee -a "$SRCDIR"/abqaerr.log
fi
if [ "${#gettext_potfiles[@]}" -gt 1 ] ; then
	aberr "QA (E403): More than one POT files are found in autobuild/po!" \
		| tee -a "$SRCDIR"/abqaerr.log
fi

# Check required variables.
for i in GETTEXT_DOMAIN GETTEXT_LINGUAS GETTEXT_SRCS ; do
	if ! abisdefined "$i" ; then
		gettext_notdefined+=("$i")
	fi
done
if [ "${#gettext_notdefined[@]}" -ge 1 ] ; then
	aberr "QA (E401): Missing Gettext related definition in defines:\n\t${gettext_notdefined[@]}" \
		| tee -a "$SRCDIR"/abqaerr.log
fi

# Check if the POT file actually exists.
if [ ! -e "$SRCDIR"/autobuild/po/"$GETTEXT_DOMAIN".pot ] ; then
	aberr "QA (E404): PO Template $GETTEXT_DOMAIN.pot does not exist!" \
		| tee -a "$SRCDIR"/abqaerr.log
fi

# Check if the source files exists and lives within the autobuild/ directory.
gettext_nosrc=()
for src in "${GETTEXT_SRCS[@]}" ; do
	if [ ! -f "$SRCDIR"/autobuild/"$src" ] ; then
		gettext_nosrc+=("$src")
	fi
done
if [ "${#gettext_nosrc[@]}" -gt 0 ] ; then
	aberr "QA (E403): The following sources defined in \${GETTEXT_SRCS[@]} does not exist:\n\t${gettext_nosrc[*]}" \
		| tee -a "$SRCDIR"/abqaerr.log
fi

# GETTEXT_DOMAIN must start with aosc- to avoid naming collisions.
if [ "x${GETTEXT_DOMAIN##aosc-}" = "x$GETTEXT_DOMAIN" ] ; then
	aberr "QA (E403): Invalid Gettext domain: $GETTEXT_DOMAIN. Gettext domain must start with 'aosc-' to avoid naming collisions." \
		| tee -a "$SRCDIR"/abqaerr.log
fi

# Check if the POT is older than sources.
gettext_mtime_pot=$(stat --printf "%Y" "$GETTEXT_DOMAIN".pot)
gettext_mtime_src=0
for src in "${GETTEXT_SRCS[@]}" ; do
	_mtime=$(stat --printf "%Y" "$SRCDIR"/autobuild/"$src")
	if [ "$_mtime" -gt "$gettext_mtime_src" ] ; then
		gettext_mtime_src="$_mtime"
	fi
done
if [ "$gettext_mtime_src" -gt "$gettext_mtime_pot" ] ; then
	# Sources used to generate the POT is newer than the template file.
	aberr "QA (E403): Source files are newer than the PO Template $GETTEXT_DOMAIN.pot!" \
		| tee -a "$SRCDIR"/abqaerr.log
	aberr "You can use \`abpoutil update' to update the template file." \
		| tee -a "$SRCDIR"/abqaerr.log
fi
unset gettext_notdefined gettext_potfiles gettext_mtime_pot gettext_mtime_src gettext_nosrc
