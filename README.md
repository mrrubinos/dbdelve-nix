# dbdelve-nix

A Nix flake that builds [DBDelve](https://github.com/ShayanAbbas1/dbdelve), a
native multi-engine database client, from source.

The flake supports `x86_64-linux` and `aarch64-linux`. It has no binary cache,
so the first build compiles DBDelve and its bundled DuckDB and SQLite.

## Outputs

- `packages.<system>.dbdelve`, also exposed as `packages.<system>.default`
- `apps.<system>.default`, which runs `dbdelve`

## Run directly

```sh
nix run github:mrrubinos/dbdelve-nix
```

## Add to a NixOS configuration

Add the flake as an input and pass it to your modules:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    dbdelve = {
      url = "github:mrrubinos/dbdelve-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { nixpkgs, dbdelve, ... }:
    {
      nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit dbdelve; };
        modules = [ ./configuration.nix ];
      };
    };
}
```

Then add the package in `configuration.nix`:

```nix
{ pkgs, dbdelve, ... }:
{
  environment.systemPackages = [
    dbdelve.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];
}
```

The `follows` line builds DBDelve against your nixpkgs. Upstream uses Rust
edition 2024, which needs rustc 1.85 or later. If the build fails with your
nixpkgs, remove the `follows` line. The flake then uses the nixpkgs revision in
its own `flake.lock`.

## System requirements

DBDelve uses these services from the host at run time:

- A Vulkan or OpenGL driver. Set `hardware.graphics.enable = true;`.
- A Secret Service provider for saved passwords, such as gnome-keyring or
  KWallet. On a desktop without one, set
  `services.gnome.gnome-keyring.enable = true;`.
- xdg-desktop-portal for the export dialog. GNOME and Plasma enable it.

The ODBC bridge reads drivers from `/etc/odbcinst.ini`. To register drivers,
set `environment.unixODBCDrivers`:

```nix
environment.unixODBCDrivers = with pkgs.unixodbcDrivers; [ psql ];
```

## Update DBDelve

This repository pins upstream as the `dbdelve-src` input. To move to the latest
upstream commit, run this in this repository:

```sh
nix flake update dbdelve-src
nix build
```

Commit the new `flake.lock`. Then update the input in your NixOS configuration:

```sh
nix flake update dbdelve
```

The package reads its version from the upstream `Cargo.toml` and its crates
from the upstream `Cargo.lock`. An update needs no hash change. If upstream
adds a git dependency to `Cargo.lock`, add its hash to `cargoLock.outputHashes`
in `flake.nix`.

## Package layout

- `bin/dbdelve` is a symlink to `libexec/dbdelve/dbdelve`.
- `libexec/dbdelve/plugins/odbc` holds the ODBC bridge. DBDelve looks for
  bundled plugins in a `plugins` directory beside its executable.
- `share/applications` and `share/icons/hicolor` hold the desktop entry and
  the icons.

The package does not run the upstream test suite. The suite needs live database
containers and a GPU adapter.
