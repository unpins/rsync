{
  description = "rsync as a single self-contained binary";

  nixConfig = {
    extra-substituters = [ "https://unpins.cachix.org" ];
    extra-trusted-public-keys = [ "unpins.cachix.org-1:DDaShjbZ8VvcqxeTcAU3kV9vxZQBlyb7V/uLBHfTynI=" ];
  };

  inputs.unpins-lib.url = "github:unpins/nix-lib";

  # Native Linux/macOS comes from pkgsStatic.rsync. The only native override is
  # dropping `doCheck`: the upstream test suite has two cases that can't pass in
  # the Nix build sandbox — `chgrp` (the sandbox uid can't change a file's
  # group) and `itemize` (its expected diff assumes a non-sandbox environment).
  # Both are environmental, not real regressions, so we skip the suite rather
  # than carve out individual tests.
  #
  # Windows goes through Cosmopolitan (not mingw — rsync forks the
  # sender/receiver/generator and execs the remote shell, which msvcrt can't
  # do). See ./cosmo.nix for the recipe and the one dependency quirk.
  outputs = { self, unpins-lib }:
    let
      # `rsync-ssl` is a /bin/sh helper that shells out to `openssl s_client`
      # or stunnel; it is not a program this binary can hold, and it is not
      # shipped. Its man page is, though: the man harvest takes the package's
      # whole `man` output, so `unpin man rsync-ssl` answered for a command the
      # user has no way to run. Drop the page. (`rsyncd.conf.5` stays — it
      # documents the config file `rsync --daemon` reads, and the daemon is
      # right here.) The page installs uncompressed; the glob covers the case
      # where nixpkgs' fixup has already gzipped it.
      dropRsyncSslMan = old: {
        postInstall = (old.postInstall or "") + ''
          rm -f $out/share/man/man1/rsync-ssl.1*
        '';
      };
    in
    unpins-lib.lib.mkStandaloneFlake {
      inherit self;
      dnsFallback = true; # resolves hostnames; opt into the Android DNS fallback
      name = "rsync";
      smoke = [ "--version" ];
      smokePattern = "^rsync +version [0-9]+\\.[0-9]+";

      # Build via the unpin-llvm engine + emit a bitcode multicall module.
      engine = "unpin-llvm";
      multicall = {
        programs = [{ name = "rsync"; }];
      };
      build = pkgs: (pkgs.pkgsStatic.rsync.overrideAttrs (_: { doCheck = false; }))
        .overrideAttrs dropRsyncSslMan;
      # The cosmo build's man output happens not to carry the page today (only
      # `rsync.1` and `rsyncd.conf.5` reach the .exe), but the prune goes on
      # this path too so the two cannot drift: `windowsBuild` does not go
      # through `build`, so a wrapper on `build` alone never touches the .exe.
      windowsBuild = pkgs:
        (import ./cosmo.nix { inherit unpins-lib; } pkgs).overrideAttrs dropRsyncSslMan;
    };
}
