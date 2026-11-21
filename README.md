# GameSenseLib

A lightweight **GameSense-inspired UI library** for Roblox (Luau / executors). The look is
taken as a *reference* — dark panels, lime accent, column sections, filled sliders, toggles
with attachable keybinds/color pickers, dropdowns, and a full config system. It is a reusable
widget framework, not a copy of any menu.

![status](https://img.shields.io/badge/luau-UI%20library-a3e635)

## Load it (loadstring)

Pull the library straight from GitHub and build your own menu:

```lua
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/cuckcoding/GameSenseLib/main/GameSenseLib.lua"))()

local Window = Library:CreateWindow({ Title = "gamesense", Accent = Color3.fromRGB(166, 226, 46) })
local Tab    = Window:AddTab("Rage", "R")
local Aim    = Tab:AddSection("Aimbot", "Left")

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

- **Window** — draggable, animated accent strip, accent glow, configurable toggle key, intro tween
- **Sidebar tabs** → two-column **sections** (`"Left"` / `"Right"`)
- **Elements**
  - `AddToggle` — chain `:AddKeybind{...}` and `:AddColorPicker{...}` onto it (GameSense style)
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

Window:AddTab(name, iconText?) -> Tab        Window:AddConfigTab()
Window:SetToggleKey(keyName)                  -- default "RightShift"

Tab:AddSection(title, "Left"|"Right") -> Section

Section:AddToggle{Text,Flag,Default,Callback}      -- :AddKeybind{} / :AddColorPicker{}
Section:AddSlider{Text,Flag,Min,Max,Default,Decimals,Suffix,Callback}
Section:AddDropdown{Text,Flag,Options,Default,Multi,Callback}
Section:AddButton{Text,Callback}       Section:AddTextbox{Text,Flag,Default,Placeholder,Callback}
Section:AddKeybind{Text,Flag,Default,Mode,Callback}
Section:AddColorPicker{Text,Flag,Default,Alpha,Callback}
Section:AddLabel(text)                 Section:AddDivider()
```

Every element returns an object with `:Set(value)` / `:Get()` (and `:SetText()` where relevant),
so configs can restore the whole menu state.

## Notes

This is a UI framework only — the example's labels (Aimbot, ESP, …) are placeholder content to
demonstrate layout; the callbacks are no-ops. Bring your own logic.

## License

MIT
