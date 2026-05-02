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
        mkdocs = idris2-withpkgs.packages.${system}.idris2-mkdoc-md;
        docBrowser = idris2-withpkgs.packages.${system}.doc-browser;

        # Registry packages available as idris2-withpkgs.packages.${system}.<name>
        selectedLibs = with idris2-withpkgs.packages.${system}; [ json http ];

        # Wrapped idris2 with all registry deps on IDRIS2_PACKAGE_PATH
        idris2Wrapped = idris2-withpkgs.lib.${system}.withPackages (p: with p; [
          json
          http
        ]);

        pkg = pkgs.idris2Packages.buildIdris {
          src = ./.;
          ipkgName = "taiga-cli";
          version = "0.1.0";
          idrisLibraries = selectedLibs;
        };

        # Bundle docs for project dependencies into a browsable collection
        projectDocs = pkgs.runCommand "taiga-cli-docs" {
          nativeBuildInputs = [ pkgs.makeWrapper ];
        } (
          let
            docsPkgs = with idris2-withpkgs.packages.${system}; [
              json-docs
              http-docs
            ];
            linkCommands = map (docsPkg: ''
              if [ -d ${docsPkg}/share/doc ]; then
                for dir in ${docsPkg}/share/doc/*; do
                  if [ -d "$dir" ]; then
                    name=$(basename "$dir")
                    ln -s "$dir" $out/share/doc/"$name"
                  fi
                done
              fi
            '') docsPkgs;
          in
          ''
            mkdir -p $out/share/doc
            ${pkgs.lib.concatStringsSep "\n" linkCommands}

            mkdir -p $out/bin
            cp ${docBrowser}/bin/doc-browser $out/bin/
            chmod +x $out/bin/doc-browser

            wrapProgram $out/bin/doc-browser \
              --set DOCS_PATH "$out/share/doc"
          ''
        );

        python = pkgs.python3.withPackages (ps: [ ps.pytest ps.requests ]);
      in
      {
        packages.default = pkg.executable;
        packages.docs = projectDocs;

        devShells.default = pkgs.mkShell {
          buildInputs = [
            idris2Wrapped
            projectDocs
            mkdocs
            pkgs.rlwrap
            python
          ] ++ (with pkgs; [
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
            (writeShellScriptBin "docs" ''
              echo "Available package documentation:"
              echo ""
              doc-browser list
              echo ""
              echo "View a package index:   doc-browser show <pkg>"
              echo "View a module:          doc-browser show <pkg> <module>"
            '')
          ]);

          shellHook = ''
            export IDRIS2_PACKAGE_PATH="${idris2Wrapped}/lib/idris2-${idris2.version}:''${IDRIS2_PACKAGE_PATH:-}"
            echo "taiga-cli devShell"
            echo ""
            echo "Commands:"
            echo "  build       - Build the project"
            echo "  run         - Build and run taiga-cli"
            echo "  tcli        - Run the built executable"
            echo "  docs        - List browsable package docs"
            echo "  doc-browser - Browse docs interactively"
            echo ""
            echo "  doc-browser list              - List all packages"
            echo "  doc-browser show json         - View json package index"
            echo "  doc-browser show json JSON    - View JSON.Encoder module"
          '';
        };
      }
    );
}
