#!/bin/bash
##15-perl.sh: Builds Makefile.PL stuff
##@copyright GPL-2.0+

build_perl_probe() {
	[ -f "$SRCDIR"/Makefile.PL ] || \
		[ -h "$SRCDIR"/Makefile.PL ] || \
			[ -f "$SRCDIR"/Build.PL ] || \
				[ -h "$SRCDIR"/Build.PL ]
}

build_perl_configure() {
	BUILD_START
	if [ -e "$SRCDIR"/Makefile.PL ]; then
		abinfo "Generating Makefile from Makefile.PL ..."
		PERL_MM_USE_DEFAULT=1 \
                perl -I"$SRCDIR" Makefile.PL INSTALLDIRS=vendor \
                || abdie "Makefile generation failed: $?."
	elif [ -e "$SRCDIR"/Build.PL ]; then
		abinfo "Generating Build from Build.PL ..."
		PERL_MM_USE_DEFAULT=1 \
		perl -I"SRCDIR" Build.PL INSTALLDIRS=vendor \
		|| abdie "Build generation failed: $?."
	else
		abdie "Unrecognized type, does this not seem to be a Perl package?: $?."
	fi
}

build_perl_build() {
	BUILD_READY
	ab_tostringarray MAKE_AFTER
	abinfo "Building Perl package ..."
	if [ -e "$SRCDIR"/Makefile ]; then
		make \
			V=1 VERBOSE=1 "${MAKE_AFTER[@]}" \
			|| abdie "Failed to build Perl (Makefile.PL) package: $?."
	elif [ -e "$SRCDIR"/Build ]; then
		perl Build \
			|| abdie "Failed to build Perl (Build.PL) package: $?."
	else
		abdie "The configure phase seems to have failed to generate Build or Makefile files correctly: $?."
	fi
}

build_perl_install() {
    BUILD_FINAL
	abinfo "Installing Perl package ..."
	if [ -e "$SRCDIR"/Makefile ]; then
		make \
			V=1 VERBOSE=1 DESTDIR="$PKGDIR" install \
			|| abdie "Failed to install Perl (Makefile.PL) package: $?."
	elif [ -e "$SRCDIR"/Build ]; then
		perl \
			Build install --destdir="$PKGDIR" \
			|| abdie "Failed to install Perl (Build.PL) package: $?."
	else
		abdie "An error occurred during the installation process: $?."
	fi
}
echo 1
