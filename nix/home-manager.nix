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
  monitorName = if cfg.monitor.name == null then "" else cfg.monitor.name;
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
    monitor = monitorName;
  };

  multi = cfg.monitors != [ ];
  dynamic = cfg.autoDetect || lib.any (m: m.width == null || m.height == null) cfg.monitors;
  runtimeSettings = pkgs.writeText "sakoora-outputs.json" (
    builtins.toJSON {
      inherit (cfg) monitors autoDetect;
    }
  );
  outputThemes = lib.imap0 (index: monitor: {
    inherit monitor;
    id = "output${toString index}";
    theme = import ./theme.nix {
      inherit pkgs;
      inherit (monitor) width height;
      source = self;
      style = cfg.style;
      monitor = monitor.name;
      namespace = "output${toString index}";
    };
  }) cfg.monitors;
  multiTheme = pkgs.runCommand "sakoora-hyprlock-multi" { } ''
    mkdir -p "$out/outputs"
    ${lib.concatMapStringsSep "\n" (output: ''
      ln -s ${output.theme}/to_move/sakoora.hyprlock "$out/outputs/${output.id}"
      # Animation definitions apply globally, so include them only once.
      ${if output.id == "output0" then "cat" else "sed '/^animations {$/,/^}$/d'"} \
        ${output.theme}/to_move/sakoora.hyprlock/current_style.conf >> "$out/current_style.conf"
      printf '\n' >> "$out/current_style.conf"
    '') outputThemes}
  '';

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
    pkgs.wlr-randr
    pkgs.jq
    pkgs.python3
    pkgs.bash
  ];

  panels = pkgs.writeShellApplication {
    name = "sakoora-panels";
    inherit runtimeInputs;
    text =
      if dynamic then
        ''
          exec python3 ${./runtime-layout.py} ${self} ${runtimeSettings} ${toString cfg.style} "$@"
        ''
      else if multi then
        ''
          outputs=$(wlr-randr --json)
          pids=()
          ${lib.concatMapStringsSep "\n" (output: ''
            if jq -e --arg name ${lib.escapeShellArg output.monitor.name} \
              'any(.[]; .enabled and .name == $name)' <<< "$outputs" >/dev/null; then
              SAKOORA_MONITOR=${lib.escapeShellArg output.monitor.name} \
                "$HOME/.config/hypr/sakoora.hyprlock/outputs/${output.id}/style-${toString cfg.style}/scripts/panels" "$@" &
              pids+=("$!")
            fi
          '') outputThemes}
          failed=0
          for pid in "''${pids[@]}"; do
            wait "$pid" || failed=1
          done
          exit "$failed"
        ''
      else
        ''
          export SAKOORA_MONITOR=${lib.escapeShellArg monitorName}
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
      name = mkOption {
        type = types.nullOr (types.strMatching "[A-Za-z0-9._-]+");
        default = null;
        example = "DP-1";
        description = "Output name on which to render the theme, or null for all outputs.";
      };

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

    autoDetect = mkOption {
      type = types.bool;
      default = false;
      description = "Generate layouts at lock time for all enabled outputs, using their maximum supported pixel area. Named monitors override automatic dimensions.";
    };

    monitors = mkOption {
      default = [ ];
      description = "Independent output layouts. A nonempty list replaces the legacy monitor option. Omit both dimensions to select the maximum supported resolution at lock time.";
      type = types.listOf (
        types.submodule {
          options = {
            name = mkOption { type = types.strMatching "[A-Za-z0-9._-]+"; };
            width = mkOption {
              type = types.nullOr types.ints.positive;
              default = null;
            };
            height = mkOption {
              type = types.nullOr types.ints.positive;
              default = null;
            };
          };
        }
      );
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
        assertion =
          if multi || dynamic then
            lib.all (
              m:
              (m.width == null && m.height == null)
              || (
                m.width != null
                && m.height != null
                && builtins.div (lib.min (builtins.div (4 * m.height) 9) (builtins.div m.width 4)) 12 > 0
              )
            ) cfg.monitors
          else
            panelPadding > 0;
        message = "sakoora-hyprlock: specify both width and height (or neither); dimensions must produce a usable layout";
      }
      {
        assertion =
          !multi
          || builtins.length (lib.unique (map (m: m.name) cfg.monitors)) == builtins.length cfg.monitors;
        message = "sakoora-hyprlock.monitors must contain unique output names";
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

    xdg.configFile."hypr/sakoora.hyprlock" = mkIf (!dynamic) {
      source = if multi then multiTheme else "${theme}/to_move/sakoora.hyprlock";
    };

    programs.hyprlock = {
      enable = true;
      package = cfg.package;
      extraConfig = mkAfter ''
        source = ${
          if dynamic then
            "~/.cache/sakoora-layout/current_style.conf"
          else
            "~/.config/hypr/sakoora.hyprlock/current_style.conf"
        }
      '';
    };
  };
}
