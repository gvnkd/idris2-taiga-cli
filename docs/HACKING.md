# HACKING.md — taiga-cli Flake Development Guide

This document is a comprehensive guide to understanding, developing, and extending the `taiga-cli` Nix flake. It covers the architecture of the flake, how dependencies are managed, how documentation browsing works, and how to make changes.

## Table of Contents

1. [Overview](#overview)
2. [Flake Architecture](#flake-architecture)
3. [Dependency Management](#dependency-management)
4. [The idris2-withpkgs Integration](#the-idris2-withpkgs-integration)
5. [Documentation System](#documentation-system)
6. [Build Process](#build-process)
7. [Development Workflow](#development-workflow)
8. [Adding New Dependencies](#adding-new-dependencies)
9. [Troubleshooting](#troubleshooting)
10. [Reference](#reference)

---

## Overview

`taiga-cli` is built as a Nix flake. The flake declares:

- **Inputs**: External flakes we depend on (`nixpkgs`, `flake-utils`, `idris2-withpkgs`)
- **Packages**: Build outputs (`default` = the executable, `docs` = browsable documentation bundle)
- **DevShell**: Interactive development environment with tools, dependencies, and documentation

The key design decision is that we outsource Idris 2 package management to the `idris2-withpkgs` flake, which maintains a registry of 200+ Idris 2 packages with proper Nix integration.

---

## Flake Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     flake.nix                               │
├─────────────────────────────────────────────────────────────┤
│ Inputs                                                      │
│   ├── nixpkgs         (NixOS package set)                   │
│   ├── flake-utils     (eachDefaultSystem helper)            │
│   └── idris2-withpkgs (Idris 2 package registry)            │
│                                                             │
│ Outputs                                                     │
│   ├── packages.default = taiga-cli executable               │
│   ├── packages.docs    = browsable docs bundle              │
│   └── devShells.default = development environment           │
└─────────────────────────────────────────────────────────────┘
```

### Key Design Decisions

1. **Outsourced package registry**: Instead of defining Idris 2 packages inline, we consume them from `idris2-withpkgs`.
2. **Two-tier dependency selection**: We select which packages we need, then `idris2-withpkgs` handles transitive dependencies.
3. **Wrapped Idris 2**: The devShell provides `idris2` pre-configured with `IDRIS2_PACKAGE_PATH` pointing to all transitive dependencies.
4. **Bundled docs**: Documentation for dependencies is collected into a single browsable directory.

---

## Dependency Management

### The `.ipkg` File

The canonical dependency list lives in `taiga-cli.ipkg`:

```idris
package taiga-cli
version = 0.1.0

sourcedir = "src"
main = Main
executable = taiga-cli

depends = json
        , http2
```

**Critical**: The flake must provide exactly the packages listed here. If `.ipkg` says `http2` but the flake provides `http`, the build will fail with:

```
Error: Failed to resolve the dependencies for taiga-cli:
  Required http2 any but no matching version is installed.
```

### How the Flake Declares Dependencies

In `flake.nix`, we declare which packages we need from the registry:

```nix
selectedLibs = with idris2-withpkgs.packages.${system}; [ json http2 ];
```

This creates a list of Nix derivations. Each derivation is an Idris 2 library built by `nixpkgs`' `buildIdris` function, with transitive dependencies automatically propagated.

### Transitive Dependency Resolution

`idris2-withpkgs` uses `nixpkgs.idris2Packages.buildIdris` which automatically handles transitive dependencies through `propagatedIdrisLibraries`. When you include `json`, you automatically get:

- `elab-util` (json depends on it)
- `parser` (elab-util depends on it)
- `algebra`, `bytestring`, `array` (parser depends on them)
- ...and so on

This is Nix's equivalent of Cabal's dependency solver, but resolved at evaluation time.

### The Wrapped Idris 2

The `idris2Wrapped` derivation is the key to making everything work in the devShell:

```nix
idris2Wrapped = idris2-withpkgs.lib.${system}.withPackages (p: with p; [
  json
  http2
]);
```

This creates a new derivation that:
1. Symlinks the `idris2` binary
2. Wraps it with `--suffix IDRIS2_PACKAGE_PATH` containing paths to all transitive deps
3. Places the result in `$out/bin/idris2`

When you type `idris2` in the devShell, you're running this wrapped version, not the raw compiler.

---

## The idris2-withpkgs Integration

### What is idris2-withpkgs?

`idris2-withpkgs` is a separate flake (`github:gvnkd/flake-idris2-withPackages`) that provides:

1. **A package registry**: ~200 Idris 2 packages defined as Nix expressions
2. **`lib.withPackages`**: A function to create wrapped Idris 2 with selected packages
3. **Documentation generation**: Each package has a `-docs` output with Markdown docs
4. **`doc-browser`**: A shell script for browsing generated documentation

### Why Not Define Packages Here?

Defining Idris 2 packages inline in `taiga-cli` would mean:
- Duplicating package definitions across every project
- Manually tracking transitive dependencies
- Updating hashes when upstream changes

By outsourcing to `idris2-withpkgs`, `taiga-cli` only needs to declare which packages it directly uses. The registry handles the rest.

### Updating the Registry

To update to the latest version of the registry:

```shell
nix flake update idris2-withpkgs
```

This updates `flake.lock` to point to a newer commit of the registry. If upstream packages changed (new hashes, new dependencies), you'll see build failures that need to be addressed.

### Using a Local Registry (Development)

When developing the registry itself, you can point the input to a local path:

```nix
# In flake.nix
idris2-withpkgs.url = "path:/srv/idris2-mkdoc-md";
```

Then update the lock:

```shell
nix flake update idris2-withpkgs
```

Remember to switch back to the GitHub URL before committing.

---

## Documentation System

### Overview

The flake generates and bundles documentation for all Idris 2 dependencies, making it browsable from within the devShell.

```
┌──────────────────────────────────────────┐
│           projectDocs derivation          │
├──────────────────────────────────────────┤
│  $out/share/doc/                         │
│    ├── json/                             │
│    │   ├── index.md                      │
│    │   ├── JSON.md                       │
│    │   ├── JSON.Encoder.md               │
│    │   └── ...                           │
│    └── http2/                            │
│        ├── index.md                      │
│        ├── Http2.md                      │
│        └── ...                           │
│  $out/bin/doc-browser                    │
│    (wrapped with DOCS_PATH=$out/share/doc)│
└──────────────────────────────────────────┘
```

### How It Works

The `projectDocs` derivation:

1. Takes the `-docs` outputs of each dependency (`json-docs`, `http2-docs`)
2. Symlinks their contents into a shared directory
3. Copies the `doc-browser` script and wraps it with `DOCS_PATH`

```nix
projectDocs = pkgs.runCommand "taiga-cli-docs" {
  nativeBuildInputs = [ pkgs.makeWrapper ];
} (
  let
    docsPkgs = with idris2-withpkgs.packages.${system}; [
      json-docs
      http2-docs
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
```

### doc-browser Modes

The `doc-browser` script has two modes:

**Collection mode** (multiple packages): Used in `projectDocs`
```shell
doc-browser list              # List packages: json, http2
doc-browser show json         # Show json/index.md
doc-browser show json JSON.Encoder  # Show json/JSON.Encoder.md
```

**Single-package mode**: Used in per-package `-docs-with-browser` bundles
```shell
doc-browser list              # List modules
doc-browser show JSON.Encoder # Show JSON.Encoder.md directly
```

The script auto-detects the mode by checking if `DOCS_PATH/index.md` exists.

### Accessing Docs in the DevShell

The docs bundle is included in `buildInputs`, so `doc-browser` is on `PATH`:

```shell
nix develop

# List packages
doc-browser list

# View docs
doc-browser show json
doc-browser show http2 Http2

# The 'docs' command shows help
docs
```

### Building Docs Independently

```shell
nix build .#docs
./result/bin/doc-browser list
```

---

## Build Process

### The `buildIdris` Call

The executable is built using `nixpkgs`' Idris 2 infrastructure:

```nix
pkg = pkgs.idris2Packages.buildIdris {
  src = ./.;
  ipkgName = "taiga-cli";
  version = "0.1.0";
  idrisLibraries = selectedLibs;
};
```

This:
1. Copies the source to the Nix store
2. Sets up `IDRIS2_PACKAGE_PATH` with `selectedLibs` and their transitive deps
3. Runs `idris2 --build taiga-cli.ipkg`
4. Produces a derivation with `library` and `executable` outputs

### Build Failures

Common failures:

**Dependency mismatch**:
```
Error: Failed to resolve the dependencies for taiga-cli:
  Required http2 any but no matching version is installed.
```
→ Fix: Update `selectedLibs` in `flake.nix` to match `taiga-cli.ipkg`

**Missing transitive dependency**:
```
Error: Module JSON.Derive not found
```
→ Fix: The `json` package should propagate `elab-util`. If not, the registry has a bug.

**Source hash mismatch** (when updating registry):
```
error: hash mismatch in fixed-output derivation
```
→ Fix: The upstream repo changed. Update the hash in the registry, or use a pinned `rev`.

---

## Development Workflow

### Daily Development

```shell
# Enter the devShell
nix develop

# Build the project
build

# Run the executable
run --help

# Or after building once
./build/exec/taiga-cli --help

# Browse dependency docs
doc-browser show json JSON.Encoder
```

### Adding a Feature That Needs a New Package

1. Add the package to `taiga-cli.ipkg`:
   ```idris
   depends = json
           , http2
           , containers
   ```

2. Add it to `selectedLibs` in `flake.nix`:
   ```nix
   selectedLibs = with idris2-withpkgs.packages.${system}; [
     json
     http2
     containers
   ];
   ```

3. Also add it to `idris2Wrapped`:
   ```nix
   idris2Wrapped = idris2-withpkgs.lib.${system}.withPackages (p: with p; [
     json
     http2
     containers
   ]);
   ```

4. Add docs to the bundle:
   ```nix
   docsPkgs = with idris2-withpkgs.packages.${system}; [
     json-docs
     http2-docs
     containers-docs
   ];
   ```

5. Update the lock file:
   ```shell
   nix flake lock
   ```

6. Build:
   ```shell
   nix build .#default
   ```

### Testing the Flake

```shell
# Build the executable
nix build .#default

# Build docs
nix build .#docs

# Enter devShell and check tools
nix develop --command idris2 --version
nix develop --command doc-browser list

# Check all outputs build
nix build .#default .#docs
```

---

## Adding New Dependencies

### If the Package Exists in the Registry

Just add it to the four places mentioned above:
1. `taiga-cli.ipkg`
2. `selectedLibs`
3. `idris2Wrapped`
4. `docsPkgs`

### If the Package Does NOT Exist in the Registry

You have two options:

**Option A: Add it to the upstream registry** (recommended for widely-used packages)

1. Clone `idris2-withpkgs`
2. Add the package definition in `registry/packages/<name>.nix`
3. Run the extraction script to get dependencies from upstream `HEAD.toml`
4. Submit a PR or push to your fork
5. Update `taiga-cli` to point to your fork temporarily

**Option B: Define it locally in `taiga-cli`** (for project-specific or private packages)

Add a local package definition in the flake:

```nix
my-private-pkg = pkgs.idris2Packages.buildIdris {
  src = ./vendor/my-private-pkg;
  ipkgName = "my-private-pkg";
  version = "0.1.0";
  idrisLibraries = with idris2-withpkgs.packages.${system}; [ json ];
};

selectedLibs = with idris2-withpkgs.packages.${system}; [ json http2 ] ++ [ my-private-pkg ];
```

---

## Troubleshooting

### "Required X any but no matching version is installed"

The `.ipkg` file declares a dependency that isn't in `selectedLibs`.

**Fix**: Ensure `taiga-cli.ipkg` and `flake.nix` agree on package names. Note that some packages have different names in the registry vs. their `.ipkg` name. For example, the `http2` Idris package is provided by the `http2` Nix attribute.

### "attribute 'doc-browser' missing"

Your `idris2-withpkgs` input is too old (before doc-browser was added).

**Fix**:
```shell
nix flake update idris2-withpkgs
```

### "hash mismatch in fixed-output derivation"

An upstream package source changed (e.g., force-push to `main` branch).

**Fix**: This is a registry issue. If using a registry with `rev = "main"`, the hash may drift. The curated packages in the registry use pinned commits. You can:
- Update the registry to a newer commit that has fixed hashes
- Or temporarily switch to a local registry with fixed hashes

### Docs show "Available package documentation:" but empty list

The `projectDocs` derivation didn't find any docs directories.

**Fix**: Check that the `-docs` packages exist:
```shell
nix eval .#docs --json 2>/dev/null | jq
```

Verify the docs packages build individually:
```shell
nix build .#json-docs
ls result/share/doc/
```

### "Unknown dependency 'X' for package 'Y'"

A package in the registry declares a dependency that doesn't exist in the registry.

**Fix**: This is a registry bug. The registry's `build-idris-with-docs.nix` should filter out built-in packages (`base`, `prelude`, `network`, etc.) and skip unknown ones. Update the registry or patch locally.

---

## Reference

### Flake Outputs

| Output | Description |
|--------|-------------|
| `.#default` | `taiga-cli` executable |
| `.#docs` | Browsable docs bundle with `doc-browser` |

### DevShell Commands

| Command | Description |
|---------|-------------|
| `build` | Build `taiga-cli.ipkg` |
| `run` | Build and run the executable |
| `tcli` | Run the built executable |
| `docs` | Show available package docs |
| `doc-browser` | Browse docs interactively |

### Key Files

| File | Purpose |
|------|---------|
| `flake.nix` | Flake definition — inputs, packages, devShell |
| `flake.lock` | Locked input versions |
| `taiga-cli.ipkg` | Idris 2 package manifest — canonical dependency list |
| `src/` | Source code |

### Registry Reference

The `idris2-withpkgs` flake exposes:

| Attribute | Description |
|-----------|-------------|
| `packages.<system>.<name>` | Library package (e.g., `json`, `http2`) |
| `packages.<system>.<name>-docs` | Markdown docs for the package |
| `packages.<system>.<name>-docs-with-browser` | Docs + wrapped doc-browser |
| `packages.<system>.all-docs` | Curated bundle of all packages |
| `packages.<system>.doc-browser` | Standalone doc-browser script |
| `packages.<system>.idris2-mkdoc-md` | The docs generator itself |
| `lib.<system>.withPackages` | Function to create wrapped Idris 2 |

### Nix Commands

```shell
# Update all inputs
nix flake update

# Update specific input
nix flake update idris2-withpkgs

# Enter devShell
nix develop

# Build specific output
nix build .#default
nix build .#docs

# Run command in devShell without entering
nix develop --command doc-browser list

# Check flake evaluates
nix flake check

# Show flake metadata
nix flake metadata

# Show available packages in registry
nix eval --impure --expr "
  let flake = builtins.getFlake \"github:gvnkd/flake-idris2-withPackages\";
  in builtins.attrNames flake.packages.x86_64-linux
"
```

---

## Contributing Changes to the Flake

When modifying `flake.nix`:

1. **Update the lock file** if you changed inputs:
   ```shell
   nix flake lock
   ```

2. **Build all outputs**:
   ```shell
   nix build .#default .#docs
   ```

3. **Test the devShell**:
   ```shell
   nix develop --command build
   nix develop --command doc-browser list
   ```

4. **Commit both `flake.nix` and `flake.lock`**:
   ```shell
   git add flake.nix flake.lock
   git commit -m "..."
   ```

5. **Never commit with `path:` inputs**: Always use the GitHub URL for committed code.

---

*This document is maintained alongside the flake. When the flake changes, update this document.*
