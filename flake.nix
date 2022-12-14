{
  description = "Snow, my personal wayland compositor";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/release-22.11";
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
    flake-utils.url = "github:numtide/flake-utils";
    zig-overlay.url = "github:mitchellh/zig-overlay";
  };

  outputs = { self, nixpkgs, flake-utils, zig-overlay, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [
            zig-overlay.overlays.default
          ];
        };
      in rec {
        devShells = {
          snow = pkgs.mkShell {
            packages = with pkgs; [
              zigpkgs."0.10.0"

              pkg-config

              wayland-scanner.dev wayland-protocols

              wayland wlroots libxkbcommon pixman fcft
            ];
          };
          default = devShells.snow;
        };
      });
}
