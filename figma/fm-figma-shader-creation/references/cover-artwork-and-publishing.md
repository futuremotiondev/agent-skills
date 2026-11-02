# Cover artwork and publishing

## What is documented, and what is not

An agent cannot set cover artwork. No MCP parameter carries it, and the shader source bundle holds
only `main.ts` and `features.json`. The only documented artwork slots are in two publish modals:

| Channel | Artwork fields | Other fields | Review |
| --- | --- | --- | --- |
| Community ("Publish to Community") | Icon, recommended 128 x 128 px. Thumbnail, an image **or video**, recommended 1920 x 1080 px. Up to nine more images or videos in a carousel | Name, description, category, up to five tags, Animated or Interactive property, publisher identity, contributors, comments toggle, support contact | Yes, "In review" until approved by email; material updates may be re-reviewed |
| Internal ("Publish internally", Organization and Enterprise plans) | Icon, 128 x 128 px | Name, description | No |
| Team library style | None; the style carries the configuration | Style name | Normal library publish |

Not documented anywhere as of 2026-11-02: how the Tools tab and Fill or Effects picker thumbnails
are produced for unpublished shaders, what Figma's default placeholder image is or when it shows,
accepted formats, size limits, crop or letterbox behaviour, GIF support, dark and light variants.
**An unpublished, account-library shader has no documented way to replace Figma's default image.**
Publishing (internally or to Community) is the only documented route to custom artwork.

Verify any claim about picker thumbnails by opening the Tools tab and the publish modal and
screenshotting the actual behaviour before telling a user their default image is replaced.

## Producing the artwork (workflow, inferred from documented pieces)

Figma does not prescribe a workflow. This one uses only documented specs and export features, and an
agent can build and verify everything except the upload.

1. **Frame**: a 1920 x 1080 frame in a Design file (Figma's generic Community guidance also
   recommends simple, eye-catching covers with little text and consistency across your resources).
2. **Effect**: place representative source artwork (photo, type, vector) and apply the shader at its
   defaults or at a hero factory preset. A split before/after reads instantly, though Figma does not
   ask for one. **Fill**: apply the shader fill to the whole frame.
3. Keep the subject centred with generous safe margins, because crop behaviour is undocumented.
4. Export PNG at exactly 1920 x 1080 (`exportAsync` or the Export panel at 1x).
5. **Icon**: a 128 x 128 crop of the shader's visual signature that reads at small size. For internal
   publishing it is the only artwork, so it is probably what the org library shows.
6. **Animated or interactive shaders**: the thumbnail accepts video. Motion exports .mp4, .webp, and
   .gif; a short seamless .mp4 loop is the best-supported choice. Use the keyframable-phase pattern
   to make the loop exact.
7. **Carousel**: one slot per factory preset or parameter variation.
8. The preview must not overstate the shader; the review guideline requires "an accurate description
   and preview so that users will not be surprised by any hidden behavior".
9. A human uploads the files in the publish modal. Hand them the exported paths and the field values.

An agent can do steps 1 to 7 with `use_figma` (build the frame, apply the shader, set a preset by
definition id, `exportAsync`) and `get_screenshot` for a check.

## Publishing steps

- Community: Tools tab, hover the shader, "...", Publish, "Publish to Community". Fill the modal.
  Listing URL: `https://www.figma.com/community/shader/<id>`. Updates go through "Publish changes",
  which also lets you change artwork and listing details. Users cannot revert; rollback means
  republishing an earlier version. Unpublishing removes the shader for installers; deletion is
  irreversible; shaders cannot be monetised.
- Internal: same menu, "Publish internally". Any org member can publish; no review.
- Styles: select a layer with the shader applied, save the fill or effect as a style, publish the
  library. This is the user-preset mechanism.
- MCP-created shaders sit in the same account library under "Created by you", so the same menu
  applies. Figma does not state this explicitly; confirm on first use.

## Review guidelines as a checklist

| Area | Requirement |
| --- | --- |
| Build | No errors or warnings; self-contained; only Figma's shader capabilities |
| Defaults | Suitable output at defaults; defaults are the finished result, never at range edges |
| Controls | Meaningful names; only settings a user would adjust; correct at every value and at extreme combinations |
| Geometry | Scales with the layer (no raw-pixel dependence); works rotated, masked, clipped; respects layer opacity and blend mode |
| Cost | No unbounded or runtime-count loops; no high fixed iteration or texture-sample counts; no dependent reads |
| Testing | Mouse absent, edges, scaled and rotated layers, scrolling frames, multiple instances, long-running animation |
| Listing | Accurate description and preview; significant visual changes ship as a new shader |

Run the geometry and cost rows against every shader, published or not; they are the difference
between a shader that works on one test image and one that works on a client's board.
