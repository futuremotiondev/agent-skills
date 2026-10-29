# Design Tokens Reference

Companion to the fm-product-design skill for the Design Tokens and Design System modes. It defines the tier model, naming, value formats, the dark-mode method, the contrast table, platform export rules, and a complete example whose numbers were computed from its own values.

## Tier model

| Tier      | Purpose                                                             | Example                                                            | Who consumes it                          |
| --------- | ------------------------------------------------------------------- | ------------------------------------------------------------------ | ---------------------------------------- |
| Primitive | Raw values with no meaning: color scales, type scale, spacing scale | `color.gray.900`, `space.4`, `font.size.md`                        | Semantic tokens only                     |
| Semantic  | Roles that describe intent                                          | `color.text.primary`, `color.surface.raised`, `color.border.focus` | Components and layouts                   |
| Component | Bindings for one part of one component                              | `button.primary.bg`, `input.border-error`                          | That component's code and Figma variants |

Rules:

- Components reference semantic or component tokens; a primitive in component code is a defect.
- Add a component token only when a real component needs a value that differs from the semantic default. Keep the tier small.
- Every semantic token that can differ by mode declares its dark value. A missing dark value falls back to light and is listed as a known gap.

## Naming

Pattern: `category.role.variant.state`, lowercase, dot-separated, kebab-case inside a segment.

| Category      | Roles                                                                               | Variants and states         |
| ------------- | ----------------------------------------------------------------------------------- | --------------------------- |
| color.text    | primary, secondary, tertiary, disabled, link, on-action                             | hover, active               |
| color.surface | default, subtle, raised, overlay                                                    |                             |
| color.border  | subtle, default, focus, error                                                       |                             |
| color.action  | primary, secondary, danger                                                          | bg, hover, active, disabled |
| color.status  | error, success, warning, info                                                       | fg, bg, border              |
| font          | family, size, weight, line-height, letter-spacing                                   |                             |
| space         | 0 to 24 on a 4 px grid                                                              |                             |
| radius        | none, sm, md, lg, xl, full                                                          |                             |
| shadow        | sm, md, lg, xl                                                                      | web, ios, android           |
| motion        | duration.fast, duration.normal, duration.slow; easing.enter, exit, standard, spring |                             |

## Value format

- Store dimensions and durations as unitless numbers (`16`, `250`) whenever a native app consumes the tokens; the export layer adds `px`, `rem`, `pt`, or `ms`.
- Store easing as a cubic-bezier array such as `[0.4, 0, 0.2, 1]`; export to CSS strings or platform easing objects.
- Store shadows per platform: a CSS string for the web; `shadowColor`, `shadowOffset`, `shadowOpacity`, and `shadowRadius` for iOS; `elevation` for Android.
- Use the W3C Design Tokens Community Group shape (`$type`, `$value`, references in braces) so Style Dictionary, Tokens Studio, and Figma variable importers can read the file.
- Put mode overrides in `$extensions.mode.dark` beside the light value, or in separate mode files that override the same paths. Pick one approach and keep it.
- Disabled text and disabled controls are exempt from WCAG contrast minimums (1.4.3, inactive components); say so in the deliverable instead of inflating their contrast.

## Dark mode method

Dark mode is a second semantic mapping, never an inversion.

1. Surfaces get lighter as elevation rises (default 950, subtle 900, raised 800); shadows shrink and lighter tints do the lifting.
2. Text is off-white (gray.50), not pure white, to reduce halation.
3. Brand and status colors move one or two steps lighter and slightly less saturated so they hold 4.5:1 on dark surfaces.
4. Borders step up one or two shades because dark backgrounds swallow contrast.
5. Recompute every pair; dark mode gets its own column in the contrast table.

## Deriving a brand ramp from one hex

Most requests supply a single brand color. Build the ramp before mapping semantics:

1. Place the given hex at the step whose lightness it matches (a mid-saturation blue usually lands at 500 or 600); keep it exact, since it is the only real constraint.
2. Generate the other steps by stepping lightness at roughly even intervals in a perceptual space (OKLCH or LCH) when tooling allows; plain HSL stepping is acceptable for a first draft if it is labeled as such.
3. Desaturate the two lightest and two darkest steps by 10 to 15 percent so they do not turn neon or muddy.
4. Verify the anchors with the contrast script: the light-mode action step (usually 600) needs 4.5:1 with white text, the dark-mode action step (usually 400) needs 4.5:1 with the dark surface, and the focus step needs 3:1 on both surfaces.
5. Record the ramp as a first draft in "Known gaps" until a designer has reviewed it on real screens.

## Contrast table

Required with every token deliverable. These values were computed from the example below with the skill's contrast script; recompute whenever a hex value changes.

| Pair                                        | Light  | Dark   | Requirement | Note            |
| ------------------------------------------- | ------ | ------ | ----------- | --------------- |
| `text.primary` on `surface.default`         | 17.7:1 | 19.3:1 | 4.5:1       |                 |
| `text.secondary` on `surface.default`       | 7.6:1  | 13.7:1 | 4.5:1       |                 |
| `text.tertiary` on `surface.default`        | 4.8:1  | 7.9:1  | 4.5:1       |                 |
| `text.primary` on `surface.subtle`          | 17.0:1 | 17.0:1 | 4.5:1       |                 |
| `text.secondary` on `surface.subtle`        | 7.2:1  | 12.0:1 | 4.5:1       |                 |
| `text.primary` on `surface.raised`          | 17.7:1 | 14.0:1 | 4.5:1       |                 |
| `text.secondary` on `surface.raised`        | 7.6:1  | 10.0:1 | 4.5:1       |                 |
| `text.link` on `surface.default`            | 6.6:1  | 6.2:1  | 4.5:1       |                 |
| `text.on-action` on `action.primary.bg`     | 6.6:1  | 6.2:1  | 4.5:1       |                 |
| `text.on-action` on `action.primary.hover`  | 9.1:1  | 9.3:1  | 4.5:1       |                 |
| `text.on-action` on `action.primary.active` | 11.7:1 | 12.4:1 | 4.5:1       |                 |
| `action.primary.bg` on `surface.default`    | 6.6:1  | 6.2:1  | 3.0:1       | button boundary |
| `border.default` on `surface.default`       | 4.8:1  | 7.9:1  | 3.0:1       | input boundary  |
| `border.focus` on `surface.default`         | 4.7:1  | 6.2:1  | 3.0:1       | focus ring      |
| `border.error` on `surface.default`         | 4.8:1  | 7.3:1  | 3.0:1       | error boundary  |
| `status.error.fg` on `surface.default`      | 6.5:1  | 7.3:1  | 4.5:1       |                 |
| `status.error.fg` on `status.error.bg`      | 5.9:1  | 5.8:1  | 4.5:1       |                 |
| `status.success.fg` on `surface.default`    | 5.0:1  | 11.6:1 | 4.5:1       |                 |
| `status.success.fg` on `status.success.bg`  | 4.8:1  | 8.6:1  | 4.5:1       |                 |
| `status.warning.fg` on `surface.default`    | 5.0:1  | 12.1:1 | 4.5:1       |                 |
| `status.warning.fg` on `status.warning.bg`  | 4.8:1  | 9.0:1  | 4.5:1       |                 |
| `status.info.fg` on `surface.default`       | 6.6:1  | 6.2:1  | 4.5:1       |                 |
| `status.info.fg` on `status.info.bg`        | 6.0:1  | 5.3:1  | 4.5:1       |                 |

`text.disabled` (gray.400 light, gray.600 dark) is exempt as an inactive state and is not listed.

## Complete example

Primitives, semantic tokens with light and dark modes, typography, spacing, radius, per-platform shadows, motion, and a small component tier. What is reusable and what is a placeholder:

- Reusable defaults: the gray, red, green, and amber ramps, the semantic role names and their light and dark mappings, the type scale, spacing, radius, shadows, and motion. Adopt them as they are unless the product already has equivalents.
- Placeholder: the `brand` ramp. Replace it with the product's own scale (see "Deriving a brand ramp from one hex"), then rerun the contrast check for every pair that references it.

```json
{
  "color": {
    "white": {
      "$type": "color",
      "$value": "#FFFFFF"
    },
    "black": {
      "$type": "color",
      "$value": "#000000"
    },
    "gray": {
      "50": {
        "$type": "color",
        "$value": "#F9FAFB"
      },
      "100": {
        "$type": "color",
        "$value": "#F3F4F6"
      },
      "200": {
        "$type": "color",
        "$value": "#E5E7EB"
      },
      "300": {
        "$type": "color",
        "$value": "#D1D5DB"
      },
      "400": {
        "$type": "color",
        "$value": "#9CA3AF"
      },
      "500": {
        "$type": "color",
        "$value": "#6B7280"
      },
      "600": {
        "$type": "color",
        "$value": "#4B5563"
      },
      "700": {
        "$type": "color",
        "$value": "#374151"
      },
      "800": {
        "$type": "color",
        "$value": "#1F2937"
      },
      "900": {
        "$type": "color",
        "$value": "#111827"
      },
      "950": {
        "$type": "color",
        "$value": "#030712"
      }
    },
    "brand": {
      "50": {
        "$type": "color",
        "$value": "#EEF4FF"
      },
      "100": {
        "$type": "color",
        "$value": "#D9E5FF"
      },
      "200": {
        "$type": "color",
        "$value": "#B3CBFF"
      },
      "300": {
        "$type": "color",
        "$value": "#8FB0F4"
      },
      "400": {
        "$type": "color",
        "$value": "#5B8DEF"
      },
      "500": {
        "$type": "color",
        "$value": "#2F6FE4"
      },
      "600": {
        "$type": "color",
        "$value": "#1F56C4"
      },
      "700": {
        "$type": "color",
        "$value": "#17439B"
      },
      "800": {
        "$type": "color",
        "$value": "#123478"
      },
      "900": {
        "$type": "color",
        "$value": "#0E2757"
      }
    },
    "red": {
      "50": {
        "$type": "color",
        "$value": "#FEF2F2"
      },
      "300": {
        "$type": "color",
        "$value": "#FCA5A5"
      },
      "400": {
        "$type": "color",
        "$value": "#F87171"
      },
      "600": {
        "$type": "color",
        "$value": "#DC2626"
      },
      "700": {
        "$type": "color",
        "$value": "#B91C1C"
      },
      "800": {
        "$type": "color",
        "$value": "#991B1B"
      },
      "950": {
        "$type": "color",
        "$value": "#450A0A"
      }
    },
    "green": {
      "50": {
        "$type": "color",
        "$value": "#F0FDF4"
      },
      "300": {
        "$type": "color",
        "$value": "#86EFAC"
      },
      "400": {
        "$type": "color",
        "$value": "#4ADE80"
      },
      "700": {
        "$type": "color",
        "$value": "#15803D"
      },
      "800": {
        "$type": "color",
        "$value": "#166534"
      },
      "950": {
        "$type": "color",
        "$value": "#052E16"
      }
    },
    "amber": {
      "50": {
        "$type": "color",
        "$value": "#FFFBEB"
      },
      "300": {
        "$type": "color",
        "$value": "#FCD34D"
      },
      "400": {
        "$type": "color",
        "$value": "#FBBF24"
      },
      "700": {
        "$type": "color",
        "$value": "#B45309"
      },
      "800": {
        "$type": "color",
        "$value": "#92400E"
      },
      "950": {
        "$type": "color",
        "$value": "#451A03"
      }
    },
    "navy": {
      "950": {
        "$type": "color",
        "$value": "#0B1A3A"
      }
    }
  },
  "semantic": {
    "color": {
      "surface": {
        "default": {
          "$type": "color",
          "$value": "{color.white}",
          "$extensions": {
            "mode": {
              "dark": "{color.gray.950}"
            }
          }
        },
        "subtle": {
          "$type": "color",
          "$value": "{color.gray.50}",
          "$extensions": {
            "mode": {
              "dark": "{color.gray.900}"
            }
          }
        },
        "raised": {
          "$type": "color",
          "$value": "{color.white}",
          "$extensions": {
            "mode": {
              "dark": "{color.gray.800}"
            }
          }
        }
      },
      "text": {
        "primary": {
          "$type": "color",
          "$value": "{color.gray.900}",
          "$extensions": {
            "mode": {
              "dark": "{color.gray.50}"
            }
          }
        },
        "secondary": {
          "$type": "color",
          "$value": "{color.gray.600}",
          "$extensions": {
            "mode": {
              "dark": "{color.gray.300}"
            }
          }
        },
        "tertiary": {
          "$type": "color",
          "$value": "{color.gray.500}",
          "$extensions": {
            "mode": {
              "dark": "{color.gray.400}"
            }
          }
        },
        "disabled": {
          "$type": "color",
          "$value": "{color.gray.400}",
          "$extensions": {
            "mode": {
              "dark": "{color.gray.600}"
            }
          }
        },
        "link": {
          "$type": "color",
          "$value": "{color.brand.600}",
          "$extensions": {
            "mode": {
              "dark": "{color.brand.400}"
            }
          }
        },
        "on-action": {
          "$type": "color",
          "$value": "{color.white}",
          "$extensions": {
            "mode": {
              "dark": "{color.gray.950}"
            }
          }
        }
      },
      "border": {
        "subtle": {
          "$type": "color",
          "$value": "{color.gray.200}",
          "$extensions": {
            "mode": {
              "dark": "{color.gray.800}"
            }
          }
        },
        "default": {
          "$type": "color",
          "$value": "{color.gray.500}",
          "$extensions": {
            "mode": {
              "dark": "{color.gray.400}"
            }
          }
        },
        "focus": {
          "$type": "color",
          "$value": "{color.brand.500}",
          "$extensions": {
            "mode": {
              "dark": "{color.brand.400}"
            }
          }
        },
        "error": {
          "$type": "color",
          "$value": "{color.red.600}",
          "$extensions": {
            "mode": {
              "dark": "{color.red.400}"
            }
          }
        }
      },
      "action": {
        "primary": {
          "bg": {
            "$type": "color",
            "$value": "{color.brand.600}",
            "$extensions": {
              "mode": {
                "dark": "{color.brand.400}"
              }
            }
          },
          "hover": {
            "$type": "color",
            "$value": "{color.brand.700}",
            "$extensions": {
              "mode": {
                "dark": "{color.brand.300}"
              }
            }
          },
          "active": {
            "$type": "color",
            "$value": "{color.brand.800}",
            "$extensions": {
              "mode": {
                "dark": "{color.brand.200}"
              }
            }
          }
        }
      },
      "status": {
        "error": {
          "fg": {
            "$type": "color",
            "$value": "{color.red.700}",
            "$extensions": {
              "mode": {
                "dark": "{color.red.400}"
              }
            }
          },
          "bg": {
            "$type": "color",
            "$value": "{color.red.50}",
            "$extensions": {
              "mode": {
                "dark": "{color.red.950}"
              }
            }
          },
          "border": {
            "$type": "color",
            "$value": "{color.red.300}",
            "$extensions": {
              "mode": {
                "dark": "{color.red.800}"
              }
            }
          }
        },
        "success": {
          "fg": {
            "$type": "color",
            "$value": "{color.green.700}",
            "$extensions": {
              "mode": {
                "dark": "{color.green.400}"
              }
            }
          },
          "bg": {
            "$type": "color",
            "$value": "{color.green.50}",
            "$extensions": {
              "mode": {
                "dark": "{color.green.950}"
              }
            }
          },
          "border": {
            "$type": "color",
            "$value": "{color.green.300}",
            "$extensions": {
              "mode": {
                "dark": "{color.green.800}"
              }
            }
          }
        },
        "warning": {
          "fg": {
            "$type": "color",
            "$value": "{color.amber.700}",
            "$extensions": {
              "mode": {
                "dark": "{color.amber.400}"
              }
            }
          },
          "bg": {
            "$type": "color",
            "$value": "{color.amber.50}",
            "$extensions": {
              "mode": {
                "dark": "{color.amber.950}"
              }
            }
          },
          "border": {
            "$type": "color",
            "$value": "{color.amber.300}",
            "$extensions": {
              "mode": {
                "dark": "{color.amber.800}"
              }
            }
          }
        },
        "info": {
          "fg": {
            "$type": "color",
            "$value": "{color.brand.600}",
            "$extensions": {
              "mode": {
                "dark": "{color.brand.400}"
              }
            }
          },
          "bg": {
            "$type": "color",
            "$value": "{color.brand.50}",
            "$extensions": {
              "mode": {
                "dark": "{color.navy.950}"
              }
            }
          },
          "border": {
            "$type": "color",
            "$value": "{color.brand.200}",
            "$extensions": {
              "mode": {
                "dark": "{color.brand.800}"
              }
            }
          }
        }
      }
    }
  },
  "font": {
    "family": {
      "sans": {
        "$type": "fontFamily",
        "$value": [
          "Inter",
          "system-ui",
          "sans-serif"
        ]
      },
      "mono": {
        "$type": "fontFamily",
        "$value": [
          "JetBrains Mono",
          "ui-monospace",
          "monospace"
        ]
      }
    },
    "size": {
      "xs": {
        "$type": "number",
        "$value": 12
      },
      "sm": {
        "$type": "number",
        "$value": 14
      },
      "md": {
        "$type": "number",
        "$value": 16
      },
      "lg": {
        "$type": "number",
        "$value": 18
      },
      "xl": {
        "$type": "number",
        "$value": 20
      },
      "2xl": {
        "$type": "number",
        "$value": 24
      },
      "3xl": {
        "$type": "number",
        "$value": 30
      },
      "4xl": {
        "$type": "number",
        "$value": 36
      },
      "5xl": {
        "$type": "number",
        "$value": 48
      }
    },
    "weight": {
      "regular": {
        "$type": "fontWeight",
        "$value": 400
      },
      "medium": {
        "$type": "fontWeight",
        "$value": 500
      },
      "semibold": {
        "$type": "fontWeight",
        "$value": 600
      },
      "bold": {
        "$type": "fontWeight",
        "$value": 700
      }
    },
    "line-height": {
      "tight": {
        "$type": "number",
        "$value": 1.2
      },
      "snug": {
        "$type": "number",
        "$value": 1.3
      },
      "normal": {
        "$type": "number",
        "$value": 1.5
      },
      "relaxed": {
        "$type": "number",
        "$value": 1.6
      }
    },
    "letter-spacing": {
      "tight": {
        "$type": "number",
        "$value": -0.02
      },
      "normal": {
        "$type": "number",
        "$value": 0
      }
    }
  },
  "space": {
    "0": {
      "$type": "number",
      "$value": 0
    },
    "1": {
      "$type": "number",
      "$value": 4
    },
    "2": {
      "$type": "number",
      "$value": 8
    },
    "3": {
      "$type": "number",
      "$value": 12
    },
    "4": {
      "$type": "number",
      "$value": 16
    },
    "5": {
      "$type": "number",
      "$value": 20
    },
    "6": {
      "$type": "number",
      "$value": 24
    },
    "8": {
      "$type": "number",
      "$value": 32
    },
    "10": {
      "$type": "number",
      "$value": 40
    },
    "12": {
      "$type": "number",
      "$value": 48
    },
    "16": {
      "$type": "number",
      "$value": 64
    },
    "20": {
      "$type": "number",
      "$value": 80
    },
    "24": {
      "$type": "number",
      "$value": 96
    }
  },
  "radius": {
    "none": {
      "$type": "number",
      "$value": 0
    },
    "sm": {
      "$type": "number",
      "$value": 4
    },
    "md": {
      "$type": "number",
      "$value": 8
    },
    "lg": {
      "$type": "number",
      "$value": 12
    },
    "xl": {
      "$type": "number",
      "$value": 16
    },
    "full": {
      "$type": "number",
      "$value": 9999
    }
  },
  "shadow": {
    "sm": {
      "$type": "shadow",
      "$value": {
        "web": "0 1px 3px rgba(3, 7, 18, 0.1)",
        "ios": {
          "shadowColor": "#030712",
          "shadowOffset": {
            "width": 0,
            "height": 1
          },
          "shadowOpacity": 0.1,
          "shadowRadius": 1.5
        },
        "android": {
          "elevation": 1
        }
      }
    },
    "md": {
      "$type": "shadow",
      "$value": {
        "web": "0 4px 12px rgba(3, 7, 18, 0.12)",
        "ios": {
          "shadowColor": "#030712",
          "shadowOffset": {
            "width": 0,
            "height": 4
          },
          "shadowOpacity": 0.12,
          "shadowRadius": 6.0
        },
        "android": {
          "elevation": 4
        }
      }
    },
    "lg": {
      "$type": "shadow",
      "$value": {
        "web": "0 8px 24px rgba(3, 7, 18, 0.14)",
        "ios": {
          "shadowColor": "#030712",
          "shadowOffset": {
            "width": 0,
            "height": 8
          },
          "shadowOpacity": 0.14,
          "shadowRadius": 12.0
        },
        "android": {
          "elevation": 8
        }
      }
    },
    "xl": {
      "$type": "shadow",
      "$value": {
        "web": "0 20px 60px rgba(3, 7, 18, 0.18)",
        "ios": {
          "shadowColor": "#030712",
          "shadowOffset": {
            "width": 0,
            "height": 20
          },
          "shadowOpacity": 0.18,
          "shadowRadius": 30.0
        },
        "android": {
          "elevation": 16
        }
      }
    }
  },
  "motion": {
    "duration": {
      "fast": {
        "$type": "duration",
        "$value": 150
      },
      "normal": {
        "$type": "duration",
        "$value": 250
      },
      "slow": {
        "$type": "duration",
        "$value": 400
      }
    },
    "easing": {
      "enter": {
        "$type": "cubicBezier",
        "$value": [
          0,
          0,
          0.2,
          1
        ]
      },
      "exit": {
        "$type": "cubicBezier",
        "$value": [
          0.4,
          0,
          1,
          1
        ]
      },
      "standard": {
        "$type": "cubicBezier",
        "$value": [
          0.4,
          0,
          0.2,
          1
        ]
      },
      "spring": {
        "$type": "cubicBezier",
        "$value": [
          0.34,
          1.56,
          0.64,
          1
        ]
      }
    }
  },
  "component": {
    "button": {
      "primary": {
        "bg": {
          "$type": "color",
          "$value": "{semantic.color.action.primary.bg}"
        },
        "fg": {
          "$type": "color",
          "$value": "{semantic.color.text.on-action}"
        },
        "radius": {
          "$type": "number",
          "$value": "{radius.md}"
        },
        "height": {
          "$type": "number",
          "$value": 48
        }
      }
    },
    "input": {
      "border": {
        "$type": "color",
        "$value": "{semantic.color.border.default}"
      },
      "border-focus": {
        "$type": "color",
        "$value": "{semantic.color.border.focus}"
      },
      "border-error": {
        "$type": "color",
        "$value": "{semantic.color.border.error}"
      },
      "height": {
        "$type": "number",
        "$value": 48
      }
    }
  }
}
```

## Platform export

| Target       | How the tokens land                                                                                                                                            |
| ------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| CSS          | Style Dictionary emits `--color-text-primary` custom properties; mode files emit the same names under `[data-theme="dark"]` or `prefers-color-scheme`          |
| Tailwind     | Map `theme.extend.colors` to `var(--color-*)`, `spacing` and `borderRadius` to the numeric scales with `px`, and `fontSize` to `[size, { lineHeight }]` tuples |
| React Native | Build `theme.light` and `theme.dark` objects; numbers feed `StyleSheet` directly; choose `shadow.*.ios` or `shadow.*.android` with `Platform.select`           |
| iOS          | Export to asset catalogs or Swift constants in `pt`; map `font.size` to Dynamic Type text styles where possible                                                |
| Android      | Export to `colors.xml` and `dimens.xml` in `dp` and `sp`, or to Compose theme objects                                                                          |
| Figma        | Import as variables with two modes (light, dark) in one collection; bind component properties to semantic variables only                                       |

## Token deliverable checklist

- [ ] Three tiers present; components reference semantic or component tokens only
- [ ] Light and dark values for every semantic color
- [ ] Contrast table with a computed ratio for every text and UI pair, in both modes
- [ ] Type scale with sizes, weights, line-heights, and a stated ratio
- [ ] Spacing on a 4 px grid; one radius family; per-platform shadows; motion durations and easings
- [ ] Naming rules stated; platform export notes included
- [ ] Known gaps listed (values not yet verified, components not yet tokenized)
