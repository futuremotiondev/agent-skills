# Preset JSON Schema

The exact JSON the plugin's **Paste Preset** accepts (AI Autotagger 11, schema version 5). Emit
this shape and nothing else. Behavior notes live in [plugin-internals.md](plugin-internals.md).

## Skeleton

```json
{
  "name": "Preset Name",
  "globalInstructions": "Role, purpose, file-name hint, shared rules…",
  "rules": [
    {
      "type": "description",
      "name": "Summary",
      "instruction": "Summary: …",
      "includeNameAsTitle": true,
      "replaceExisting": false
    },
    {
      "type": "tags",
      "name": "Color Scheme",
      "instruction": "Color Scheme: … Return exactly one tag.",
      "tagsType": "specific",
      "tagsList": ["Light", "Dark", "Both"],
      "tagModifier": { "position": "prefix", "text": "Color Scheme", "useSpace": true }
    },
    {
      "type": "tags",
      "name": "Brand",
      "instruction": "Brand: … Return an empty list if unknown.",
      "tagsType": "none",
      "tagsList": [],
      "tagModifier": { "position": "prefix", "text": "Brand", "useSpace": true }
    },
    {
      "type": "name",
      "name": "Name",
      "instruction": "Name: …"
    }
  ],
  "skipRule": { "tag": "Processed with AI Autotagger: Preset Name", "shouldAddOnSkip": true },
  "version": 5
}
```

## Preset fields

| Field                | Type    | Required | Notes                                                                                                |
| -------------------- | ------- | -------- | ---------------------------------------------------------------------------------------------------- |
| `name`               | string  | yes      | Shown only in the plugin; defaults to "Imported Preset". Not sent to the model.                      |
| `globalInstructions` | string  | yes      | First part of the system prompt. Supports `<NAME>` and `<DESCRIPTION>`. Omitted for local providers. |
| `rules`              | array   | yes      | 1–100 rules. Order = prompt order = JSON output order = description section order.                   |
| `skipRule`           | object  | no       | `{ "tag": string, "shouldAddOnSkip": boolean }`. Import adds a default if missing.                   |
| `version`            | integer | yes      | Emit `5`. Higher values are rejected; lower values are migrated.                                     |

Never emit `id`, `createdAt`, `updatedAt`, or `folderId`; the plugin generates them.

## Rule fields

| Field                | Rule types  | Type    | Values / notes                                                                            |
| -------------------- | ----------- | ------- | ----------------------------------------------------------------------------------------- |
| `type`               | all         | string  | `"description"`, `"tags"`, `"name"`                                                       |
| `name`               | all         | string  | Unique; 1–2 words ideal. Becomes the JSON key (snake_case) and the description header.    |
| `instruction`        | all         | string  | Starts with `Name:`. One paragraph. See [instruction-writing.md](instruction-writing.md). |
| `includeNameAsTitle` | description | boolean | Default `true`. Prepends `# Name` to the text in Eagle.                                   |
| `replaceExisting`    | description | boolean | Default `false`. `true` wipes the whole description at that point.                        |
| `tagsType`           | tags        | string  | `"example"` (suggestions), `"specific"` (closed enum), `"none"` (open, no list).          |
| `tagsList`           | tags        | array   | Strings. Required non-empty for example/specific; `[]` for none. No commas in a tag.      |
| `tagModifier`        | tags        | object  | Optional. `{ "position": "prefix" or "suffix", "text": string, "useSpace": boolean }`.    |

UI label mapping for manual entry: `tagsType` example/specific/none = Tags Type
Example/Specific/N/A; `tagModifier.position` = Modifier Position; `tagModifier.text` = Modifier
Text; `tagModifier.useSpace` = Include Space.

Legacy fields the importer still understands but you should not emit: `tagPrefix` (string,
becomes a Prefix modifier with a space) and `dependsOnRuleIds` (validated, currently unused).

## Formatting conventions for delivered files

- File name: `<preset-name-in-kebab-case>.preset.json`, for example `ui-design-v2.preset.json`.
- 2-space indentation, UTF-8, real characters (no `\u` escapes for “ ” – —), trailing newline.
- Key order: `name`, `globalInstructions`, `rules`, `skipRule`, `version`; within rules: `type`,
  `name`, `instruction`, then type-specific fields.
- Short arrays may sit on one line; long tag lists may wrap.
- Run `python scripts/validate_preset.py <file>` and fix every ERROR before delivering.

## Normalizing a preset the user pasted

Presets copied from the plugin or restored from a backup may carry ids, timestamps, legacy
fields, whitespace, or duplicate tags. Clean them before editing:

```bash
python scripts/validate_preset.py pasted.json --normalize clean.preset.json
```

Backups shaped like `{"presets": [...]}` or plain arrays are accepted; each preset is validated
separately.
