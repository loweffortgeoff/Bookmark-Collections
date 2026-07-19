# Tucked App Icon Design

**Date:** 2026-07-19
**Status:** Approved

## Objective

Replace the current literal bookmark icon with a distinctive mark for the
official product name, **Tucked: Stuff for Whenever**. The new icon should feel
clever and playful while expressing the idea that interesting things are
waiting to be rediscovered.

This work changes the app icon artwork only. It does not rename Xcode targets,
folders, bundle identifiers, or other internal `BookmarkCollections` names.

## Approved Concept: Pocket Portal

A warm five-point star peeks out from behind a soft pocket. The pocket visibly
occludes roughly the lower third of the star so the central idea is communicated
through the overlap: the saved thing has been tucked away and is now reappearing.

The star tilts slightly to give the composition a curious, playful gesture. Two
small eyes add personality, but the star has no mouth, limbs, or other mascot
features. The result should remain a compact symbol rather than character art.

The star and pocket form one centered silhouette with generous clearance from
the canvas edges. No bookmark, link, browser, filing, or letterform imagery is
included; the app name is allowed to explain the product category.

## Color and Finish

The approved **Dusk Candy** palette uses:

- a deep violet background;
- a coral pocket;
- a warm yellow star;
- darker violet eyes that remain visible against the star.

The rendering is softly dimensional and tactile, using restrained gradients,
shallow depth, and subtle highlights. It must avoid glass, chrome, heavy gloss,
photorealism, text, and decorative sparkles that compete with the silhouette.

Exact color stops, highlight intensity, and shadow values may be tuned during
production to preserve contrast and legibility, but the approved violet/coral/
yellow color relationship must remain intact.

## Deliverables

- A vector-based 1024-by-1024 master in the existing `design/` directory.
- A rendered 1024-by-1024 source preview beside the master.
- All PNG sizes referenced by the existing
  `BookmarkCollections/Assets.xcassets/AppIcon.appiconset/Contents.json`.
- No Xcode project-file changes unless asset catalog validation proves they are
  required.

The implementation should replace the current app icon assets in place while
retaining the current filenames and asset-catalog structure. The existing
`Bookmarx`-named design masters may be replaced or supplemented by clearly named
`Tucked` masters; no broader internal project rename is part of this work.

## Validation

The finished icon must:

- preserve the pocket-in-front occlusion at every exported size;
- keep the star's eyes readable without becoming visual noise;
- retain a recognizable silhouette at 16, 32, 60, and 180 points;
- remain distinguishable in grayscale and against light and dark desktop
  contexts;
- contain no unintended transparency or baked-in text;
- match every filename, pixel dimension, idiom, and scale declared by the
  existing asset catalog;
- pass asset-catalog/build validation for the app target.

At the smallest sizes, implementation may simplify highlights and eye geometry
if needed, but it must not change the approved metaphor, composition, or palette.

## Out of Scope

- Product-name or tagline changes.
- Xcode target, bundle identifier, folder, or namespace renames.
- A full visual identity, wordmark, launch screen, or in-app theme redesign.
- New dependencies or non-system rendering frameworks.
