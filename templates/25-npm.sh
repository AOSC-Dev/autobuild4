#!/bin/bash
##25-npm.sh: Builds NPM registry archives
##@copyright GPL-2.0+
abtryexe node npm || ((!ABSTRICT)) || ablibret

build_npm_probe(){
	[ -f "$SRCDIR"/package.json ]
}

build_npm_audit(){
	if bool "$NONPMAUDIT"; then
		return 0;
	fi
	if [ -f "$SRCDIR"/yarn.lock ]; then
		yarn audit \
			|| abdie 'Vulnerabilities detected! Aborting...'
	elif [ -f "$SRCDIR"/packages-lock.json ]; then
		npm audit \
			|| abdie 'Vulnerabilities detected! Aborting...'
	else
		abdie "The project does not contain any lock files. Unable to conduct the audit: $?."
	fi
}

build_npm_configure() {
	BUILD_START
	true;
}

build_npm_build(){
	BUILD_READY
	abinfo "Creating a symlink to make NPM happy ..."
	ln -sv "$SRCDIR/../$PKGNAME-$PKGVER."* "$PKGNAME-$PKGVER.tgz" \
		|| abdie "Failed to make NPM happy: $?."
}

build_npm_install() {
	BUILD_FINAL
	abinfo "Installing NPM package ..."
	npm install --production -g --user root \
		--prefix "$PKGDIR"/usr "$PKGNAME-$PKGVER.tgz" \
		|| abdie "Could not install from NPM archives: $?."
}

ab_register_template npm -- node npm
