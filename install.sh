#!/usr/bin/env bash
set -e

# Battery Watts Plasmoid - Install Script

echo "==> Installing Battery Watts plasmoid..."

PLASMOID_ID="com.mintocha.batterywatts"

# 1. Install or update the plasmoid package
kpackagetool6 --type Plasma/Applet --upgrade . 2>/dev/null || \
    kpackagetool6 --type Plasma/Applet --install . 2>/dev/null || \
    {
        kpackagetool6 --type Plasma/Applet --remove "$PLASMOID_ID" 2>/dev/null || true
        kpackagetool6 --type Plasma/Applet --install .
    }

echo ""
echo "==> Restarting Plasma..."
kquitapp6 plasmashell 2>/dev/null || true
sleep 2
kstart plasmashell

echo ""
echo "==> Done!"
echo ""
echo "    Then right-click panel -> Enter Edit Mode -> Add Widgets -> Battery Watts"
