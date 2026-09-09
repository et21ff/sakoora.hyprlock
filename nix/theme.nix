{
  pkgs,
  source,
  width,
  height,
  style,
  monitor,
  namespace ? "",
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
      pkgs.python3
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

    monitor=${pkgs.lib.escapeShellArg monitor}
    if [[ -n "$monitor" ]]; then
      for config in "$theme_dir"/style-*/hyprlock.conf; do
        sed -i \
          -e '/^monitor[[:space:]]*=/d' \
          -e "/^background {$/a monitor = $monitor" \
          -e "/^image {$/a monitor = $monitor" \
          -e "/^shape {$/a monitor = $monitor" \
          -e "/^label {$/a monitor = $monitor" \
          -e "/^input-field {$/a monitor = $monitor" \
          "$config"
      done
    fi

    ${pkgs.lib.optionalString (namespace != "") ''
        python3 - "$theme_dir" ${pkgs.lib.escapeShellArg namespace} <<'PY'
      import pathlib, re, sys
      root = pathlib.Path(sys.argv[1])
      namespace = sys.argv[2]
      # Hyprlang variables are global: give every output its own names.
      variables = set()
      for path in root.rglob("*.conf"):
          variables.update(re.findall(r"^\$([A-Za-z_][A-Za-z_0-9]*)\s*=", path.read_text(), re.M))
      for path in root.rglob("*"):
          if path.is_symlink() or not path.is_file():
              continue
          if path.suffix not in (".conf", ".sh") and path.parent.name != "scripts":
              continue
          text = path.read_text()
          text = text.replace("hypr/sakoora.hyprlock/", "hypr/sakoora.hyprlock/outputs/" + namespace + "/")
          text = text.replace("hyprlock-cache/", "hyprlock-cache/" + namespace + "/")
          if path.suffix == ".conf":
              text = re.sub(r"\$([A-Za-z_][A-Za-z_0-9]*)", lambda m: "$" + namespace + "_" + m[1] if m[1] in variables else m[0], text)
          path.write_text(text)
      PY
    ''}
    patchShebangs "$theme_dir"
  ''
