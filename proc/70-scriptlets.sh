#!/bin/bash
##proc/scripts: Silly way to deal with scripts
##@copyright GPL-2.0+
mkdir -p abscripts

for i in postinst prerm postrm preinst; do
	echo "#!/bin/bash" > abscripts/$i
	cat autobuild/$i >> abscripts/$i 2>/dev/null || abinfo "Creating empty $i."
	chmod 755 abscripts/$i
done

if [ -f "$SRCDIR"/autobuild/templates ]; then
	abinfo "Installing Debconf templates ..."
	install -Dvm644 "$SRCDIR"/autobuild/templates abscripts/templates
fi

load_strict "$AB/lib/scriptlets.sh"

for i in scriptlet_alternative scriptlet_pax scriptlet_usergroup; do
    abinfo "Running scriptlet generator ${i} ..."
	"${i}"
done
