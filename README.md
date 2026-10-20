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

## Remove

```bash
omarchy plugin remove derekross.rgb
```

Removing the plugin stops the daemon and the OpenRGB server it started, and
headsets get their own lighting back. If you linked `omarchy-rgb` onto your
PATH, delete the link with `rm ~/.local/bin/omarchy-rgb`. The daemon's state
is in `~/.local/state/omarchy/`, in files starting with `rgb-`, and you can
delete those too. Turn room sync off before removing the plugin, so your
room lights get their own colors back. OpenRGB itself stays installed.

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

## Room lights (Philips Hue)

The effects can also light your room through a Hue Entertainment area. This
is off by default, and the panel only shows a **Room lights** switch once
OpenRGB has found an Entertainment area.

1. In the Hue app, create an Entertainment area with the lights you want.
2. Pair your bridge in OpenRGB with Entertainment mode on (Settings → Philips
   Hue, or Manual Devices in newer versions). OpenRGB needs the bridge's IP
   and MAC address, and you press the button on the bridge to pair.
3. Restart the shell so the plugin's OpenRGB server picks up the bridge.

From a terminal:

```bash
omarchy-rgb room on         # on, off or toggle
```

When room sync turns on, each light's current state is saved from the bridge
to `~/.local/state/omarchy/rgb-room-snapshot.json`. When it turns off, or the
panel switches to Manual, the stream ends and the lights are put back,
because Hue lights otherwise keep the last streamed color. If the daemon
stops unexpectedly, it puts the lights back the next time it starts.

The daemon reads the bridge key from OpenRGB's settings and talks to the
bridge over HTTPS. No public authority signs a Hue bridge's certificate, so
the first time a key is used the daemon saves the bridge's certificate
fingerprint to `~/.local/state/omarchy/rgb-hue-bridge.json`, and from then on
it sends the key only to a bridge presenting that same certificate. If you
replace or reset the bridge, pair it again in OpenRGB (a new key starts a new
pin) or delete that file.

## How it works

The daemon talks to the OpenRGB SDK server using only Python's standard
library. It watches the current theme and `~/.local/state/omarchy/rgb-effect`
for changes, so switching themes or effects needs no signals or restarts. The
bar widget reads `omarchy-rgb status`.
