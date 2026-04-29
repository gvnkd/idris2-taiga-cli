{
  pkgs,
  inputs,
}:
let
  buildIdris = pkgs.idris2Packages.buildIdris;
  idrisVersion = pkgs.idris2.version;

  mkLib =
    {
      ipkgName,
      src,
      idrisLibraries ? [ ],
      subdir ? null,
    }:
    let
      rawSrc =
        if subdir != null then
          pkgs.runCommandLocal "${ipkgName}-src" { } ''
            mkdir $out
            cp -r ${src}/${subdir}/. $out/
          ''
        else
          src;
    in
    (buildIdris { inherit ipkgName; src = rawSrc; inherit idrisLibraries; }).library { };

  compatLib =
    raw:
    pkgs.runCommand "${raw.name or "lib"}" { passthru = { inherit (raw.passthru) propagatedIdrisLibraries withSource; }; } ''
      mkdir -p $out/idris2-${idrisVersion}
      cp -r ${raw}/lib/idris2-${idrisVersion}/. $out/idris2-${idrisVersion}/
    '';

  spec =
    [
      # name              src input                  deps                            subdir
      [ "algebra"          inputs.idris2-algebra-src  [ ]                             null ]
      [ "ref1"             inputs.idris2-ref1-src     [ ]                             null ]
      [ "elab-util"        inputs.idris2-elab-util-src [ ]                            null ]
      [ "filepath"         inputs.idris2-filepath-src [ ]                            null ]
      [ "quantifiers-extra" inputs.idris2-quantifiers-extra-src [ ]                  null ]
      [ "hashable"         inputs.idris2-hashable-src [ ]                            null ]
      [ "ansi"             inputs.idris2-ansi-src     [ ]                             null ]
      [ "array"            inputs.idris2-array-src    [ "algebra" "ref1" ]            null ]
      [ "elin"             inputs.idris2-elin-src     [ "quantifiers-extra" "ref1" ]  null ]
      [ "refined"          inputs.idris2-refined-src  [ "elab-util" "algebra" ]       null ]
      [ "finite"           inputs.idris2-finite-src   [ "elab-util" ]                 null ]
      [ "bytestring"       inputs.idris2-bytestring-src [ "algebra" "array" "ref1" ]  null ]
      [ "cptr"             inputs.idris2-cptr-src     [ "elin" "array" ]              null ]
      [ "ilex-core"        inputs.idris2-ilex-src     [ "elab-util" "bytestring" ]    "core" ]
      [ "ilex"             inputs.idris2-ilex-src     [ "elab-util" "algebra" "array" "bytestring" "ilex-core" "refined" ] null ]
      [ "ilex-json"        inputs.idris2-ilex-src     [ "ilex" ]                      "json" ]
      [ "parser"           inputs.idris2-parser-src   [ "elab-util" "bytestring" "ilex-core" ] null ]
      [ "containers"       inputs.idris2-containers-src [ "array" "elab-util" "hashable" "ref1" ] null ]
      [ "posix"            inputs.idris2-linux-src    [ "bytestring" "cptr" "elab-util" "elin" "finite" ] "posix" ]
      [ "json"             inputs.idris2-json-src     [ "parser" "elab-util" "ilex-json" ] null ]
      [ "linux"            inputs.idris2-linux-src    [ "posix" ]                     "linux" ]
      [ "async"            inputs.idris2-async-src    [ "array" "containers" "elin" "quantifiers-extra" ] null ]
      [ "streams"          inputs.idris2-streams-src  [ "async" "bytestring" "elin" ] null ]
      [ "tui"              inputs.idris2-tui-src      [ "ansi" "json" "elab-util" "quantifiers-extra" ] null ]
    ];

  resolve =
    acc: entry:
    let
      name = builtins.elemAt entry 0;
      src = builtins.elemAt entry 1;
      deps = builtins.elemAt entry 2;
      subdir = builtins.elemAt entry 3;
      idrisLibraries = builtins.map (d: acc.${d}) deps;
    in
    acc // { ${name} = mkLib { ipkgName = name; inherit src idrisLibraries subdir; }; };

  libs = builtins.foldl' resolve { } spec;

  all = builtins.attrValues libs;
in
{
  inherit libs all;
  idris2 = pkgs.idris2.withPackages (_: builtins.map compatLib all);
}
