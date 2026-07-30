#!/usr/bin/env bash
# =============================================================================
# build.sh — Build a Soda (Bottles) Wine runner with the d2d1-dcomp patch set
#
# This mirrors the official bottlesdevs "Soda" CI build (build-soda.yml in
# bottlesdevs/wine) and injects the Direct2D 1.3 / DirectComposition patch
# series from patches/*.mypatch as wine-tkg user patches.
#
# Result: dist/soda-d2d1-10.0-1-x86_64.tar.xz — extract into
#         ~/.local/share/bottles/runners/ and select it in Bottles.
#
# Requirements: a Debian/Ubuntu-ish host (the wine-tkg dependency autoresolver
# uses apt via sudo), ~4 GB free disk, ~30-60 min.
# =============================================================================
set -euo pipefail

RUNNER_NAME="soda-d2d1-10.0-1"
# The wine source: Valve's Proton wine bleeding-edge tag pinned by the
# bottlesdevs soda recipe (build-tools: runners/vaniglia/wine-tkg-valve.cfg).
BLEEDING_TAG="experimental-wine-bleeding-edge-10.0-272530-20251119-p75f008-w4a5ca6-d392494-vc01c8b"
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
# Also align _plain_version/_proton_branch with the 10.0-based tag.
PROFILE="wine-tkg-profiles/wine-tkg-valve-exp-bleeding.cfg"
sed -i "s|_bleeding_tag=\".*\"|_bleeding_tag=\"$BLEEDING_TAG\"|" "$PROFILE"
sed -i 's|experimental_11.0|experimental_10.0|g' "$PROFILE"

# --- 4. Drop the de-steamify hotfix ------------------------------------------
# tkg's de-steamify-10.0 patch currently fails 2 hunks against this bleeding
# tag (unrelated to the d2d1 series). It only strips Steam integration, which
# is harmless to keep under Bottles, so remove it to keep the build green.
# Delete this block if tkg fixes the patch upstream.
rm -f wine-tkg-patches/hotfixes/valve/de-steamify/10.0/de-steamify-valve-exp-bleeding.mypatch

# --- 5. Fetch the official soda recipe, like build-soda.yml does -------------
mkdir -p "$HOME/.config/frogminer"
curl -fsSL "$RECIPE_URL" -o "$HOME/.config/frogminer/wine-tkg.cfg"

# --- 6. Install the d2d1-dcomp patch set as wine-tkg user patches ------------
cp "$REPO_ROOT"/patches/*.mypatch wine-tkg-userpatches/

# --- 7. Build (installs build deps via apt/sudo through tkg's autoresolver) --
yes | ./non-makepkg-build.sh

# --- 8. Package like the official workflow -----------------------------------
cd non-makepkg-builds
mv wine-tkg-* "${RUNNER_NAME}-x86_64"
tar cJvf "$REPO_ROOT/dist/${RUNNER_NAME}-x86_64.tar.xz" "${RUNNER_NAME}-x86_64"

echo
echo "Done: dist/${RUNNER_NAME}-x86_64.tar.xz"
echo "Install:  tar -xJf dist/${RUNNER_NAME}-x86_64.tar.xz -C ~/.local/share/bottles/runners/"
echo "Then select '$RUNNER_NAME' as the runner in Bottles."
