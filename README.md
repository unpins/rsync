# rsync

Standalone build of [rsync](https://rsync.samba.org/).

[![CI](https://github.com/unpins/rsync/actions/workflows/rsync.yml/badge.svg)](https://github.com/unpins/rsync/actions)
![Linux](https://img.shields.io/badge/Linux-✓-success?logo=linux&logoColor=white)
![macOS](https://img.shields.io/badge/macOS-✓-success?logo=apple&logoColor=white)
![Windows](https://img.shields.io/badge/Windows-✓-success?logo=windows&logoColor=white)

Part of the [unpins](https://unpins.org) project — native single-binary builds with no third-party runtime dependencies.

## Usage

Run `rsync` with [unpin](https://github.com/unpins/unpin):

```bash
unpin rsync -av src/ dst/
```

To install it onto your PATH:

```bash
unpin install rsync
```

## Build locally

```bash
nix build github:unpins/rsync
./result/bin/rsync --version
```

Or run directly:

```bash
nix run github:unpins/rsync
```

The first invocation will offer to add the [unpins.cachix.org](https://unpins.cachix.org) substituter so most pulls come pre-built.

## Manual download

The [Releases](https://github.com/unpins/rsync/releases) page has standalone binaries for manual download.

## Man pages

`rsync.1`, `rsync-ssl.1` and `rsyncd.conf.5` are embedded in the binary — read them with `unpin man rsync`, `unpin man rsync-ssl` and `unpin man rsyncd.conf`.

## Build notes

- **Windows** uses [Cosmopolitan](https://justine.lol/cosmopolitan/) (cosmocc), not mingw. rsync runs its sender, receiver and generator as separate `fork`ed processes and `exec`s the remote shell — primitives msvcrt lacks, which is why native-Windows rsync has historically meant a Cygwin build. Cosmopolitan provides them, so the stock upstream source builds into one `.exe` that imports only system DLLs.
- Two cross-compile fixes make the Windows build work: rsync's "secure mkstemp" probe is skipped when cross-compiling, so it's forced back on (cosmo's `mkstemp` is fine; the fallback path it would otherwise take corrupts transfers), and `libzstd`'s cosmo build is handled in `nix-lib/cosmo/zstd.nix`.
- No platforms are excluded, and no rsync features are turned off to get a static build.
