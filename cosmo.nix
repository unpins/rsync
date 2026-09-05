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
  # Same cross-defeated AC_RUN probes as the native build (see flake.nix), but
  # the answers are Windows', so they are set here rather than shared. Measured
  # with the upstream probe bodies compiled by this very toolchain and run on
  # the Windows VM:
  #
  #   hardlink-symlink  yes   link()/linkat() on a symlink works, and lstat
  #                           still reports S_ISLNK on the new name.
  #   socketpair        yes   cosmo implements AF_UNIX socketpair on NT;
  #                           verified bidirectional, not just created.
  #   hardlink-special  no    cosmo has no mkfifo() at all -- the probe does
  #                           not even compile -- so there are no special files
  #                           to hard-link. Pinned to "no" so the answer is a
  #                           recorded measurement and not a cross default that
  #                           happens to agree.
  rsync_cv_can_hardlink_symlink = "yes";
  rsync_cv_HAVE_SOCKETPAIR = "yes";
  rsync_cv_can_hardlink_special = "no";

  # This one overrides the probe rather than answering it. Run on Windows the
  # probe says NO: cosmo's mkstemp() creates the file 0664, and upstream
  # demands exactly 0600 (NTFS has no such mode to give). But the "no" branch
  # is broken here, not merely less secure -- do_mkstemp() then takes
  # mktemp() + open(O_EXCL|O_CREAT), and cosmo's mktemp() collides on Windows
  # ("mkstemp ... failed: File exists"), breaking every transfer, since the
  # receiver writes through a temp file. cosmo's mkstemp() itself is fine
  # (verified on the VM: unique names, no collisions), and do_mkstemp()
  # fchmod()s to the mode it wants immediately after, so the one thing the
  # probe rejects is the one thing rsync fixes for itself.
  rsync_cv_HAVE_SECURE_MKSTEMP = "yes";
})
