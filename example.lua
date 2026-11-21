--[[
	GameSenseLib — remote example
	Run with:
		loadstring(game:HttpGet("https://raw.githubusercontent.com/cuckcoding/GameSenseLib/main/example.lua"))()

	It pulls the library from GitHub and builds a sample GameSense-style menu.
	Press RightShift to toggle the menu.
]]

local REPO = "https://raw.githubusercontent.com/cuckcoding/GameSenseLib/main/GameSenseLib.lua"
local Library = loadstring(game:HttpGet(REPO))()

local Window = Library:CreateWindow({ Title = "gamesense", Accent = Color3.fromRGB(114, 132, 255) })

--============================ RAGE TAB ============================
local Rage = Window:AddTab("Rage", "crosshair")

local Aim = Rage:AddSection("Aimbot", "Left")
Aim:AddToggle({ Text = "Enabled", Flag = "aim_enabled", Default = true })
	:AddKeybind({ Flag = "aim_key", Default = "MouseButton2", Mode = "Hold" })
Aim:AddDropdown({ Text = "Target hitbox", Flag = "aim_hitbox",
	Options = { "Head", "Neck", "Chest", "Stomach", "Pelvis" }, Default = "Head" })
Aim:AddSlider({ Text = "Maximum FOV", Flag = "aim_fov", Min = 0, Max = 180, Default = 10, Decimals = 1, Suffix = "°" })
Aim:AddSlider({ Text = "Speed", Flag = "aim_speed", Min = 0, Max = 1, Default = 0.65, Decimals = 2 })
Aim:AddSlider({ Text = "Reaction time", Flag = "aim_reaction", Min = 0, Max = 500, Default = 100, Suffix = "ms" })
Aim:AddSlider({ Text = "Recoil compensation", Flag = "aim_rcs", Min = 0, Max = 100, Default = 75, Suffix = "%" })
Aim:AddToggle({ Text = "Quick stop", Flag = "aim_quickstop" })
Aim:AddToggle({ Text = "Aim through smoke", Flag = "aim_smoke" })

local Trig = Rage:AddSection("Triggerbot", "Right")
Trig:AddToggle({ Text = "Enabled", Flag = "trig_enabled" })
	:AddKeybind({ Flag = "trig_key", Default = "LeftAlt", Mode = "Hold" })
Trig:AddSlider({ Text = "Minimum hit chance", Flag = "trig_hc", Min = 0, Max = 100, Default = 75, Suffix = "%" })
Trig:AddSlider({ Text = "Minimum damage", Flag = "trig_dmg", Min = 1, Max = 100, Default = 1 })
Trig:AddSlider({ Text = "Reaction time", Flag = "trig_delay", Min = 0, Max = 250, Default = 0, Suffix = "ms" })
Trig:AddToggle({ Text = "Burst fire", Flag = "trig_burst" })
Trig:AddToggle({ Text = "Shoot through walls", Flag = "trig_walls" })

local Other = Rage:AddSection("Other", "Right")
Other:AddDropdown({ Text = "Accuracy boost", Flag = "acc_boost", Options = { "Off", "Low", "High", "Max" }, Default = "Off" })
Other:AddToggle({ Text = "Standalone recoil compensation", Flag = "standalone_rcs" })

--============================ VISUALS TAB ============================
local Visuals = Window:AddTab("Visuals", "eye")
local ESP = Visuals:AddSection("Player ESP", "Left")
ESP:AddToggle({ Text = "Enabled", Flag = "esp_enabled", Default = true })
ESP:AddToggle({ Text = "Box", Flag = "esp_box", Default = true })
	:AddColorPicker({ Flag = "esp_box_color", Default = Color3.fromRGB(166, 226, 46) })
ESP:AddToggle({ Text = "Name", Flag = "esp_name", Default = true })
	:AddColorPicker({ Flag = "esp_name_color", Default = Color3.fromRGB(255, 255, 255) })
ESP:AddToggle({ Text = "Health bar", Flag = "esp_health" })
ESP:AddSlider({ Text = "Render distance", Flag = "esp_dist", Min = 50, Max = 2000, Default = 500, Suffix = "m" })
ESP:AddDropdown({ Text = "Box style", Flag = "esp_style", Options = { "2D", "Corner", "3D" }, Default = "Corner" })

local World = Visuals:AddSection("World", "Right")
World:AddToggle({ Text = "Fullbright", Flag = "world_fb" })
World:AddSlider({ Text = "FOV", Flag = "world_fov", Min = 70, Max = 120, Default = 90 })
World:AddColorPicker({ Text = "Skybox tint", Flag = "world_sky", Default = Color3.fromRGB(40, 40, 60) })
World:AddKeybind({ Text = "Zoom key", Flag = "world_zoom", Default = "C" })

--============================ MISC TAB ============================
local Misc = Window:AddTab("Misc", "wrench")
local Movement = Misc:AddSection("Movement", "Left")
Movement:AddToggle({ Text = "Bunny hop", Flag = "misc_bhop" })
Movement:AddSlider({ Text = "Walk speed", Flag = "misc_ws", Min = 16, Max = 100, Default = 16 })
Movement:AddButton({ Text = "Reset character", Callback = function()
	Library:Notify({ Title = "Misc", Text = "Reset pressed." })
end })
Movement:AddTextbox({ Text = "Nickname", Flag = "misc_nick", Placeholder = "player" })

local Menu = Misc:AddSection("Menu", "Right")
Menu:AddColorPicker({ Text = "Accent color", Flag = "menu_accent", Default = Color3.fromRGB(114, 132, 255),
	Callback = function(c) Library:SetAccent(c) end })
Menu:AddButton({ Text = "Unload menu", Callback = function() Library:Unload() end })

--============================ CONFIG TAB ============================
Window:AddConfigTab()

Library:Notify({ Title = "gamesense", Text = "Loaded from GitHub. Press [RShift] to toggle.", Duration = 5 })
