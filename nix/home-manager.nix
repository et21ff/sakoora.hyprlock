{ self }:
{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib)
    mkAfter
    mkEnableOption
    mkIf
    mkOption
    types
    ;

  cfg = config.sakoora-hyprlock;
  width = cfg.monitor.width;
  height = cfg.monitor.height;
  panelWidth =
    if builtins.div (4 * height) 9 >= builtins.div width 4 then
      builtins.div width 4
    else
      builtins.div (4 * height) 9;
  panelPadding = builtins.div panelWidth 12;

  theme = import ./theme.nix {
    inherit
      height
      pkgs
      width
      ;
    source = self;
    style = cfg.style;
  };

  runtimeInputs = [
    pkgs.bluez
    pkgs.coreutils
    pkgs.fd
    pkgs.findutils
    pkgs.gnugrep
    pkgs.gnused
    pkgs.grim
    pkgs.imagemagick
    pkgs.networkmanager
    pkgs.playerctl
    pkgs.procps
    pkgs.systemd
  ];

  panels = pkgs.writeShellApplication {
    name = "sakoora-panels";
    inherit runtimeInputs;
    text = ''
      exec "$HOME/.config/hypr/sakoora.hyprlock/style-${toString cfg.style}/scripts/panels" "$@"
    '';
  };

  lock = pkgs.writeShellApplication {
    name = "sakoora-lock";
    runtimeInputs = runtimeInputs ++ [
      cfg.package
      panels
    ];
    text = ''
      sakoora-panels
      exec hyprlock --grace ${toString cfg.grace} "$@"
    '';
  };

  fonts = pkgs.runCommand "sakoora-hyprlock-fonts" { } ''
    font_dir="$out/share/fonts/truetype/sakoora"
    mkdir -p "$font_dir"
    cp ${self}/to_move/*.ttf "$font_dir/"
  '';
in
{
  options.sakoora-hyprlock = {
    enable = mkEnableOption "the sakoora.hyprlock theme";

    style = mkOption {
      type = types.enum [
        1
        2
      ];
      default = 1;
      description = "Theme style to activate.";
    };

    monitor = {
      width = mkOption {
        type = types.ints.positive;
        example = 2560;
        description = "Physical monitor width in pixels.";
      };

      height = mkOption {
        type = types.ints.positive;
        example = 1440;
        description = "Physical monitor height in pixels.";
      };
    };

    grace = mkOption {
      type = types.ints.unsigned;
      default = 5;
      description = "Number of seconds passed to hyprlock's --grace option.";
    };

    package = mkOption {
      type = types.package;
      default = pkgs.hyprlock;
      defaultText = lib.literalExpression "pkgs.hyprlock";
      description = "Hyprlock package to use.";
    };

    installFonts = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to install the bundled fonts and a CJK fallback font.";
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = panelPadding > 0;
        message = "sakoora-hyprlock.monitor is too small to produce a usable layout";
      }
    ];

    home.packages = [
      lock
      panels
    ]
    ++ lib.optionals cfg.installFonts [
      fonts
      pkgs.noto-fonts-cjk-sans
    ];

    xdg.configFile."hypr/sakoora.hyprlock".source = "${theme}/to_move/sakoora.hyprlock";

    programs.hyprlock = {
      enable = true;
      package = cfg.package;
      extraConfig = mkAfter ''
        source = ~/.config/hypr/sakoora.hyprlock/current_style.conf
      '';
    };
  };
}
