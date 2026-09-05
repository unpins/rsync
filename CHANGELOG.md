# Changelog

## [Unreleased]

- The Windows build now compresses with the current zlib. It had been falling
  back to the 2013 copy bundled in the rsync tarball, because the zlib it was
  built against handed over no library to link. Every `--compress` transfer
  went through that older code.
- Restored four capabilities that cross-compiling had silently switched off.
  rsync settles them by running a test program, which a cross-build cannot do,
  so `configure` answered "no" to all of them: the binary reported
  `no socketpairs, no hardlink-specials, no hardlink-symlinks` where a
  distribution build reports all three, and it created its temporary files
  through the older `mktemp` path instead of `mkstemp`. With `-H`, hard-linked
  symlinks and hard-linked FIFOs were copied as separate files rather than
  preserved as links, and `--link-dest` refused to link them. The tests were
  run on each real target and the answers given back to `configure`.
  Hardlink-specials stays off on Windows, which has no FIFOs to link.

- Dropped the manual page for `rsync-ssl`. It documents a helper script that
  is not part of this binary, so `unpin man rsync-ssl` was answering for a
  command there is no way to run.
