{ pkgs, lib, ... }:

{
  # Identity & Localization
  time.timeZone = "Etc/UTC";
  i18n.defaultLocale = "en_US.UTF-8";

  # User Configuration
  users.users = {
    ferrarimarco = {
      isNormalUser = true;
      extraGroups = [
        "wheel"
        "networkmanager"
      ];
      # TODO: Add public SSH key
      # openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAAC3..." ];
    };
  };

  # System Maintenance
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    # Deduplicate files in the store to save disk space
    auto-optimise-store = true;
    # Allow the user 'wheel' (sudo) to run nix commands
    trusted-users = [
      "root"
      "@wheel"
    ];
  };

  # Automatically remove old build inputs periodically
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  # Essential Tools
  environment.systemPackages = with pkgs; [
    vim
    git
    curl
    wget
    tmux
  ];

  services = {
    openssh = {
      enable = true;
      settings = {
        ChallengeResponseAuthentication = lib.mkDefault "no";
        GSSAPIAuthentication = lib.mkDefault "no";
        PasswordAuthentication = lib.mkDefault false;
        PermitEmptyPasswords = lib.mkDefault "no";
        PermitRootLogin = lib.mkDefault "no";
        UseDns = lib.mkDefault false;
        X11Forwarding = lib.mkDefault false;
      };
    };
  };

  system.stateVersion = "25.11";
}
