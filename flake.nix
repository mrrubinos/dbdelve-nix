{
  description = "DBDelve, a native multi-engine database client";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    dbdelve-src = {
      url = "github:ShayanAbbas1/dbdelve";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      dbdelve-src,
    }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});

      dbdelve =
        {
          lib,
          rustPlatform,
          pkg-config,
          fontconfig,
          freetype,
          libxkbcommon,
          wayland,
          libxcb,
          libx11,
          vulkan-loader,
          libGL,
          unixodbc,
          zstd,
        }:
        let
          manifest = lib.importTOML "${dbdelve-src}/Cargo.toml";
          runtimeLibs = [
            vulkan-loader
            libGL
            wayland
            libxkbcommon
            fontconfig
            libx11
            libxcb
          ];
        in
        rustPlatform.buildRustPackage {
          pname = "dbdelve";
          version = manifest.workspace.package.version;
          src = dbdelve-src;

          cargoLock.lockFile = "${dbdelve-src}/Cargo.lock";

          cargoBuildFlags = [
            "--package"
            "dbdelve"
            "--package"
            "dbdelve-plugin-odbc"
          ];

          nativeBuildInputs = [
            pkg-config
            rustPlatform.bindgenHook
          ];

          buildInputs = [
            fontconfig
            freetype
            libxkbcommon
            wayland
            libxcb
            libx11
            unixodbc
            zstd
          ];

          # The suite needs live database containers and a GPU adapter.
          doCheck = false;

          postInstall = ''
            libexec=$out/libexec/dbdelve
            mkdir -p $libexec/plugins/odbc/bin
            mv $out/bin/dbdelve $libexec/dbdelve
            mv $out/bin/dbdelve-odbc $libexec/plugins/odbc/bin/dbdelve-odbc
            install -Dm644 plugins/odbc/dbdelve-plugin.toml $libexec/plugins/odbc/dbdelve-plugin.toml
            ln -s $libexec/dbdelve $out/bin/dbdelve

            install -Dm644 assets/linux/dbdelve.desktop $out/share/applications/dbdelve.desktop
            for png in assets/linux/icons/dbdelve-*.png; do
              size=''${png##*-}
              size=''${size%.png}
              install -Dm644 $png $out/share/icons/hicolor/''${size}x''${size}/apps/dbdelve.png
            done
          '';

          postFixup = ''
            patchelf --add-rpath ${lib.makeLibraryPath runtimeLibs} $out/libexec/dbdelve/dbdelve
          '';

          meta = {
            description = "Fast, native, multi-engine database client";
            homepage = "https://github.com/ShayanAbbas1/dbdelve";
            license = lib.licenses.gpl3Only;
            mainProgram = "dbdelve";
            platforms = systems;
          };
        };
    in
    {
      packages = forAllSystems (pkgs: {
        dbdelve = pkgs.callPackage dbdelve { };
        default = self.packages.${pkgs.stdenv.hostPlatform.system}.dbdelve;
      });

      apps = forAllSystems (pkgs: {
        default = {
          type = "app";
          program = nixpkgs.lib.getExe self.packages.${pkgs.stdenv.hostPlatform.system}.dbdelve;
        };
      });
    };
}
