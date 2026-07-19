# Tucked App Icon Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the current literal bookmark icon with the approved opaque, full-bleed Dusk Candy “Pocket Portal” icon for Tucked.

**Architecture:** Keep one editable SVG master and one canonical 1024-by-1024 RGB PNG in `design/`. Derive every existing asset-catalog PNG from that canonical raster so all platform sizes share identical artwork and remain opaque; keep `Contents.json` and the Xcode project unchanged.

**Tech Stack:** SVG, macOS Quick Look rendering, `ffmpeg`, `sips`, Xcode asset catalogs, `xcodebuild`

## Global Constraints

- The icon concept is a slightly tilted five-point star, with two eyes and no mouth or limbs, peeking from behind a soft pocket that occludes roughly its lower third.
- Use the approved Dusk Candy relationship: deep violet background, coral pocket, warm yellow star, and darker violet eyes.
- Rendering is softly dimensional and tactile; do not add glass, chrome, heavy gloss, photorealism, text, or decorative sparkles.
- Every delivered PNG is an opaque, full-bleed square with no alpha channel, baked-in rounded corners, rounded-rectangle frame, corner transparency, or platform mask.
- Do not rename Xcode targets, folders, bundle identifiers, namespaces, or the existing asset-catalog PNG filenames.
- Do not add dependencies or edit `BookmarkCollections.xcodeproj/project.pbxproj`.

---

## File Map

- Create `design/Tucked-master.svg`: editable 1024-by-1024 vector source for the approved icon.
- Create `design/Tucked-AppIcon-1024.png`: canonical opaque RGB render used for visual review and all derived sizes.
- Modify `BookmarkCollections/Assets.xcassets/AppIcon.appiconset/AppIcon-*.png`: replace the 19 existing raster files in place without changing filenames.
- Modify `CHANGELOG.md`: record the user-visible icon rebrand under 1.0.0.

### Task 1: Produce the approved master artwork

**Files:**

- Create: `design/Tucked-master.svg`
- Create: `design/Tucked-AppIcon-1024.png`

**Interfaces:**

- Consumes: the approved design in `docs/superpowers/specs/2026-07-19-tucked-app-icon-design.md`.
- Produces: a complete `1024 × 1024` SVG master and an opaque RGB `1024 × 1024` PNG at `design/Tucked-AppIcon-1024.png`.

- [ ] **Step 1: Create the vector master**

Use `apply_patch` to create `design/Tucked-master.svg` with this complete content:

```svg
<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
  <defs>
    <linearGradient id="background" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#8068F2"/>
      <stop offset="0.52" stop-color="#5A3AB7"/>
      <stop offset="1" stop-color="#352071"/>
    </linearGradient>
    <radialGradient id="backgroundGlow" cx="50%" cy="20%" r="72%">
      <stop offset="0" stop-color="#A995FF" stop-opacity="0.34"/>
      <stop offset="1" stop-color="#A995FF" stop-opacity="0"/>
    </radialGradient>
    <linearGradient id="star" x1="0.12" y1="0.05" x2="0.82" y2="0.92">
      <stop offset="0" stop-color="#FFF8B8"/>
      <stop offset="0.55" stop-color="#FFE77A"/>
      <stop offset="1" stop-color="#F7C84C"/>
    </linearGradient>
    <linearGradient id="pocket" x1="0.18" y1="0" x2="0.82" y2="1">
      <stop offset="0" stop-color="#FFB46F"/>
      <stop offset="0.48" stop-color="#FF7A78"/>
      <stop offset="1" stop-color="#EF4D72"/>
    </linearGradient>
    <linearGradient id="pocketLip" x1="0" y1="0" x2="1" y2="0">
      <stop offset="0" stop-color="#FFD2AA"/>
      <stop offset="0.5" stop-color="#FFE0BB"/>
      <stop offset="1" stop-color="#FFB58E"/>
    </linearGradient>
    <filter id="starShadow" x="-35%" y="-35%" width="170%" height="185%">
      <feDropShadow dx="0" dy="22" stdDeviation="24" flood-color="#28134F" flood-opacity="0.32"/>
    </filter>
    <filter id="pocketShadow" x="-25%" y="-30%" width="150%" height="175%">
      <feDropShadow dx="0" dy="24" stdDeviation="25" flood-color="#28134F" flood-opacity="0.34"/>
    </filter>
  </defs>

  <rect width="1024" height="1024" fill="url(#background)"/>
  <rect width="1024" height="1024" fill="url(#backgroundGlow)"/>

  <g transform="translate(16 -10) rotate(12 512 456)" filter="url(#starShadow)">
    <path d="M512 172 L566 334 L737 339 L601 441 L648 606 L512 512 L376 606 L423 441 L287 339 L458 334 Z" fill="url(#star)"/>
    <ellipse cx="454" cy="397" rx="17" ry="21" fill="#55358E"/>
    <ellipse cx="562" cy="383" rx="17" ry="21" fill="#55358E"/>
    <circle cx="449" cy="391" r="5" fill="#FFFFFF" opacity="0.72"/>
    <circle cx="557" cy="377" r="5" fill="#FFFFFF" opacity="0.72"/>
  </g>

  <g filter="url(#pocketShadow)">
    <path d="M226 430 Q512 576 798 430 L753 786 Q512 894 271 786 Z" fill="url(#pocket)"/>
    <path d="M226 430 Q512 576 798 430" fill="none" stroke="url(#pocketLip)" stroke-width="30" stroke-linecap="round"/>
    <path d="M289 499 Q512 603 735 499" fill="none" stroke="#D93667" stroke-width="12" stroke-linecap="round" opacity="0.24"/>
    <path d="M310 742 Q512 826 714 742" fill="none" stroke="#FFB08D" stroke-width="18" stroke-linecap="round" opacity="0.22"/>
  </g>
</svg>
```

- [ ] **Step 2: Render a temporary 1024-pixel preview**

Run:

```bash
icon_render_dir=$(mktemp -d)
qlmanage -t -s 1024 -o "$icon_render_dir" design/Tucked-master.svg
test -f "$icon_render_dir/Tucked-master.svg.png"
```

Expected: Quick Look reports thumbnail generation and the `test` command exits `0`.

- [ ] **Step 3: Force the canonical PNG to opaque RGB**

Run:

```bash
/opt/homebrew/bin/ffmpeg -loglevel error -y \
  -i "$icon_render_dir/Tucked-master.svg.png" \
  -pix_fmt rgb24 design/Tucked-AppIcon-1024.png
sips -g pixelWidth -g pixelHeight -g hasAlpha \
  design/Tucked-AppIcon-1024.png
```

Expected:

```text
pixelWidth: 1024
pixelHeight: 1024
hasAlpha: no
```

- [ ] **Step 4: Review the full-size master and smallest-size proof**

Run:

```bash
sips -z 16 16 design/Tucked-AppIcon-1024.png \
  --out "$icon_render_dir/Tucked-AppIcon-16.png"
```

Open both PNGs with the local image viewer. Confirm the background reaches all four square corners, the pocket visibly sits in front of the lower star, the star has two readable eyes and no mouth, and the combined silhouette remains recognizable at 16 pixels. If the 16-pixel eyes merge or disappear, increase each SVG eye ellipse to at most `rx="20" ry="24"`, rerender, and repeat this step.

- [ ] **Step 5: Commit the approved master and canonical render**

```bash
git add design/Tucked-master.svg design/Tucked-AppIcon-1024.png
git commit -m "design: add Tucked app icon master"
```

### Task 2: Export and validate the asset catalog

**Files:**

- Modify: `BookmarkCollections/Assets.xcassets/AppIcon.appiconset/AppIcon-16.png`
- Modify: `BookmarkCollections/Assets.xcassets/AppIcon.appiconset/AppIcon-20.png`
- Modify: `BookmarkCollections/Assets.xcassets/AppIcon.appiconset/AppIcon-29.png`
- Modify: `BookmarkCollections/Assets.xcassets/AppIcon.appiconset/AppIcon-32.png`
- Modify: `BookmarkCollections/Assets.xcassets/AppIcon.appiconset/AppIcon-40.png`
- Modify: `BookmarkCollections/Assets.xcassets/AppIcon.appiconset/AppIcon-58.png`
- Modify: `BookmarkCollections/Assets.xcassets/AppIcon.appiconset/AppIcon-60.png`
- Modify: `BookmarkCollections/Assets.xcassets/AppIcon.appiconset/AppIcon-64.png`
- Modify: `BookmarkCollections/Assets.xcassets/AppIcon.appiconset/AppIcon-76.png`
- Modify: `BookmarkCollections/Assets.xcassets/AppIcon.appiconset/AppIcon-80.png`
- Modify: `BookmarkCollections/Assets.xcassets/AppIcon.appiconset/AppIcon-87.png`
- Modify: `BookmarkCollections/Assets.xcassets/AppIcon.appiconset/AppIcon-120.png`
- Modify: `BookmarkCollections/Assets.xcassets/AppIcon.appiconset/AppIcon-128.png`
- Modify: `BookmarkCollections/Assets.xcassets/AppIcon.appiconset/AppIcon-152.png`
- Modify: `BookmarkCollections/Assets.xcassets/AppIcon.appiconset/AppIcon-167.png`
- Modify: `BookmarkCollections/Assets.xcassets/AppIcon.appiconset/AppIcon-180.png`
- Modify: `BookmarkCollections/Assets.xcassets/AppIcon.appiconset/AppIcon-256.png`
- Modify: `BookmarkCollections/Assets.xcassets/AppIcon.appiconset/AppIcon-512.png`
- Modify: `BookmarkCollections/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`
- Modify: `CHANGELOG.md`

**Interfaces:**

- Consumes: opaque `design/Tucked-AppIcon-1024.png` from Task 1 and the existing filenames in `AppIcon.appiconset/Contents.json`.
- Produces: 19 opaque RGB icon PNGs with the exact existing filenames and dimensions; `Contents.json` remains byte-for-byte unchanged.

- [ ] **Step 1: Capture the catalog manifest before replacing images**

Run:

```bash
shasum BookmarkCollections/Assets.xcassets/AppIcon.appiconset/Contents.json \
  > /tmp/tucked-appicon-contents-before.sha
```

Expected: `/tmp/tucked-appicon-contents-before.sha` contains one SHA-1 record.

- [ ] **Step 2: Derive every required asset from the canonical RGB PNG**

Run:

```bash
icon_set=BookmarkCollections/Assets.xcassets/AppIcon.appiconset
for size in 16 20 29 32 40 58 60 64 76 80 87 120 128 152 167 180 256 512 1024; do
  sips -z "$size" "$size" design/Tucked-AppIcon-1024.png \
    --out "$icon_set/AppIcon-$size.png"
done
```

Expected: `sips` reports one output path for each of the 19 declared sizes.

- [ ] **Step 3: Verify exact dimensions and absence of alpha**

Run:

```bash
icon_set=BookmarkCollections/Assets.xcassets/AppIcon.appiconset
failed=0
for size in 16 20 29 32 40 58 60 64 76 80 87 120 128 152 167 180 256 512 1024; do
  file="$icon_set/AppIcon-$size.png"
  width=$(sips -g pixelWidth "$file" | awk '/pixelWidth/ {print $2}')
  height=$(sips -g pixelHeight "$file" | awk '/pixelHeight/ {print $2}')
  alpha=$(sips -g hasAlpha "$file" | awk '/hasAlpha/ {print $2}')
  if [[ "$width" != "$size" || "$height" != "$size" || "$alpha" != "no" ]]; then
    echo "FAIL $file: ${width}x${height}, alpha=$alpha"
    failed=1
  fi
done
exit "$failed"
```

Expected: no output and exit status `0`.

- [ ] **Step 4: Verify the asset manifest did not change**

Run:

```bash
shasum -c /tmp/tucked-appicon-contents-before.sha
git diff --exit-code -- \
  BookmarkCollections/Assets.xcassets/AppIcon.appiconset/Contents.json \
  BookmarkCollections.xcodeproj/project.pbxproj
```

Expected: `Contents.json: OK`; both `git diff` checks exit `0`.

- [ ] **Step 5: Record the icon change**

Use `apply_patch` to add this bullet to `CHANGELOG.md` under `## 1.0.0 — Unreleased` → `### Added`:

```markdown
- New Tucked app icon: a curious star peeking from a pocket in the Dusk Candy palette.
```

- [ ] **Step 6: Build the asset catalog in the app target**

Run:

```bash
xcodebuild build \
  -project BookmarkCollections.xcodeproj \
  -scheme BookmarkCollections \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO
```

Expected: `** BUILD SUCCEEDED **` with no AppIcon, alpha-channel, or asset-catalog warnings.

- [ ] **Step 7: Review the final diff and visual outputs**

Run:

```bash
git diff --check
git status --short
```

Open `AppIcon-16.png`, `AppIcon-60.png`, `AppIcon-180.png`, and `AppIcon-1024.png` with the local image viewer. Confirm full-bleed square backgrounds, consistent pocket/star occlusion, readable eyes where resolution permits, and no baked platform mask.

Expected status: the 19 catalog PNGs and `CHANGELOG.md` are modified; no project file, `Contents.json`, or unrelated source is modified.

- [ ] **Step 8: Commit the exported catalog**

```bash
git add CHANGELOG.md BookmarkCollections/Assets.xcassets/AppIcon.appiconset/AppIcon-*.png
git commit -m "design: install Tucked app icon"
```
