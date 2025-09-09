{
  description = "Basic development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        lib = pkgs.lib;
        calicoctl = pkgs.fetchurl {
          url = https://github.com/projectcalico/calico/releases/download/v3.30.3/calicoctl-linux-amd64;
          name = "calicoctl";
          hash = "sha256-p9AX0av2711uAyZxh8DdaMMvXpN7ZN7NKdADvkT6a5Q=";
        };
        calicoctl-package = pkgs.runCommand "calicoctl" {} ''
          mkdir -p $out/bin
          cp ${calicoctl} $out/bin/calicoctl
          ln -s $out/bin/calicoctl $out/bin/kubectl-calico
          chmod +x $out/bin/calicoctl
        '';
      in
        {
          devShells.default = pkgs.mkShell {
            shellHook = ''
              export EDITOR=${pkgs.nano}/bin/nano
            '';
            packages = with pkgs; [
              calicoctl-package
              k9s
              kind
              kubernetes-helm
              nano
              pv
            ];
          };
        }
    );
}
