{
  description = "Build a cargo project without extra checks";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-23.11";
    crane = {
      url = "github:ipetkov/crane";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, crane, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        craneLib = crane.lib.${system};

        nginxWithStream = pkgs.nginxMainline.overrideAttrs (oldAttrs: {
          configureFlags = oldAttrs.configureFlags ++ [
            "--with-stream"
            "--with-stream_ssl_module"
            "--error-log-path=/dev/null"
          ];
        });

        ohttp-relay = craneLib.buildPackage {
          src = craneLib.cleanCargoSource (craneLib.path ./.);
          strictDeps = true;

          buildInputs = [
            nginxWithStream
          ] ++ pkgs.lib.optionals pkgs.stdenv.isDarwin [
            pkgs.libiconv
            pkgs.darwin.apple_sdk.frameworks.Security
          ];

          preBuild = ''
            export PATH=${nginxWithStream}/bin:$PATH
          '';
        };
      in
      {
        checks = {
          inherit ohttp-relay;
        };

        packages.nginx-with-stream = nginxWithStream;
        packages.default = ohttp-relay;

        apps.default = flake-utils.lib.mkApp {
          drv = ohttp-relay;
        };

        devShells.default = craneLib.devShell {
          checks = self.checks.${system};

          packages = [
            nginxWithStream
            pkgs.rustup
          ];

          shellHook = ''
            # Setup the Rust Nightly toolchain with rustup
            rustup default nightly

            # Optionally, you can also include components like rust-src for Rust Analyzer
            rustup component add rust-src
          '';
        };
      });
}
