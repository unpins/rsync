# rsync

[rsync](https://rsync.samba.org/) as a single self-contained binary, built natively for Linux, macOS, and Windows.

[![CI](https://github.com/unpins/rsync/actions/workflows/rsync.yml/badge.svg)](https://github.com/unpins/rsync/actions)
![Linux](https://img.shields.io/badge/Linux-✓-success?logo=linux&logoColor=white)
![macOS](https://img.shields.io/badge/macOS-✓-success?logo=apple&logoColor=white)
![Windows](https://img.shields.io/badge/Windows-✓-success?logo=windows&logoColor=white)

Part of the [unpins](https://unpins.org) catalog; install it with [`unpin`](https://github.com/unpins/unpin): `unpin install rsync`.

## Usage

Run `rsync` with [unpin](https://github.com/unpins/unpin):

```bash
unpin rsync -av src/ dst/
```

To install it onto your PATH:

```bash
unpin install rsync
```

## Man pages

`rsync.1` and `rsyncd.conf.5` are embedded in the binary — read them with `unpin man rsync` and `unpin man rsyncd.conf`.

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

## Build notes

- **Windows** uses [Cosmopolitan](https://justine.lol/cosmopolitan/) (cosmocc), not mingw. rsync runs its sender, receiver and generator as separate `fork`ed processes and `exec`s the remote shell — primitives msvcrt lacks, which is why native-Windows rsync has historically meant a Cygwin build. Cosmopolitan provides them, so the stock upstream source builds into one `.exe` that imports only system DLLs.
- rsync decides four of its capabilities by compiling a small program and *running* it. Every build here is a cross-build, so those tests never ran and `configure` assumed the worst: the binary came out reporting `no socketpairs, no hardlink-specials, no hardlink-symlinks`, and it wrote its temporary files through the older, racier path. We ran the same tests on each real target — Linux, macOS and Windows — and gave `configure` the measured answers. `rsync --version` now lists the same capabilities a distribution build does, and `-H` preserves hard-linked symlinks and hard-linked FIFOs instead of copying them. The one that stays off is hardlink-specials on Windows: Cosmopolitan has no FIFOs or device nodes to link.
- `libzstd` needs cosmo-specific handling for the Windows build; that lives in `nix-lib/cosmo/zstd.nix`, not here.
- No platforms are excluded. One upstream optimization is off: the SIMD rolling checksum on Linux x86_64, which needs `ifunc` and musl doesn't have it. Upstream only offers that one on x86_64 Linux anyway, so every other target matches a distribution build exactly.
