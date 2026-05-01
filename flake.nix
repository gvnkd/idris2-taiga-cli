{
  description = "taiga-cli — AI agent CLI for Taiga project management";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    idris2-algebra-src = {
      flake = false;
      url = "github:stefan-hoeck/idris2-algebra/e279843a99fe250e2fcd928c774ddb6ffe36815b";
    };
    idris2-ansi-src = {
      flake = false;
      url = "github:idris-community/idris2-ansi/90f80ac513572877a3de818b43f837fa59265fec";
    };
    idris2-array-src = {
      flake = false;
      url = "github:stefan-hoeck/idris2-array/47fb4c0eef3223a02d60c832a0e6b98193d4c44c";
    };
    idris2-async-src = {
      flake = false;
      url = "github:stefan-hoeck/idris2-async/1cd4007efcce51efc79c2697a925608826f9d75d";
    };
    idris2-bytestring-src = {
      flake = false;
      url = "github:stefan-hoeck/idris2-bytestring/230d8577f02de22251786f128ec921078da4d880";
    };
    idris2-containers-src = {
      flake = false;
      url = "github:idris-community/idris2-containers/3568bb6d0be9f0c675cbf5f0ed4a120b4b767cb8";
    };
    idris2-cptr-src = {
      flake = false;
      url = "github:stefan-hoeck/idris2-cptr/63f224d52af5c5655f022fb9c9a6edd34feefd50";
    };
    idris2-elab-util-src = {
      flake = false;
      url = "github:stefan-hoeck/idris2-elab-util/90a2363256cbaafd3b0cc4e2bf36003761b6c4f0";
    };
    idris2-elin-src = {
      flake = false;
      url = "github:stefan-hoeck/idris2-elin/c66a6709397431150235e8bdddc0a21fcbedb7de";
    };
    idris2-filepath-src = {
      flake = false;
      url = "github:stefan-hoeck/idris2-filepath/4e8fe9af80d457adc63904ebf58e223ba35c62aa";
    };
    idris2-finite-src = {
      flake = false;
      url = "github:stefan-hoeck/idris2-finite/5d9a9de5466030f3ffc5a0c2ad4ef647bc882a30";
    };
    idris2-hashable-src = {
      flake = false;
      url = "github:Z-snails/idris2-hashable/af0b5e086d26777cbdedf0e1b5d7a9684d755da6";
    };
    idris2-ilex-src = {
      flake = false;
      url = "github:stefan-hoeck/idris2-ilex/a07a214d2284b73622f7ff583b7c2c3f146155ab";
    };
    idris2-json-src = {
      flake = false;
      url = "github:stefan-hoeck/idris2-json/b15189c7198143e1357802ce8748dc1ab544da76";
    };
    idris2-linux-src = {
      flake = false;
      url = "github:stefan-hoeck/idris2-linux/f34c638ce71f0a46b8b0ef471e2a43e9a91a5853";
    };
    idris2-parser-src = {
      flake = false;
      url = "github:stefan-hoeck/idris2-parser/9decb99fe27c3411c18850129715a49c64f1b1c0";
    };
    idris2-quantifiers-extra-src = {
      flake = false;
      url = "github:stefan-hoeck/idris2-quantifiers-extra/5e368c5dcc7724e19b1e9eb3baf8e206cf79d2a1";
    };
    idris2-ref1-src = {
      flake = false;
      url = "github:stefan-hoeck/idris2-ref1/a310afbb234cb5a405985bf3667c4ea5f5248084";
    };
    idris2-refined-src = {
      flake = false;
      url = "github:stefan-hoeck/idris2-refined/02e43fa2b89076b4096c5f442bac7bea8814d552";
    };
    idris2-streams-src = {
      flake = false;
      url = "github:stefan-hoeck/idris2-streams/dd56316d102c4736ba24f47bea72fc3a9008585f";
    };
    idris2-tui-src = {
      flake = false;
      url = "github:emdash/idris2-tui/aac912e4581dc3fb8b02e12bb984006500d6c2bb";
    };
#    idris2-http-src = {
#      flake = false;
#      url = "github:idris-community/idris2-http/0ff06cf2c831cc9283d2e539978fedf599df2b17";
#    };
#    idris2-sop-src = {
#      flake = false;
#      url = "github:stefan-hoeck/idris2-sop/1e01b67a11857e9c9a0ea5fb2870bd915b5a223d";
#    };
#    idris2-tls-src = {
#      flake = false;
#      url = "github:stefan-hoeck/idris2-tls/4a53d18ce15f228b7c74f7a9722359fd53cab87a";
#    };
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      ...
    }@inputs:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        idris2Pkgs = import ./nix/idris2_packages.nix { inherit pkgs inputs; };
        python = pkgs.python3.withPackages (ps: [ ps.pytest ps.requests ]);
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs =
            [ idris2Pkgs.idris2 pkgs.rlwrap python ]
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
#              (pkgs.writeShellScriptBin "curl" ''
#                # Wrapper: block raw curl against the Taiga instance.
#                # Raw curl is strictly prohibited - use tcli / taiga-cli instead.
#                for arg in "$@"; do
#                  case "$arg" in
#                    *http://taiga.bigdesk/*|*http://127.0.0.1*) 
#                      echo "ERROR: Using raw curl with the Taiga instance is strictly prohibited." >&2
#                      echo "This is the canonical, tested, and type-safe way to interact with Taiga." >&2
#                      echo "Use 'tcli' or 'taiga-cli' instead:" >&2
#                      echo "  tcli task list" >&2
#                      echo "  tcli story get <id>" >&2
#                      echo "  tcli sprint create \"<name>\"" >&2
#                      exit 1
#                      ;;
#                  esac
#                done
#                exec ${pkgs.curl}/bin/curl "$@"
#              '')
            ]);
        };
      }
    );
}
