{
  description = "taiga-cli — AI agent CLI for Taiga project management";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    idris2-withpkgs.url = "github:gvnkd/flake-idris2-withPackages";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      idris2-withpkgs,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        idris2 = idris2-withpkgs.inputs.idris2-src.packages.${system}.idris2;

        # Registry packages available as idris2-withpkgs.packages.${system}.<name>
        selectedLibs = with idris2-withpkgs.packages.${system}; [ json ];

        # Wrapped idris2 with all registry deps on IDRIS2_PACKAGE_PATH
        idris2Wrapped = idris2-withpkgs.lib.${system}.withPackages (p: [
          p.json
        ]);

        pkg = pkgs.idris2Packages.buildIdris {
          src = ./.;
          ipkgName = "taiga-cli";
          version = "0.1.0";
          idrisLibraries = selectedLibs;
        };

        python = pkgs.python3.withPackages (ps: [ ps.pytest ps.requests ]);
      in
      {
        packages.default = pkg.executable;

        devShells.default = pkgs.mkShell {
          buildInputs =
            [ idris2Wrapped pkgs.rlwrap python ]
            ++ (with pkgs; [
              (writeShellScriptBin "build" ''
                idris2 --build taiga-cli.ipkg "$@"
              '')
              (writeShellScriptBin "run" ''
                idris2 --build taiga-cli.ipkg && exec ./build/exec/taiga-cli "$@"
              '')
              (writeShellScriptBin "taiga-cli" ''
                exec ./build/exec/taiga-cli "$@"
              '')
              (writeShellScriptBin "tcli" ''
                exec ./build/exec/taiga-cli "$@"
              '')
            ]);
        };
      }
    );
}
