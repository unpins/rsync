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
      # Four capabilities rsync settles with AC_RUN_IFELSE, which a cross build
      # never runs -- so autoconf took the "no" branch on all four and the
      # binary came out weaker than any distro's. Not cosmetic: with `-H`,
      # hard-linked symlinks and FIFOs were copied as separate files instead of
      # preserved, `--link-dest` refused to link them, and `do_mkstemp()` fell
      # back to `mktemp()` + `open(O_EXCL|O_CREAT)`.
      #
      # The answers belong to the target's kernel and libc, so they were
      # measured by running the upstream probe bodies on the real targets
      # (windows' differ and live in ./cosmo.nix):
      #
      #                        linux-musl   darwin   windows (cosmo)
      #   hardlink-symlink        yes        yes          yes
      #   hardlink-special        yes        yes          no
      #   socketpair              yes        yes          yes
      #   secure-mkstemp          yes        yes          no  (mode 0664)
      #
      # Copy the probe body from configure.ac rather than writing one: it uses
      # `linkat(…, 0)` when HAVE_LINKAT, which is what `do_link()` calls, and on
      # darwin the two disagree -- plain `link()` follows the symlink and fails
      # on a dangling one, so probing with it mis-answers darwin `no`.
      #
      # Left alone though cross-defeated the same way: HAVE_C99_VSNPRINTF (the
      # "no" branch uses rsync's own lib/snprintf.c -- correct, just not libc's)
      # and MKNOD_CREATES_FIFOS/SOCKETS (its "no" branch uses mkfifo()/socket()
      # instead of mknod(), the more portable route, not a weaker one).
      runProbeAnswers = {
        rsync_cv_can_hardlink_symlink = "yes";
        rsync_cv_can_hardlink_special = "yes";
        rsync_cv_HAVE_SOCKETPAIR = "yes";
        rsync_cv_HAVE_SECURE_MKSTEMP = "yes";
      };

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
      # rsync 3.5.0's recipe writes `${python3}/bin/python3` into the shebangs
      # of its test scripts. That is text in `preBuild`, never a program the
      # build runs on the target, yet it names the HOST python: here that is
      # a whole static CPython (sqlite, gdbm, readline, …) built with the
      # engine, and on darwin and cosmo one nixpkgs refuses to evaluate, so
      # the build failed before it started. The tests are off (doCheck below);
      # the build machine's python is the right one for a shebang anyway.
      build = pkgs: ((pkgs.pkgsStatic.rsync.override {
        python3 = pkgs.pkgsStatic.buildPackages.python3;
      }).overrideAttrs
        (_: { doCheck = false; } // runProbeAnswers))
        .overrideAttrs dropRsyncSslMan;
      # The cosmo build's man output happens not to carry the page today (only
      # `rsync.1` and `rsyncd.conf.5` reach the .exe), but the prune goes on
      # this path too so the two cannot drift: `windowsBuild` does not go
      # through `build`, so a wrapper on `build` alone never touches the .exe.
      windowsBuild = pkgs:
        (import ./cosmo.nix { inherit unpins-lib; } pkgs).overrideAttrs dropRsyncSslMan;
    };
}
