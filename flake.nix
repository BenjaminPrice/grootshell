{
  description = "grootshell — a Quickshell desktop shell for groot";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      # Linux only — this is a Wayland shell. Both arches so it is not
      # gratuitously x86-only, though only x86_64 is ever built in practice.
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAll = nixpkgs.lib.genAttrs systems;
      pkgsFor = system: nixpkgs.legacyPackages.${system};
    in
    {
      packages = forAll (
        system:
        let
          pkgs = pkgsFor system;
        in
        rec {
          grootshell = pkgs.callPackage ./nix/package.nix { src = self; };
          default = grootshell;
        }
      );

      # `nix flake check` — parse every QML file, then audit for the mistakes
      # that parse cleanly and fail at load. Quickshell exits when its config
      # fails to load, so each of those is a black screen on a host with no
      # local console; they are worth catching before a push, not after.
      checks = forAll (
        system:
        let
          pkgs = pkgsFor system;
        in
        {
          qml = pkgs.runCommand "grootshell-qml-check"
            {
              nativeBuildInputs = [
                pkgs.qt6.qtdeclarative
                pkgs.python3
              ];
            }
            ''
              cd ${self}

              for f in $(find . -name '*.qml' -not -path './.git/*' | sort); do
                qmlformat "$f" > /dev/null || {
                  echo "qmlformat: $f failed to parse" >&2
                  exit 1
                }
              done

              python3 scripts/qml-audit.py .

              # The Qt palette template must list exactly 21 roles per state,
              # in QPalette's enum order.
              #
              # qt6ct falls back to its default palette SILENTLY when a list is
              # the wrong length — no warning, no error, just an unthemed file
              # dialog you notice a week later. This check used to be an
              # assertion in the NixOS module that built the template; it moved
              # here with the template itself.
              for line in active inactive disabled; do
                n=$(grep "^''${line}_colors=" templates/qt6ct-colors.conf.tpl \
                      | tr ',' '\n' | wc -l)
                if [ "$n" -ne 21 ]; then
                  echo "qt6ct template: ''${line}_colors has $n roles, expected 21" >&2
                  exit 1
                fi
              done

              touch $out
            '';
        }
      );

      devShells = forAll (
        system:
        let
          pkgs = pkgsFor system;
        in
        {
          # `nix develop` then `qs -p .` runs the checkout directly, which is the
          # same thing the packaged wrapper does with GROOTSHELL_CONFIG_PATH set.
          default = pkgs.mkShell {
            packages = with pkgs; [
              quickshell
              qt6.qtdeclarative # qmllint / qmlformat
              material-symbols
              rubik
              nerd-fonts.caskaydia-cove
            ];
          };
        }
      );

      formatter = forAll (system: (pkgsFor system).nixfmt);
    };
}
