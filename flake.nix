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
    unpins-lib.lib.mkStandaloneFlake {
      inherit self;
      dnsFallback = true; # resolves hostnames; opt into the Android DNS fallback
      name = "rsync";
      build = pkgs: pkgs.pkgsStatic.rsync.overrideAttrs (_: { doCheck = false; });
      windowsBuild = import ./cosmo.nix { inherit unpins-lib; };
    };
}
