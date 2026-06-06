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
  cosmoPkgs = unpins-lib.lib.cosmoStaticCross pkgs;
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
