{ pkgs, ... }:

import ../../tests/make-test.nix {
  inherit pkgs;
  hostConfiguration = ./configuration.nix;
}
