# The in-app path: Figma agent chat, Tools panel, code viewer

Figma documents no hand-coding editor and no build-error panel inside the app. In-app authoring is
prompt-driven; code-level control comes through the MCP path. Use this reference when the user
works in the Figma UI, when they ask what a Figma feature does, or when MCP is unavailable.

## Create

- Open **Agents** in the navigation bar, start a chat, and say "Build me a shader" plus the
  description. Without the words "build a shader" the agent may produce a plain image fill.
- Or in the Fill or Effects panel choose "Add shader" / "Create shader with agents".
- Good prompts name the kind (effect or fill), the controls wanted, real-world references ("like a
  risograph print"), and ask to test on a duplicate layer.
- Building and editing consume AI credits; applying does not. Requires edit access and WebGPU
  (not compatibility mode). Available on every plan except K-12 Education.

## Edit

- Describe the change to the agent, or use the Tools panel entry for the shader.
- Versions are created automatically after each edit, with agent-written version descriptions.
  Only the creator can view or restore them.
- Rename: Tools tab, hover, "...", Rename.
- Agent edits regenerate code. They do not promise to preserve comments, control keys, option ids,
  or preset ids. For any shader that has a preset table, a documented uniform layout, or the house
  commenting standard, make edits in source and push through `update_shader` instead.

## View and download code

Tools tab, "...", "View code". Anyone can view and download the code of any shader, including
Figma's. "Download all files" gives `main.ts` and `features.json`. Code cannot be edited there.

## Apply

- Fill: Fill (or Stroke) panel, "Shader fill", pick from "Created by you", library, or Figma's set.
- Effect: Effects panel, "Add effect", "Shader effect". Effects read the layer's current pixels
  as input; fills do not.
- Controls appear in the panel in `defineProperties` order. Spatial controls with
  `mode: "canvas_and_ui"` or `"canvas"` show handles on the canvas.
- A layer on an older version shows an "Update to latest version" control.
- Animated or interactive shaders need Play pressed above the layer, and only one runs per page.
- Shader fills and effects can be saved as styles and published to the team library.

## Motion mode

Individual shader controls can be keyframed. A static shader with a phase control that maps 0..100
to one full period loops seamlessly when keyframed 0 to 100. Keyframing a `preset` select jumps
between looks; keyframing a slider while a preset is active animates nothing, because the preset
replaces the live panel.

## Try-it links

`https://www.figma.com/file/new?try-tool-resource-content-id=<id>&try-tool-resource-type=gen_effect&type=design&mode=design`
(or `gen_fill`) opens a new Design file with the shader ready to try. Append the same two
parameters to a user-supplied file URL to open it there.
