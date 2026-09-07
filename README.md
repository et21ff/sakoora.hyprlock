<div align=center>

<img src="https://github.com/pinkSakoora/sakoora.hyprlock/blob/33a5ec211ace6b2f63b92a0fc6545cf3ad6828b4/lockbanner.png" alt="banner" width="1000"> <br>

<br>

Clean, unique hyprlock styles, bundled with a convenient installer.

</div>

<br>

<h2 align=center> overview </h2>

Notable features include:

- Adaptive element sizing and positioning according to screen resolution (when running `install`)
- Easy style switching (requiring just one word changes in `current-style.conf`)
- Self contained file structure (more in [notes](#notes))
- Small color palette: 4 colors sourced from 2 files (`colors-hyprlock.sh` and `colors-hyprlock.conf`), allowing for easier theme switching
- Various widget scripts, including network and bluetooth indicators, power status, uptime, date, time, and media player status.
- Other effects such as panel blurring, image snippets, and gradients, powered by `imagemagick`

<br>

<h2 align=center> styles preview </h2>

<h3 align=center> style-1 </h3>

<p align=center>
    <img src="https://github.com/pinkSakoora/sakoora.hyprlock/blob/33a5ec211ace6b2f63b92a0fc6545cf3ad6828b4/showcase1.png" alt="style-1 showcase" width="1000">
</p>

> [!NOTE]
> Panel blurring requires drawing ahead of time. This requires you to run the drawing script (located at `~/.config/hypr/sakoora.hyprlock/style-1/scripts/panels`) before launching hyprlock. More in [notes](#notes).

<h3 align=center> style-2 </h3>

<p align=center>
    <img src="https://github.com/pinkSakoora/sakoora.hyprlock/blob/4776f89b9890c03ecb36f2436d9fe65e01a300b0/showcase2.png" alt="style-2 showcase" width="1000">
</p>

> [!NOTE]
> Image snippets and gradients require drawing ahead of time. This requires you to run the drawing script (located at `~/.config/hypr/sakoora.hyprlock/style-2/scripts/panels`) before launching hyprlock. More in [notes](#notes).

<br>

<h2 align=center> installation </h2>

> [!WARNING]
> This has only been tested on Arch Linux.  

Cloning the repository and running `install` installs all required dependencies and sets it up.
```
git clone https://github.com/pinkSakoora/sakoora.hyprlock.git
sakoora.hyprlock/install
```
The installer asks for confirmation before installing required packages.

If you wish to install the dependencies manually, they are:
```
hyprland hyprlock imagemagick grim bluez-utils networkmanager playerctl
```
- `imagemagick` is required to draw panels.
- `grim` is used to take a screenshot for the drawing of panels.
- `bluez-utils` provides `bluetoothctl` which is used for the bluetooth indicator.
- `networkmanager` provides `nmcli` which is used for the network indicator.
- `playerctl` is used to fetch info about currently playing media.

<h3> NixOS and Home Manager </h3>

The flake exports Home Manager and NixOS modules. Add the repository to your
flake inputs:

```nix
inputs.sakoora-hyprlock.url = "github:pinkSakoora/sakoora.hyprlock";
```

Import both modules, then configure the Home Manager module with the physical
resolution of the monitor used by Hyprlock:

```nix
# NixOS configuration
imports = [ inputs.sakoora-hyprlock.nixosModules.default ];
sakoora-hyprlock.enable = true;

# Home Manager configuration
imports = [ inputs.sakoora-hyprlock.homeManagerModules.default ];

sakoora-hyprlock = {
  enable = true;
  style = 1;
  monitor = {
    name = "DP-1";
    width = 2560;
    height = 1440;
  };
};
```

The Home Manager module builds both adaptive layouts, installs the bundled
fonts and runtime dependencies, enables Hyprlock, and provides two commands:

- `sakoora-panels` prepares the selected style's generated image assets.
- `sakoora-lock` prepares those assets and then starts Hyprlock.

For example, a Home Manager Hyprland key binding can use:

```nix
wayland.windowManager.hyprland.settings.bind = [
  "$mod, L, exec, sakoora-lock"
];
```

Style 2 currently uses the upstream wallpaper location at
`~/.config/themes/wallpaper.png`.

To preview a style without installing the Home Manager module, first make sure
NixOS has `security.pam.services.hyprlock = {};`, then run from this repository:

```bash
nix run path:.#style-1
```

The preview detects the monitor name and resolution with `hyprctl` or `wlr-randr` and
creates all generated files in a temporary directory. It does not modify
`~/.config/hypr`. Use `SAKOORA_MONITOR` to select a monitor by name,
`SAKOORA_RESOLUTION` to provide the resolution manually, or `SAKOORA_GRACE` to
change the unlock grace period:

```bash
SAKOORA_MONITOR=DP-1 SAKOORA_GRACE=0 nix run path:.#style-1
```

For compositors without output-management support, specify the resolution:

```bash
SAKOORA_RESOLUTION=2560x1440 nix run path:.#style-1
```

Style 2 additionally needs a wallpaper:

```bash
SAKOORA_WALLPAPER="$HOME/Pictures/wallpaper.png" nix run path:.#style-2
```

<h2 align=center> notes </h2>
1. Every file created/modified by the installer is located within `~/.config/hypr/sakoora.hyprlock`, with the exception of `hyprlock.conf`, and font files. The old `hyprlock.conf` (if any) has a suffix of `-pre-sakoora` added to it. The added fonts are Josefin Sans and Fira Code Nerd Font Mono (at `~/.local/share/fonts/ttf`.)
2. The `panels` script for each style creates a folder named `hyprlock-cache` in `~/.cache`, in which it stores all drawn panels. This script should be called before hyprlock, especially in the case of panel drawing to ensure accuracy.

An example hypridle listener would be:
```
listener {
timeout = 270    # this timeout should be less than the timeout to launch hyprlock 
    on-timeout = ~/.config/hypr/sakoora.hyprlock/style-x/scripts/panels    # set up all required assets for hyprlock, replace x with required style
}
```
And an example hyprland keybind to lock the screen would be: 
```
bind = $mainMod, W, exec, ~/.config/hypr/sakoora.hyprlock/style-x/scripts/panels && hyprlock --grace 5
```
3. The default installed theme is a modified version of catppuccin-macchiato. The colors can be changed by modifying them in `~/.config/hypr/sakoora.hyprlock/colors-hyprlock.sh` and `~/.config/hypr/sakoora.hyprlock/colors-hyprlock.conf`.

<h2 align=center> support me! </h2>
While not necessary at all, any and all support is deeply appreciated! Below are the ways to support me:

<br>

<h3 align=center> gumroad </h3>
<p align=center>
    <a href="https://pinksakoora.gumroad.com/l/legacy-bndl" target="_blank">
    <img src="https://github.com/pinkSakoora/sakoora.hyprlock/blob/f0af69f5b771fd615a720ff846fe43ee0c286509/legacypromo.png" alt="gumroad banner" width=600>
    </a> <br>
    <a href="https://pinksakoora.gumroad.com/l/legacy-bndl" target=_blank">Legacy bundle</a> is a set of 5 handcrafted wallpapers picked from the art I've made<br> over the years. Buying this bundle is a great way to support me to allow<br> me to do what I love: art, design, and programming!
</p>

<h3 align=center> instagram </h3>
<p align=center>
    <a href="https://www.instagram.com/pinksakoora/" target="_blank">
    <img src="https://github.com/pinkSakoora/sakoora.hyprlock/blob/f0af69f5b771fd615a720ff846fe43ee0c286509/instapromo.png" alt="instagram banner" width=600>
    </a> <br>
    Following my <a href="https://www.instagram.com/pinksakoora/" target="_blank">art page</a> itself, where I post artworks and process reels, would be much appreciated too!
</p>
