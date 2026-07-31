#!/usr/bin/env bash
# =============================================================================
# build.sh — Build a Soda (Bottles) Wine runner with the d2d1-dcomp patch set
#
# This mirrors the official bottlesdevs "Soda" CI build (build-soda.yml in
# bottlesdevs/wine) and injects the Direct2D 1.3 / DirectComposition patch
# series from patches/*.mypatch as wine-tkg user patches.
#
# Result: dist/soda-d2d1-11.0-2-x86_64.tar.xz — extract into
#         ~/.local/share/bottles/runners/ and select it in Bottles.
#
# Requirements: a Debian/Ubuntu-ish host (the wine-tkg dependency autoresolver
# uses apt via sudo), ~4 GB free disk, ~30-60 min.
# =============================================================================
set -euo pipefail

PKG_BASENAME="soda-d2d1-11.0-2"
# The wine source: Valve's Proton wine bleeding-edge tag pinned by the
# bottlesdevs soda recipe (build-tools: runners/vaniglia/wine-tkg-valve.cfg,
# commit fcba104217 "update Soda recipe to Wine 11").
BLEEDING_TAG="experimental-wine-bleeding-edge-11.0-406792-20260730-p6ed41e-w6eabc7-d6227b6-v651f17"
RECIPE_URL="https://raw.githubusercontent.com/bottlesdevs/build-tools/main/runners/vaniglia/wine-tkg-valve.cfg"

cd "$(dirname "$0")"
REPO_ROOT="$PWD"
WORKDIR="$PWD/.work"
TKG_DIR="$WORKDIR/wine-tkg-git"

mkdir -p "$WORKDIR" dist

# --- 1. Fetch wine-tkg-git (the same build system the official Soda uses) ---
if [ ! -d "$TKG_DIR/wine-tkg-git" ]; then
    git clone --depth 1 https://github.com/Frogging-Family/wine-tkg-git.git "$TKG_DIR"
fi
cd "$TKG_DIR/wine-tkg-git"

# --- 2. Select the valve-exp-bleeding preset, like build-soda.yml does -------
sed -i 's/_LOCAL_PRESET=""/_LOCAL_PRESET="valve-exp-bleeding"/g' customization.cfg

# --- 3. Pin the exact wine tag ----------------------------------------------
# NOTE: the bottlesdevs recipe sets _bleeding_tag in the external cfg, but the
# valve-exp-bleeding profile is sourced *after* it and resets it, so the pin
# never takes effect. Force it in the profile file, which is sourced last.
# (tkg has no de-steamify patch for 11.0 yet; the valve hotfixer just warns
# "No de-steamify patch for this version... Yet" and skips it — harmless.)
PROFILE="wine-tkg-profiles/wine-tkg-valve-exp-bleeding.cfg"
sed -i "s|_bleeding_tag=\".*\"|_bleeding_tag=\"$BLEEDING_TAG\"|" "$PROFILE"

# --- 5. Fetch the official soda recipe, like build-soda.yml does -------------
mkdir -p "$HOME/.config/frogminer"
curl -fsSL "$RECIPE_URL" -o "$HOME/.config/frogminer/wine-tkg.cfg"

# --- 6. Install the d2d1-dcomp patch set as wine-tkg user patches ------------
cp "$REPO_ROOT"/patches/*.mypatch wine-tkg-userpatches/

# --- 7. Build (installs build deps via apt/sudo through tkg's autoresolver) --
yes | ./non-makepkg-build.sh

# --- 8. Package like the official workflow -----------------------------------
cd non-makepkg-builds
mv wine-tkg-* "${PKG_BASENAME}-x86_64"
tar cJvf "$REPO_ROOT/dist/${PKG_BASENAME}-x86_64.tar.xz" "${PKG_BASENAME}-x86_64"

echo
echo "Done: dist/${PKG_BASENAME}-x86_64.tar.xz"
echo "Install:  tar -xJf dist/${PKG_BASENAME}-x86_64.tar.xz -C ~/.local/share/bottles/runners/"
echo "Then select '$PKG_BASENAME' as the runner in Bottles."
