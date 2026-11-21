# GameSenseLib

A modern **Roblox UI library** (Luau / executors) with a Linoria / Obsidian-style layout:
a left icon+label tab rail, titled groupboxes in two columns, rounded panels, drop shadow,
**Lucide icons**, and a full config system. Reference only — not a copy of any menu.

![status](https://img.shields.io/badge/luau-UI%20library-7884ff)

## Load it (loadstring)

Pull the library straight from GitHub and build your own menu:

```lua
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/cuckcoding/GameSenseLib/main/GameSenseLib.lua"))()

local Window = Library:CreateWindow({ Title = "gamesense", Accent = Color3.fromRGB(114, 132, 255) })
local Tab    = Window:AddTab("Rage", "crosshair")      -- 2nd arg = Lucide icon name
local Aim    = Tab:AddGroupbox("Aimbot", "Left")       -- (AddSection still works as an alias)

Aim:AddToggle({ Text = "Enabled", Flag = "aim_enabled", Default = true })
   :AddKeybind({ Flag = "aim_key", Default = "MouseButton2", Mode = "Hold" })

Aim:AddSlider({ Text = "Maximum FOV", Flag = "aim_fov", Min = 0, Max = 180, Default = 10, Decimals = 1, Suffix = "°" })

Window:AddConfigTab()   -- save / load / export / import
```

### Or run the ready-made demo

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/cuckcoding/GameSenseLib/main/example.lua"))()
```

Press **RightShift** to toggle the menu.

## Features

- **Window** — draggable, rounded, drop shadow, configurable toggle key (`RightShift`), intro tween
- **Icon tab rail** — `Window:AddTab(name, iconName)` using **Lucide icons**; two-column **groupboxes** (`"Left"` / `"Right"`)
  - Bundled icon names: `crosshair`, `eye`, `settings`, `wrench`, `save`, `folder`, `user`, `zap`
    (plus aliases like `aim`, `visuals`, `misc`, `config`). You can also pass a raw `"rbxassetid://123"`,
    or `nil` to fall back to the tab's first letter.
- **Elements**
  - `AddToggle` — chain `:AddKeybind{...}` and `:AddColorPicker{...}` onto it
  - `AddSlider` — min/max, decimals, suffix, live value, gradient fill
  - `AddDropdown` — single **or** multi-select (`Multi = true`)
  - `AddButton`, `AddTextbox`, `AddKeybind`, `AddColorPicker` (HSV + hex), `AddLabel`, `AddDivider`
- **Notifications** — `Library:Notify{ Title, Text, Duration }`
- **Config system** — every element with a `Flag` auto-registers:
  - `Library:SaveConfig(name)` / `LoadConfig(name)` / `DeleteConfig(name)` / `ListConfigs()`
  - `Library:ExportConfig([name])` → base64 string (also copied to clipboard)
  - `Library:ImportConfig(str)`
  - `Window:AddConfigTab()` builds a ready-made config UI
- **Executor-agnostic** — resolves `gethui` / `CoreGui` / `PlayerGui`, guards every `writefile` / `setclipboard` call

## API cheatsheet

```lua
Library:CreateWindow{ Title, Accent, Size, ToggleKey }   -> Window
Library:SetAccent(Color3)      Library:Toggle([bool])     Library:Unload()
Library.Flags[flag]            Library:GetFlag(f) / :SetFlag(f, v)

Window:AddTab(name, iconName?) -> Tab        Window:AddConfigTab()
Window:SetToggleKey(keyName)                  -- default "RightShift"

Tab:AddGroupbox(title, "Left"|"Right") -> Groupbox      -- AddSection = alias

Groupbox:AddToggle{Text,Flag,Default,Callback}     -- :AddKeybind{} / :AddColorPicker{}
Groupbox:AddSlider{Text,Flag,Min,Max,Default,Decimals,Suffix,Callback}
Groupbox:AddDropdown{Text,Flag,Options,Default,Multi,Callback}
Groupbox:AddButton{Text,Callback}      Groupbox:AddTextbox{Text,Flag,Default,Placeholder,Callback}
Groupbox:AddKeybind{Text,Flag,Default,Mode,Callback}
Groupbox:AddColorPicker{Text,Flag,Default,Alpha,Callback}
Groupbox:AddLabel(text)                Groupbox:AddDivider()
```

Every element returns an object with `:Set(value)` / `:Get()` (and `:SetText()` where relevant),
so configs can restore the whole menu state.

## Notes

This is a UI framework only — the example's labels (Aimbot, ESP, …) are placeholder content to
demonstrate layout; the callbacks are no-ops. Bring your own logic.

Tab icons use the [Lucide](https://lucide.dev) icon set via assets from
[latte-soft/lucide-roblox](https://github.com/latte-soft/lucide-roblox) (ISC). Design language
inspired by [Linoria](https://github.com/violin-suzutsuki/LinoriaLib) / Obsidian.

## License

MIT
