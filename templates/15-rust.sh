#!/bin/bash
##15-rust.sh: Builds Rust + Cargo projects
##@copyright GPL-2.0+

DEFAULT_CARGO_CONFIG=(
--config 'profile.release.lto = true'
--config 'profile.release.incremental = false'
--config 'profile.release.codegen-units = 1'
--config 'profile.release.strip = false'
)

build_rust_prepare_registry() {
	local REGISTRY_URL='https://github.com/rust-lang/crates.io-index'
	local REGISTRY_DIR='github.com-1ecc6299db9ec823'
	local THIS_REGISTRY_DIR="$HOME/.cargo/registry/index/${REGISTRY_DIR}/.git"

	if [ ! -d "${THIS_REGISTRY_DIR}" ]; then
		git clone --bare "${REGISTRY_URL}" "${THIS_REGISTRY_DIR}"
	fi
}

build_rust_get_installed_rust_version() {
    rustc --version | perl -ne '/^rustc\s+(\d+\.\d+\.\d+)\s+\(/ && print"$1\n"'
}

build_rust_probe() {
	[ -f "$SRCDIR"/Cargo.toml ]
}

build_rust_inject_lto() {
	bool "${USECLANG}" \
		|| abdie 'Please set "USECLANG=1" in your defines to enable proper LTO.'
	command -v ld.lld > /dev/null \
		|| abdie 'ld.lld is unavailable. Please add "llvm" to your $BUILDDEP or disable LTO for this architecture.'
}

build_rust_audit() {
	# FIXME: cargo-audit >= 0.18 uses rustls, which breaks non-amd64/arm64 architectures.
	if ab_match_arch "!(amd64|arm64)" || bool "$NOCARGOAUDIT"; then
		return 0
	fi

	abinfo 'Auditing dependencies...'
	if ! command -v cargo-audit > /dev/null; then
		abdie "cargo-audit not found: $?."
	elif [ -f "$SRCDIR"/Cargo.lock ]; then
		if ! cargo audit; then
			abinfo 'Vulnerabilities detected! Attempting automatic fix ...'
			cargo audit fix \
				|| abdie 'Unable to fix vulnerability! Refusing to continue.'
		fi
	else
		abdie 'No lock file found -- Dependency information unreliable. Unable to conduct audit.'
	fi
}

build_rust_configure() {
	abinfo 'Setting up build environment: $PKG_CONFIG_SYSROOT_DIR= hack ...'
	export PKG_CONFIG_SYSROOT_DIR=/

	BUILD_START
	if bool AB_FLAGS_O3; then
		DEFAULT_CARGO_CONFIG+=(--config 'profile.release.opt-level = 3')
	fi
	if ! bool ABSPLITDBG; then
	    DEFAULT_CARGO_CONFIG+=(--config 'profile.release.debug = 0')
	fi
	[ -f "$SRCDIR"/Cargo.lock ] \
		|| abwarn "This project is lacking the lock file. Please report this issue to the upstream."
	if ! dpkg --compare-versions "$(build_rust_get_installed_rust_version)" ge '1.70.0'; then
		build_rust_prepare_registry
	fi
	if ab_match_arch "ppc64" && \
		! bool "$NOLTO"; then
		build_rust_inject_lto
	fi
}

build_rust_build() {
	BUILD_READY
	abinfo 'Building Cargo package ...'
	install -vd "$PKGDIR/usr/bin/"
	ab_tostringarray CARGO_AFTER
	if cargo read-manifest --manifest-path "$SRCDIR"/Cargo.toml > /dev/null; then
		cargo install --locked -f --path "$SRCDIR" \
        	"${DEFAULT_CARGO_CONFIG[@]}" \
			--root="$PKGDIR/usr/" "${CARGO_AFTER[@]}" \
			|| abdie "Compilation failed: $?."
	else
		abinfo 'Using fallback build method ...'
        cargo build --workspace "${DEFAULT_CARGO_CONFIG[@]}" --release --locked "${CARGO_AFTER[@]}" || abdie "Compilation failed: $?."
        abinfo "Installing binaries in the workspace ..."
        find "$SRCDIR"/target/release -maxdepth 1 -executable -type f ! -name "*.so" -exec 'install' '-Dvm755' '{}' "$PKGDIR/usr/bin/" ';'
	fi
}

build_rust_install() {
	abinfo 'Installing exported shared libraries in the workspace ...'
	for i in "$SRCDIR"/target/release/*.so*; do
		# filter out the compiler plugins
		readelf --wide --dyn-syms "$i" | grep -q '__rustc_proc_macro_decls_[0-9a-f]*__' ||\
			install -Dvm755 "$SRCDIR"/target/release/"$i" -t "$PKGDIR"/usr/lib/
	done
	abinfo 'Dropping lingering files ...'
	rm -v "$PKGDIR"/usr/.crates{.toml,2.json}
	BUILD_FINAL
}

ab_register_template -l rust -- rustc cargo readelf
