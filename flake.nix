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
