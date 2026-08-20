# Windows build via Cosmopolitan. mingw is a dead end for rsync: its transfer
# model runs the sender/receiver/generator as separate processes (`fork`) and
# spawns the remote shell with `fork` + `exec`, none of which msvcrt provides
# — which is why native-Windows rsync has always been a Cygwin build. Cosmo
# implements `fork`/`exec` on Windows (via CreateProcessW + page copy), so the
# stock nixpkgs sources cross-build against `pkgs.pkgsCross.cosmo` unchanged.
#
# The libzstd dependency needs cosmo-specific handling (static-only, dropped
# asm, no bash/grep drag), but that's generic to any cosmo consumer of zstd
# and lives in nix-lib/cosmo/zstd.nix — nothing of that is rsync-specific.
{ unpins-lib }:
pkgs:
let
  # OPENSSLDIR/ENGINESDIR/MODULESDIR default to openssl's own $out, so the .exe
  # ended up carrying a live reference to `openssl-…-cosmo-gnu-3.6.2-etc` — a
  # trust-store directory that exists nowhere on a user's machine. The engine's
  # native scope already retargets openssl to /etc/ssl set-wide
  # (native-overlay/openssl.nix) and the standalone `openssl` package retargets
  # the mingw build to C:/ssl; the COSMO scope has no such retarget, so every
  # cosmo consumer of openssl inherits the store path. /etc/ssl matches the
  # native side (rsync links openssl only for its MD4/MD5 digests -- it never
  # reads the trust store -- so the directory's contents are moot; what matters
  # is that the artifact stops carrying a store path).
  cosmoPkgs = (unpins-lib.lib.cosmoStaticCross pkgs).extend (final: prev: {
    openssl = prev.openssl.overrideAttrs (unpins-lib.lib.retargetOpenssl "/etc/ssl");
  });
in
cosmoPkgs.rsync.overrideAttrs (oa: {
  # rsync's "secure mkstemp" probe is an AC_RUN test, so it resolves to "cross"
  # (≠ "yes") when cross-compiling and HAVE_SECURE_MKSTEMP is left undefined.
  # do_mkstemp() then takes its fallback path — mktemp() + open(O_EXCL|O_CREAT)
  # — and cosmo's mktemp() collides on Windows ("mkstemp … failed: File exists"),
  # breaking every transfer (the receiver writes through a temp file). cosmo's
  # mkstemp() itself works correctly (verified on the VM: unique 0600 temps), so
  # force the cache var to take the mkstemp() path.
  rsync_cv_HAVE_SECURE_MKSTEMP = "yes";
})
