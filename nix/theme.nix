{
  pkgs,
  source,
  width,
  height,
  style,
}:

let
  panelWidth =
    if builtins.div (4 * height) 9 >= builtins.div width 4 then
      builtins.div width 4
    else
      builtins.div (4 * height) 9;
  panelPadding = builtins.div panelWidth 12;
in
pkgs.runCommand "sakoora-hyprlock-${toString width}x${toString height}"
  {
    nativeBuildInputs = [
      pkgs.bash
      pkgs.coreutils
    ];
  }
  ''
    mkdir -p "$out"
    cp -R ${source}/styles ${source}/to_move ${source}/style-1 ${source}/style-2 "$out/"
    chmod -R u+w "$out"

    export S_PATH="$out"
    export width=${toString width}
    export height=${toString height}
    export pw=${toString panelWidth}
    export pp=${toString panelPadding}

    bash "$out/style-1"
    bash "$out/style-2"

    theme_dir="$out/to_move/sakoora.hyprlock"
    rm "$theme_dir/current_style.conf"
    ln -s "style-${toString style}/hyprlock.conf" "$theme_dir/current_style.conf"
    patchShebangs "$theme_dir"
  ''
