#!/bin/bash
##proc/scripts: Silly way to deal with scripts
##@copyright GPL-2.0+
mkdir -p abscripts

for i in postinst prerm postrm preinst; do
	# liushuyu: using an associative array can avoid using for loops to
	# test if a string exists in an array.
	if [ "x${_AB_SKIP_MAINTSCRIPTS_[$i]}" != "x" ] ; then
		if [ -f "autobuild/$i" ] ; then
			abdie "Conflict detected: $i should be skipped but autobuild/$i exists. Please remove $i from skip list or remove the file."
		fi
		abinfo "Skipping generating maintscript $i."
		continue
	fi
	echo "#!/bin/bash" > abscripts/$i
	cat autobuild/$i >> abscripts/$i 2>/dev/null || abinfo "Creating empty $i."
	chmod 755 abscripts/$i
done

if [ -f "$SRCDIR"/autobuild/templates ]; then
	abinfo "Installing Debconf templates ..."
	install -Dvm644 "$SRCDIR"/autobuild/templates abscripts/templates
fi

if [ -f "$SRCDIR"/autobuild/config ]; then
	abinfo "Installing Debconf configuration script (DEBIAN/config) ..."
	# Note: dpkg requires executable bit on DEBIAN/config.
	install -Dvm755 "$SRCDIR"/autobuild/config abscripts/config
fi

load_strict "$AB/lib/scriptlets.sh"

for i in scriptlet_alternative scriptlet_pax scriptlet_usergroup; do
    abinfo "Running scriptlet generator ${i} ..."
	"${i}"
done
