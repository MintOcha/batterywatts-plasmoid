#!/usr/bin/env bash
set -e

# === Battery Watts — full release pipeline ===
# Builds the plugin, packages the tarball, installs locally to
# verify, pushes to git, creates a GitHub release, and uploads.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT="batterywatts-plasmoid"
PLASMOID_ID="com.mintocha.batterywatts"
REPO="MintOcha/$PROJECT"
VERSION="0.1"  # bump this + metadata.json for new releases

PLASMOID_DIR="$HOME/.local/share/plasma/plasmoids/$PLASMOID_ID"
QML_PLUGIN_DIR="$HOME/.local/lib/qt6/qml/BatteryWatts"
TARBALL="/tmp/$PLASMOID_ID-$VERSION.tar.gz"
CODE_DIR="$SCRIPT_DIR/contents/code"

# --- read github token from git credential store --------------------
GH_TOKEN=$(grep -oP 'github\.com\s+\K\S+' ~/.git-credentials 2>/dev/null | head -1 | sed 's|https://||;s|@github.com||;s|.*:||')
if [ -z "$GH_TOKEN" ]; then
    echo "!! no github token found in ~/.git-credentials"
    echo "   put one there, export GH_TOKEN, or pass --skip-release"
    SKIP_RELEASE=1
fi

# --- handle args ----------------------------------------------------
SKIP_BUILD=0 SKIP_RELEASE=${SKIP_RELEASE:-0}
for arg in "$@"; do
    case "$arg" in
        --skip-build)  SKIP_BUILD=1  ;;
        --skip-release) SKIP_RELEASE=1 ;;
        --help|-h)
            echo "usage: ./pipeline.sh [--skip-build] [--skip-release]"
            exit 0 ;;
    esac
done

echo "==> Battery Watts pipeline  v$VERSION"

# === step 1: build native plugin ====================================
if [ "$SKIP_BUILD" -eq 0 ]; then
    echo ""
    echo "--- [1/6] building native plugin ---"
    cd "$CODE_DIR"

    # clean old build artifacts
    rm -f *.o Makefile moc_* .qmake.stash *moc \
          plugins.qmltypes *_metatypes.json \
          *_qmltyperegistrations.cpp moc_predefs.h libbatteryplugin.so 2>/dev/null

    qmake6 batteryplugin.pro
    make
    # keep only the .so, ditch everything else
    rm -f *.o Makefile moc_* .qmake.stash *moc \
          plugins.qmltypes *_metatypes.json \
          *_qmltyperegistrations.cpp moc_predefs.h 2>/dev/null

    echo "    plugin built -> $CODE_DIR/libbatteryplugin.so"
else
    echo "    (--skip-build: using existing .so)"
fi

# === step 2: install locally to test =================================
echo ""
echo "--- [2/6] installing locally to test ---"

# remove any old install
kpackagetool6 --type Plasma/Applet --remove "$PLASMOID_ID" 2>/dev/null || true

# copy to plasmoids dir and install via kpackagetool6
mkdir -p "$PLASMOID_DIR"
cp -r "$SCRIPT_DIR/metadata.json" "$SCRIPT_DIR/contents" "$PLASMOID_DIR/"
kpackagetool6 --type Plasma/Applet --install "$PLASMOID_DIR" 2>/dev/null || true

# install the native QML plugin
mkdir -p "$QML_PLUGIN_DIR"
cp "$CODE_DIR/libbatteryplugin.so" "$QML_PLUGIN_DIR/"
cp "$CODE_DIR/qmldir" "$QML_PLUGIN_DIR/"
echo "    plasmoid   -> $PLASMOID_DIR"
echo "    qml plugin -> $QML_PLUGIN_DIR"

# restart Plasma
echo "    restarting plasmashell..."
kquitapp6 plasmashell 2>/dev/null || true
sleep 2
kstart plasmashell
echo "    (add widget to panel and verify it works before continuing)"

# === step 3: package tarball =========================================
echo ""
echo "--- [3/6] packaging tarball ---"
cd "$SCRIPT_DIR"
tar --no-xattrs -czf "$TARBALL" metadata.json contents/
ls -lh "$TARBALL"

# === step 4: install from tarball to verify ==========================
echo ""
echo "--- [4/6] verifying tarball install ---"
kpackagetool6 --type Plasma/Applet --remove "$PLASMOID_ID" 2>/dev/null || true
kpackagetool6 --type Plasma/Applet -i "$TARBALL"
# reinstall QML plugin (tarball doesn't handle that)
mkdir -p "$QML_PLUGIN_DIR"
cp "$CODE_DIR/libbatteryplugin.so" "$QML_PLUGIN_DIR/"
cp "$CODE_DIR/qmldir" "$QML_PLUGIN_DIR/"
echo "    tarball installs clean — good to release"

# === step 5: commit and push to GitHub ===============================
echo ""
echo "--- [5/6] pushing to GitHub ---"
cd "$SCRIPT_DIR"
git add -A
if git diff --cached --quiet 2>/dev/null; then
    echo "    nothing to commit"
else
    git commit -m "release v$VERSION" --allow-empty-message 2>/dev/null || \
        git commit -m "release v$VERSION"
fi
git push
echo "    pushed to $REPO"

# === step 6: GitHub release + upload asset ===========================
if [ "$SKIP_RELEASE" -eq 0 ] && [ -n "$GH_TOKEN" ]; then
    echo ""
    echo "--- [6/6] GitHub release ---"

    # delete existing release for v$VERSION and its assets, then recreate
    RELEASE_ID=$(curl -s -H "Authorization: token $GH_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/repos/$REPO/releases/tags/v$VERSION" | \
        python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null)

    if [ -n "$RELEASE_ID" ]; then
        # delete all existing assets
        ASSET_IDS=$(curl -s -H "Authorization: token $GH_TOKEN" \
            -H "Accept: application/vnd.github.v3+json" \
            "https://api.github.com/repos/$REPO/releases/$RELEASE_ID/assets" | \
            python3 -c "import sys,json; [print(a['id']) for a in json.load(sys.stdin)]" 2>/dev/null)
        for aid in $ASSET_IDS; do
            curl -s -H "Authorization: token $GH_TOKEN" -X DELETE \
                "https://api.github.com/repos/$REPO/releases/assets/$aid" >/dev/null
        done
        # delete the release
        curl -s -H "Authorization: token $GH_TOKEN" -X DELETE \
            "https://api.github.com/repos/$REPO/releases/$RELEASE_ID" >/dev/null
    fi

    # create release
    RELEASE_RESP=$(curl -s -H "Authorization: token $GH_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        -d "{\"tag_name\":\"v$VERSION\",\"target_commitish\":\"main\",\"name\":\"v$VERSION\",\"body\":\"## v$VERSION\n\n(auto-release via pipeline.sh)\",\"draft\":false,\"prerelease\":false}" \
        "https://api.github.com/repos/$REPO/releases")

    UPLOAD_URL=$(echo "$RELEASE_RESP" | python3 -c \
        "import sys,json; r=json.load(sys.stdin); print(r.get('upload_url','').split('{')[0])" 2>/dev/null)
    HTML_URL=$(echo "$RELEASE_RESP" | python3 -c \
        "import sys,json; r=json.load(sys.stdin); print(r.get('html_url',''))" 2>/dev/null)

    if [ -z "$UPLOAD_URL" ]; then
        echo "    !!! failed to create release:"
        echo "$RELEASE_RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('message','unknown'))" 2>/dev/null
        exit 1
    fi

    # upload asset
    curl -s -H "Authorization: token $GH_TOKEN" \
        -H "Content-Type: application/gzip" \
        --data-binary @"$TARBALL" \
        "${UPLOAD_URL}?name=${PLASMOID_ID}-${VERSION}.tar.gz" >/dev/null

    echo "    release created: $HTML_URL"
else
    echo ""
    echo "--- [6/6] GitHub release SKIPPED ---"
fi

# === done ============================================================
echo ""
echo "===== pipeline complete ====="
echo "  tarball: $TARBALL"
echo "  release: $HTML_URL"
echo ""
echo "  Next: upload $TARBALL to https://plasma.kde.org/upload/"
