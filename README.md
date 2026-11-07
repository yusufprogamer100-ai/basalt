# Basalt

A Roblox UI library for executor environments. One file at runtime, a real
module graph at build time, and a design system that refuses decoration it
cannot justify.

```
dist/basalt.luau   ~1.9k lines, no dependencies
```

## Install

```lua
local Basalt = loadstring(game:HttpGet("https://raw.githubusercontent.com/you/basalt/main/dist/basalt.luau"))()

local window = Basalt:Window({
    Title = "Basalt",
    Size = UDim2.fromOffset(760, 500),
    Theme = "basalt-dark",
    ToggleKey = Enum.KeyCode.RightShift,
})
```

## What it does

| Area | Detail |
| --- | --- |
| Window | drag, tab rail, search that filters every control, overlay layer, status line |
| Tabs | per-tab scroll position, lazy pages, two-column sections |
| Sections | auto height, collapse, badge, left/right columns |
| Controls | toggle, slider, range, dropdown (single + multi), input, keybind, colorpicker, button, label, paragraph, divider, space |
| State | key-based flags, `OnChanged`, two-way config binding, no global state |
| Config | schema-tagged JSON, profiles, decode/encode for `EnumItem` / `Color3`, debounced autosave |
| Theme | four presets + token bindings; re-theming never walks the instance tree |
| Feedback | stacked toasts with type colour, progress and manual dismiss |
| Safety | executor feature detection, pcall-isolated handlers, clean teardown |

## Why flags

Every control can carry a `Key`. The control writes to the flag, the flag fires,
the control renders. Config load writes flags, controls follow. There is exactly
one owner for a value, which is why save/load never desyncs from the screen.

```lua
aim:Slider({ Key = "smoothing", Title = "Smoothing", Min = 0, Max = 1, Rounding = 2 })

Basalt.Flags:OnChanged("smoothing", function(value) print(value) end)
Basalt.Config:Save("main")
```

## Themes

```lua
window:SetTheme("basalt-dusk")     -- basalt-dark | basalt-dusk | basalt-light | basalt-contrast
```

Tokens are semantic (`surface`, `textMuted`, `accent`, `danger`, ...), never raw
hex at call sites. `Theme:Bind(instance, "TextColor3", "text")` is the only way
a colour reaches a component, so a theme switch touches bindings, not descendants.

## Layout

Sections measure themselves: `UIListLayout` + `AutomaticSize`. The tab body is
the max of its two columns; reflow is debounced and only runs when content size
actually changes. No `Heartbeat` loop, no per-frame measurement.

## Build

```bash
python tools/build.py           # -> dist/basalt.luau
python tools/build.py --check   # validate the module graph
```

`src/` is the source of truth. `tools/build.py` concatenates modules in explicit
dependency order and wraps them with a private `require`, so the shipped file
stays a single `loadstring` target while the repository stays reviewable.

## Layout of the source

```
src/core        class, signal, instance, guard
src/services    theme, motion, flags, config, input, notify
src/components  one file per control
src/section     section container
src/tab         page + columns + reflow
src/window      chrome, search, overlay, status
src/init        public API
```

## Conventions

- No globals. Everything is a local or a module field.
- Handlers are isolated with `pcall`; a broken callback cannot freeze the UI.
- Colours only through `Theme:Bind`.
- Spacing only from 4 / 8 / 12 / 16 / 24 / 32.
- One accent colour. Status colours only for status.
- No gradients, blurs, glows, or decorative shadows in the default theme.

## Status

0.1.0 — core, all twelve controls, theming, flags, config, toasts, search.
Next: command palette, HSV picker, key-system module, mobile dock, tooltips,
`NeverLose` compatibility shim for porting existing scripts.
