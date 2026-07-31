# soda-d2d1 — Soda (Bottles) Wine runner with Direct2D 1.3 + DirectComposition patches

A Bottles **Soda**-flavored Wine runner (same base as upstream **Soda 11.0-2**) with
[giang17](https://github.com/giang17/wine)'s `d2d1-dcomp-11.0` patch series applied.
It fixes JUCE 8 / VSTGUI / SynthEdit audio-plugin GUIs rendering as **black windows**
under Wine (Pianoteq 9, Serum 2, Korg Trinity/Prophecy, EZkeys 2, Garritan CFX, …).

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
  `experimental-wine-bleeding-edge-11.0-406792-20260730-p6ed41e-w6eabc7-d6227b6-v651f17`
  (the tag pinned by the current soda recipe, same as upstream **Soda 11.0-2**)
- **Patch set**: `patches/0001..0006-*.mypatch` — giang17's `d2d1-dcomp-11.0` series
  (213 commits, ~14k lines) rebased onto the Valve 11.0 tree. Since giang17's branch
  targets Wine 11.0, this base needs almost no backporting — only 5 small conflicts
  where Valve's Proton patches overlap the series. Split by subsystem:

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

## Provenance (pinned versions this adaptation was made and verified against)

Upstream recipes and wine-tkg are moving targets fetched from `main`/HEAD at build
time; these are the exact commits used:

| Component | Pin |
|---|---|
| Patch series | [giang17/wine](https://github.com/giang17/wine) branch `d2d1-dcomp-11.0` @ `aa0abd18c084b2a0e78c70a8ba30389f49051a01` (213 commits on Wine 11.0) |
| Wine source | [ValveSoftware/wine](https://github.com/ValveSoftware/wine) tag `experimental-wine-bleeding-edge-11.0-406792-20260730-p6ed41e-w6eabc7-d6227b6-v651f17` = commit `6eabc775098aad00a293cb39772232560ea39d14` |
| Soda recipe | [bottlesdevs/build-tools](https://github.com/bottlesdevs/build-tools) `runners/vaniglia/wine-tkg-valve.cfg` @ `fcba104217` ("update Soda recipe to Wine 11", 2026-07-31) |
| wine-tkg-git | [Frogging-Family/wine-tkg-git](https://github.com/Frogging-Family/wine-tkg-git) @ `6e1c41342a249e0029c1f35f36775e1caa5ce1d1` (2026-07-13) |
| Matching upstream release | [bottlesdevs/wine](https://github.com/bottlesdevs/wine) tag `soda-11.0-2` (2026-07-31) |

For bit-exact reproducibility, check out these commits instead of `main`/HEAD in
`build.sh` / the workflow (both intentionally track upstream like the official build).
Note: the recipe's `_bleeding_tag` is reset by the tkg profile load order, so
`build.sh` pins the tag in the tkg profile file directly (see comments in `build.sh`).

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
tar -xJf dist/soda-d2d1-11.0-2-x86_64.tar.xz -C ~/.local/share/bottles/runners/
```

Restart Bottles, then select **soda-d2d1-11.0-2** as the runner for the bottle hosting
your plugin host/DAW.

## Notes

- **Don't install DXVK for DComp plugins.** The DComp/DXGI patches live in Wine's
  builtin `dxgi.dll`; DXVK replaces that DLL and silently bypasses them. (From giang17's
  notes: for DComp-based plugins DXVK offers no benefit anyway.)
- **Serum 2 recommended settings**: `"Disable DirectComposition": false`,
  `"Disable Partial Redraw": false`.
- **32-bit**: built with the default soda/tkg settings (wow64), same as stock Soda.
- **Full feature parity with giang17's branch on this base**: the 11.0-based Soda
  includes upstream `ID3D11Device5`/`ID3D11DeviceContext4`, so the D3D11 fence
  implementation is fully wired, and giang17's d2d1 test additions are included.
  (The former 10.0-based adaptation had to drop both.)
- One deliberate deviation from giang17's tree: `WINED3D_SWAPCHAIN_FORCE_GDI_PRESENT`
  is `0x01000000u` here instead of `0x00200000u`, which collides with Valve's
  `WINED3D_SWAPCHAIN_ALLOW_MS_LOCKABLE_BACKBUFFER` hack (all uses are symbolic).
- **de-steamify**: tkg ships no de-steamify patch for Wine 11 yet; its hotfixer just
  warns and skips it (same as the official Soda 11.0-2 build). The runner keeps
  Proton's inert Steam hooks, which don't affect Bottles usage.
- **warframe-launcher tkg patch** fails against this bleeding tag (tkg-side, also in
  the official build; it is applied in a subshell so the build continues, and no hunks
  landed — the tree is unaffected).
- `dlls/shell32/virtualdesktop.c` is shipped as-is (inert upstream too: not in
  shell32's Makefile nor registered in its class factory).
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
- Backport of the patch series to the Soda base, patch split, and build tooling:
  **Kimi K3** (Moonshot AI)

License: LGPL-2.1-or-later, same as Wine.
