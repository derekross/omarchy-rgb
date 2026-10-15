# omarchy-rgb

Theme-colored lighting for Omarchy. Your keyboard, mouse and other
[OpenRGB](https://openrgb.org) devices, plus Corsair VOID headsets, follow the
current theme, and a bar widget switches between effects.

- **Static**: the theme's keyboard color.
- **Pulse**: the same color breathing bright to dim.
- **Wave**: a wave across each device's physical layout, in the colors around
  the theme's accent.
- **Manual**: hands control back. Colors you set in the OpenRGB app stay, and
  headsets return to their own lighting.
- **Off**: all lights dark.

## Install

```bash
omarchy pkg add openrgb
omarchy plugin add https://github.com/derekross/omarchy-rgb.git --enable
```

That's all. The plugin's service runs inside the Omarchy shell and keeps two
processes going for your session:

- an OpenRGB SDK server on 127.0.0.1, unless one is already running
- the effects daemon in `bin/omarchy-rgb`

Both stop when the shell does. For the `omarchy-rgb` command in a terminal,
link it onto your PATH:

```bash
ln -s ~/.config/omarchy/plugins/derekross.rgb/bin/omarchy-rgb ~/.local/bin/
```

## Use

Click the keyboard icon in the bar for the panel. Right-click turns the lights
off and back on. **Open OpenRGB** switches to Manual and opens the OpenRGB app
for picking your own colors.

From a terminal:

```bash
omarchy-rgb effect wave     # static, pulse, wave, manual or off
omarchy-rgb status          # effect, colors and devices as JSON
```

## Colors

- **Static and pulse** use the theme's own keyboard color (`keyboard.rgb`) if
  it has one, otherwise its accent color.
- **Wave** takes the accent and the theme colors within 60° of it on the color
  wheel, plus the keyboard color when the theme has one, all saturated so they
  read well on LEDs. Tokyo Night, for example, runs cyan → blue → violet →
  magenta.

To change one theme's keyboard color without editing the theme, use an Omarchy
theme overlay, then re-apply the theme:

```bash
mkdir -p ~/.config/omarchy/themes/tokyo-night
echo '#7aa2f7' > ~/.config/omarchy/themes/tokyo-night/keyboard.rgb
omarchy theme set tokyo-night
```

`LED_SATURATION`, `WAVE_HUE_RANGE` and the effect timings are at the top of
`bin/omarchy-rgb`. After changing them, restart the shell with
`omarchy restart shell`.

## Corsair VOID headsets

OpenRGB doesn't support these headsets yet, so the daemon drives them directly
over hidraw. The protocol comes from SignalRGB's VOID PRO plugin, and has been
tested on a VOID PRO Wireless (`1b1c:0a1a`).

The headset's mic mute LED stays off while the daemon controls the lighting. It
comes back in Manual mode, or when the headset is switched off and on.

## How it works

The daemon talks to the OpenRGB SDK server using only Python's standard
library. It watches the current theme and `~/.local/state/omarchy/rgb-effect`
for changes, so switching themes or effects needs no signals or restarts. The
bar widget reads `omarchy-rgb status`.
