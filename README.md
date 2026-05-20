# Battery Watts

A minimal Plasma 6 plasmoid that reads your battery's **real-time power draw in watts** from sysfs and shows it in your panel.

## Features

- **Panel widget** — compact display of current power draw with auto-fitting text
- **Configurable popup** — customize precision, format, and polling interval
- **Custom format templates** — use `{watts}` in your own text patterns for each battery state
- **Auto-discovers battery** — works with BAT0, BAT1, BAT2, etc.
- **Polling interval** — update rate configurable from 1–60 seconds (default: 2s)
- **Two precision modes** — decimal places or significant figures
- **Refresh & Reset** — manual refresh or reset formats to defaults

## Screenshots

| Panel (compact) | Configuration popup |
|:---:|:---:|
| ![Panel](screenshots/panel.png) | ![Popup](screenshots/popup.png) |

## Requirements

- **Plasma 6**
- **Linux** with a battery at `/sys/class/power_supply/*/`

## Installation

### Method 1: Install script

```bash
git clone https://github.com/MintOcha/batterywatts-plasmoid.git
cd batterywatts-plasmoid
chmod +x install.sh
./install.sh
kquitapp6 plasmashell && sleep 2 && kstart plasmashell
```

Then right-click your panel → **Enter Edit Mode** → **Add Widgets** → search for "Battery Watts".

### Method 2: kpackagetool6

```bash
git clone https://github.com/MintOcha/batterywatts-plasmoid.git
cd batterywatts-plasmoid
kpackagetool6 --type Plasma/Applet --install .
kquitapp6 plasmashell && sleep 2 && kstart plasmashell
```

### Method 3: Download tarball

```bash
curl -LO https://github.com/MintOcha/batterywatts-plasmoid/releases/download/v0.2/com.mintocha.batterywatts-0.2.tar.gz
kpackagetool6 --type Plasma/Applet -i com.mintocha.batterywatts-0.2.tar.gz
kquitapp6 plasmashell && sleep 2 && kstart plasmashell
```

### Method 4: From Plasma's widget explorer

1. Right-click your panel → **Enter Edit Mode**
2. Click **Add Widgets**
3. Click **Get New Widgets** → **Download New Plasma Widgets**
4. Search for **"battery-power-watts"**
5. Click **Install**
6. Find "Battery Watts" in your widget list and drag it to the panel

## Format Templates

Each battery state has its own format string. Use `{watts}` as a placeholder for the numeric value:

| State | Default format | Example output |
|-------|---------------|----------------|
| Charging | `⚡ +{watts} W` | ⚡ +32.4 W |
| Discharging | `🔋 -{watts} W` | 🔋 -9.8 W |
| Full | `✓ {watts} W` | ✓ 0.0 W |
| Not charging | `🔌 {watts} W` | 🔌 0.5 W |

## How it works

The widget uses `Plasma5Support.DataSource` with the `executable` engine to read from sysfs:

```
/sys/class/power_supply/*/power_now   (in microwatts → divided by 1,000,000)
/sys/class/power_supply/*/status      (Charging / Discharging / Full)
```

The battery is auto-discovered — no configuration needed.

## License

MIT
