# soda-wined2d1 — Soda (Bottles) Wine runner with Direct2D 1.3 + DirectComposition patches

A Bottles **Soda**-flavored Wine runner with [giang17](https://github.com/giang17/wine)'s
`d2d1-dcomp-11.0` patch series backported onto it. It fixes JUCE 8 / VSTGUI / SynthEdit
audio-plugin GUIs rendering as **black windows** under Wine (Pianoteq 9, Serum 2, Korg
Trinity/Prophecy, EZkeys 2, Garritan CFX, …).

**Rule of thumb:** if a plugin's window is black/blank under a stock runner but the audio
works, it's almost certainly this Direct2D/DirectComposition issue:

```
DCompositionCreateDevice failed: Not implemented. (0x80004001)
```

Stock Wine implements only Direct2D 1.2 and no `dcomp.dll` DirectComposition; JUCE 8's
Direct2D 1.3 + DComp render path has nothing to draw into. The patch series implements
both.

This is a port of [mklnln/wine-d2d1-dcomp](https://github.com/mklnln/wine-d2d1-dcomp)
(which packages the same patch series as a standalone Wine 11.0 build) to the **Soda
runner from Bottles**.

## What the runner is built from

Exactly what the official Soda CI build uses, plus the patch set:

- **Build system**: [Frogging-Family/wine-tkg-git](https://github.com/Frogging-Family/wine-tkg-git),
  `valve-exp-bleeding` preset
- **Recipe**: [bottlesdevs/build-tools `runners/vaniglia/wine-tkg-valve.cfg`](https://raw.githubusercontent.com/bottlesdevs/build-tools/main/runners/vaniglia/wine-tkg-valve.cfg)
  (staging disabled, GE patches, fsync from Valve's tree, …)
- **Wine source**: Valve's Proton wine tag
  `experimental-wine-bleeding-edge-10.0-272530-20251119-p75f008-w4a5ca6-d392494-vc01c8b`
  (the tag pinned by the soda recipe)
- **Patch set**: `patches/0001..0006-*.mypatch` — giang17's `d2d1-dcomp-11.0` series
  (213 commits, ~16.3k lines) backported from Wine 11.0 to the Valve 10.0 tree, split by
  subsystem:

| Patch | Contents |
|---|---|
| `0001-d2d1-effects-and-rendering` | Direct2D: 11.0-level `dlls/d2d1` + giang17's shader AA, CDT triangulation hardening, stroke fixes, Color Management effect, `ID2D1GradientStopCollection1`, sRGB WIC bitmaps; d2d1 headers |
| `0002-directcomposition` | `dcomp.dll`: `DCompositionCreateDevice{,2,3}`, `IDCompositionDesktopDevice`, `IDCompositionDevice3/4/5`, surfaces, composition/dynamic textures, visual trees, cross-process targets |
| `0003-dwrite-font-fixes` | DirectWrite: rendering-mode-5 fix, `IDWriteFontSet::GetMatchingFonts`, 2B00–2BFF symbol fallback (Serum 2 star ratings) |
| `0004-dxgi-d3d11-composition` | DXGI composition swapchain + DComp popup handling, `ID3D11Fence` (CPU timeline), `WINED3D_BLT_RAW` call-site fixes |
| `0005-wined3d-composition-present` | Composition buffer with dirty-rect accumulation, GL/VK blitter fixes, NVIDIA A10G |
| `0006-win32-x11-windowing` | winex11 DComp window support (offscreen skip, popup types, backing store), win32u transparent-surface init + cursor fixes, ole32 cross-process RevokeDragDrop guard, shell32 VirtualDesktopManager stub, ALSA >32ch guard, ntdll `MADV_FREE` |

The patches are applied as **wine-tkg user patches** (`wine-tkg-userpatches/*.mypatch`),
the same mechanism the official recipe reserves for this.

## Build

### Locally (Debian/Ubuntu-ish hosts)

```bash
./build.sh
```

This clones wine-tkg-git, applies the official soda recipe, drops the patches into
`wine-tkg-userpatches/`, builds (wine-tkg's autoresolver installs the build dependencies
via apt/sudo), and produces `dist/soda-d2d1-10.0-1-x86_64.tar.xz` (~30–60 min, ~4 GB).

### CI

`.github/workflows/build-soda-d2d1.yml` mirrors the official `build-soda.yml` workflow
and publishes the runner tarball as a GitHub release.

## Install into Bottles

```bash
mkdir -p ~/.local/share/bottles/runners
tar -xJf dist/soda-d2d1-10.0-1-x86_64.tar.xz -C ~/.local/share/bottles/runners/
```

Restart Bottles, then select **soda-d2d1-10.0-1** as the runner for the bottle hosting
your plugin host/DAW.

## Notes

- **Don't install DXVK for DComp plugins.** The DComp/DXGI patches live in Wine's
  builtin `dxgi.dll`; DXVK replaces that DLL and silently bypasses them. (From giang17's
  notes: for DComp-based plugins DXVK offers no benefit anyway.)
- **Serum 2 recommended settings**: `"Disable DirectComposition": false`,
  `"Disable Partial Redraw": false`.
- **32-bit**: built with the default soda/tkg settings (wow64), same as stock Soda.
- **de-steamify**: tkg's de-steamify-10.0 hotfix currently fails 2 hunks against this
  bleeding tag (unrelated to the d2d1 series) and is skipped by the build script; the
  runner keeps Proton's inert Steam hooks, which don't affect Bottles usage.
- Known intentional deviations from giang17's branch, due to the 10.0 base:
  - `ID3D11DeviceContext4::Signal/Wait` / `ID3D11Device5::CreateFence/OpenSharedFence`
    are **not** wired up — those COM interfaces don't exist in this tree at all
    (upstream added them after Proton's 10.0 fork). `dlls/d3d11/fence.c` is still built
    and the DXGI/dcomp fence paths are functional; Chromium-style D3DSharedFence usage
    goes through DXGI, which works.
  - `dlls/d2d1/tests/d2d1.c` is kept from the base tree (giang17's test additions need
    the 11.0 test infrastructure); `dlls/shell32/virtualdesktop.c` is shipped as-is
    (inert upstream too: not in shell32's Makefile nor registered in its class factory).
- Verified: the patch set applies cleanly through the real wine-tkg pipeline
  (`patch -Np1`, no fuzz) on top of the pinned tag with the official recipe.

## Credits

- Patch series: **giang17** — [github.com/giang17/wine](https://github.com/giang17/wine)
  (`d2d1-dcomp-11.0` branch)
- Original standalone packaging this is adapted from:
  [mklnln/wine-d2d1-dcomp](https://github.com/mklnln/wine-d2d1-dcomp)
- Runner recipe/build: [bottlesdevs](https://github.com/bottlesdevs),
  [Frogging-Family/wine-tkg-git](https://github.com/Frogging-Family/wine-tkg-git),
  [ValveSoftware/wine](https://github.com/ValveSoftware/wine)

License: LGPL-2.1-or-later, same as Wine.
