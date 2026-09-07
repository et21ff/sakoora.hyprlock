{
  pkgs,
  source,
  style,
}:

let
  fontConfig = pkgs.makeFontsConf {
    fontDirectories = [
      "${source}/to_move"
      pkgs.noto-fonts-cjk-sans
    ];
  };
  wallpaperCheck = pkgs.lib.optionalString (style == 2) ''
    if [[ ! -f "$SAKOORA_WALLPAPER" ]]; then
      echo "Style 2 requires a wallpaper." >&2
      echo "Set SAKOORA_WALLPAPER=/path/to/wallpaper.png and try again." >&2
      exit 1
    fi
  '';
in
pkgs.writeShellApplication {
  name = "sakoora-preview-style-${toString style}";

  runtimeInputs = [
    pkgs.bash
    pkgs.bluez
    pkgs.coreutils
    pkgs.fd
    pkgs.findutils
    pkgs.gnugrep
    pkgs.gnused
    pkgs.grim
    pkgs.hyprlock
    pkgs.imagemagick
    pkgs.jq
    pkgs.networkmanager
    pkgs.playerctl
    pkgs.procps
    pkgs.systemd
    pkgs.wlr-randr
  ];

  text = ''
    if [[ ! -e /etc/pam.d/hyprlock ]]; then
      echo "Refusing to lock: /etc/pam.d/hyprlock does not exist." >&2
      echo "Enable security.pam.services.hyprlock in NixOS first." >&2
      exit 1
    fi

    original_home="$HOME"
    runtime_root="$(mktemp -d "''${XDG_RUNTIME_DIR:-/tmp}/sakoora-hyprlock.XXXXXXXX")"
    trap 'rm -rf -- "$runtime_root"' EXIT HUP INT TERM

    resolution=""
    if [[ -n "''${SAKOORA_RESOLUTION:-}" ]]; then
      if [[ "$SAKOORA_RESOLUTION" =~ ^([0-9]+)x([0-9]+)$ ]]; then
        resolution="''${BASH_REMATCH[1]} ''${BASH_REMATCH[2]}"
      else
        echo "SAKOORA_RESOLUTION must use WIDTHxHEIGHT, for example 2560x1440." >&2
        exit 1
      fi
    elif command -v hyprctl >/dev/null && monitor_json="$(hyprctl -j monitors 2>/dev/null)"; then
      resolution="$(
        jq -r --arg monitor "''${SAKOORA_MONITOR:-}" '
          (if $monitor != "" then
            map(select(.name == $monitor))[0]
          else
            (map(select(.focused))[0] // .[0])
          end)
          | select(. != null)
          | "\(.width) \(.height)"
        ' <<< "$monitor_json"
      )"
    elif output_json="$(wlr-randr --json 2>/dev/null)"; then
      resolution="$(
        jq -r --arg monitor "''${SAKOORA_MONITOR:-}" '
          map(select(.enabled and ($monitor == "" or .name == $monitor)))[0]
          | select(. != null)
          | .modes[]
          | select(.current)
          | "\(.width) \(.height)"
        ' <<< "$output_json"
      )"
    else
      echo "Could not query outputs with hyprctl or wlr-randr." >&2
      echo "Set SAKOORA_RESOLUTION=WIDTHxHEIGHT to specify it manually." >&2
      exit 1
    fi

    if [[ -z "$resolution" ]]; then
      echo "Could not determine a monitor resolution." >&2
      exit 1
    fi

    read -r width height <<< "$resolution"
    if (( 4 * height / 9 >= width / 4 )); then
      pw=$((width / 4))
    else
      pw=$((4 * height / 9))
    fi
    pp=$((pw / 12))

    cp -R ${source}/styles ${source}/to_move ${source}/style-1 ${source}/style-2 "$runtime_root/"
    chmod -R u+w "$runtime_root"

    export S_PATH="$runtime_root"
    export width height pw pp
    bash "$runtime_root/style-${toString style}"

    theme_dir="$runtime_root/to_move/sakoora.hyprlock"
    rm "$theme_dir/current_style.conf"
    ln -s "style-${toString style}/hyprlock.conf" "$theme_dir/current_style.conf"

    temporary_home="$runtime_root/home"
    mkdir -p "$temporary_home/.config/hypr"
    ln -s "$theme_dir" "$temporary_home/.config/hypr/sakoora.hyprlock"

    export FONTCONFIG_FILE=${fontConfig}
    export SAKOORA_WALLPAPER="''${SAKOORA_WALLPAPER:-$original_home/.config/themes/wallpaper.png}"
    export HOME="$temporary_home"

    ${wallpaperCheck}

    "$theme_dir/style-${toString style}/scripts/panels"
    hyprlock --config "$theme_dir/current_style.conf" --grace "''${SAKOORA_GRACE:-5}" "$@"
  '';
}
