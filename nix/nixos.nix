{
  config,
  lib,
  ...
}:

let
  cfg = config.sakoora-hyprlock;
in
{
  options.sakoora-hyprlock.enable = lib.mkEnableOption "PAM authentication for sakoora.hyprlock";

  config = lib.mkIf cfg.enable {
    security.pam.services.hyprlock = { };
  };
}
