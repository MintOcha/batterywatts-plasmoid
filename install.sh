#!/usr/bin/env bash
set -e

# Battery Watts Plasmoid - Install Script
# Works with the prebuilt binary — no build tools needed on x86_64!

PLASMOID_DIR="$HOME/.local/share/plasma/plasmoids/com.mintocha.batterywatts"
QML_PLUGIN_DIR="$HOME/.local/lib/qt6/qml/BatteryWatts"

echo "==> Installing Battery Watts plasmoid..."

# 1. Install the plasmoid package
mkdir -p "$PLASMOID_DIR"
cp -r metadata.json contents "$PLASMOID_DIR/"
echo "    Plasmoid copied to $PLASMOID_DIR"

# 2. Install the native QML plugin so BatteryWatts can be imported
mkdir -p "$QML_PLUGIN_DIR"
cp contents/code/libbatteryplugin.so "$QML_PLUGIN_DIR/"
cp contents/code/qmldir "$QML_PLUGIN_DIR/"
echo "    Native plugin installed to $QML_PLUGIN_DIR"

# 3. Register with Plasma
kpackagetool6 --type Plasma/Applet --install "$PLASMOID_DIR" 2>/dev/null || \
    echo "    (plasmoid already registered, skipping kpackagetool6)"

echo ""
echo "==> Done! Restart Plasma to see the widget:"
echo "    kquitapp6 plasmashell && sleep 2 && kstart plasmashell"
echo ""
echo "    Then right-click panel -> Enter Edit Mode -> Add Widgets -> Battery Watts"
