#!/usr/bin/env bash
set -e

# Battery Watts Plasmoid - Install Script

echo "==> Installing Battery Watts plasmoid..."

# 1. Install the plasmoid package
kpackagetool6 --type Plasma/Applet --install . 2>/dev/null || \
    echo "    (plasmoid already registered, skipping kpackagetool6)"

echo ""
echo "==> Done! Restart Plasma to see the widget:"
echo "    kquitapp6 plasmashell && sleep 2 && kstart plasmashell"
echo ""
echo "    Then right-click panel -> Enter Edit Mode -> Add Widgets -> Battery Watts"
