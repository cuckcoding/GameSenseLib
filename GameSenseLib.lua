--[[
	GameSenseLib  —  a GameSense-inspired UI Library for Roblox (Luau / executors)
	Design reference: GameSense CS2 aesthetic (dark panels, lime accent, column sections,
	sliders with filled bars, toggles, dropdowns, keybinds, color pickers, config system).

	NOT a copy of any menu — a reusable widget library with a GameSense-style skin.

	--------------------------------------------------------------------------------------
	QUICK START
	--------------------------------------------------------------------------------------
		local Library = loadstring(readfile("GameSenseLib.lua"))()   -- or loadstring(game:HttpGet(url))()

		local Window = Library:CreateWindow({ Title = "gamesense", Accent = Color3.fromRGB(166,226,46) })

		local Rage = Window:AddTab("Rage")
		local Aim  = Rage:AddSection("Aimbot", "Left")

		Aim:AddToggle({ Text = "Enabled", Flag = "aim_enabled", Default = true,
			Callback = function(v) print("aim", v) end })
			:AddKeybind({ Flag = "aim_key", Default = "MouseButton2", Mode = "Hold" })

		Aim:AddDropdown({ Text = "Hitbox", Flag = "aim_hitbox",
			Options = {"Head","Neck","Chest","Pelvis"}, Default = "Head" })

		Aim:AddSlider({ Text = "Maximum FOV", Flag = "aim_fov", Min = 0, Max = 180,
			Default = 10, Suffix = "°", Decimals = 1 })

		Window:AddConfigTab()      -- adds a ready-made Config tab (save/load/export/import)

	--------------------------------------------------------------------------------------
	API SURFACE  (chainable where sensible)
	--------------------------------------------------------------------------------------
		Library:CreateWindow(opts)            -> Window
		Library:SetAccent(Color3)
		Library:Toggle([bool])                -- show/hide
		Library:Notify({Title,Text,Duration})
		Library.Flags                         -- flag -> current value  (read any time)
		Library:GetFlag(flag) / :SetFlag(flag,value)
		Library:SaveConfig(name) / :LoadConfig(name) / :DeleteConfig(name) / :ListConfigs()
		Library:ExportConfig([name]) -> string(base64)     -- also copies to clipboard
		Library:ImportConfig(str)                          -- apply a base64 config string
		Library:Unload()

		Window:AddTab(name, iconText?)        -> Tab
		Window:AddConfigTab()
		Window:SetToggleKey(KeyName)          -- default "RightShift"

		Tab:AddSection(title, "Left"/"Right") -> Section

		Section:AddToggle{Text,Flag,Default,Callback}        -> Toggle (chain :AddKeybind/:AddColorPicker)
		Section:AddSlider{Text,Flag,Min,Max,Default,Decimals,Suffix,Callback}
		Section:AddDropdown{Text,Flag,Options,Default,Multi,Callback}
		Section:AddButton{Text,Callback}
		Section:AddKeybind{Text,Flag,Default,Mode,Callback}
		Section:AddColorPicker{Text,Flag,Default,Alpha,Callback}
		Section:AddTextbox{Text,Flag,Default,Placeholder,Callback}
		Section:AddLabel(text)  /  :AddDivider()

		Every element returns an object with :Set(value), :Get(), :SetText(s) where relevant.
]]

--==================================================================================
--  SERVICES / ENVIRONMENT
--==================================================================================
local Players           = game:GetService("Players")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")
local RunService        = game:GetService("RunService")
local HttpService       = game:GetService("HttpService")
local CoreGui           = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer

-- optional executor functions (referencing an undefined global yields nil, never errors)
local _writefile   = writefile
local _readfile    = readfile
local _isfile      = isfile
local _isfolder    = isfolder
local _makefolder  = makefolder
local _listfiles   = listfiles
local _delfile     = delfile
local _gethui      = gethui
local _setclip     = (setclipboard or toclipboard or (syn and syn.write_clipboard))
local _protectgui  = (protectgui or (syn and syn.protect_gui) or function() end)

local HAS_FS = (typeof(_writefile) == "function" and typeof(_readfile) == "function")

--==================================================================================
--  LIBRARY TABLE
--==================================================================================
local Library = {
	Flags        = {},        -- flag -> value
	Registry     = {},        -- flag -> element object (has :Set/:Get)
	Connections  = {},
	Windows      = {},
	Open         = true,
	Unloaded     = false,
	ConfigFolder = "GameSenseLib",
	Theme = {
		Accent      = Color3.fromRGB(166, 226, 46),
		Window      = Color3.fromRGB(18, 18, 20),
		Panel       = Color3.fromRGB(24, 24, 27),
		Section     = Color3.fromRGB(21, 21, 24),
		Element     = Color3.fromRGB(32, 32, 36),
		ElementDark = Color3.fromRGB(14, 14, 16),
		Border      = Color3.fromRGB(8, 8, 9),
		BorderLight = Color3.fromRGB(44, 44, 48),
		Text        = Color3.fromRGB(225, 225, 228),
		TextDim     = Color3.fromRGB(135, 135, 142),
		TextDark    = Color3.fromRGB(90, 90, 96),
	},
	Font      = Enum.Font.Gotham,
	FontBold  = Enum.Font.GothamBold,
	FontSize  = 12,
}

--==================================================================================
--  SMALL UTILITIES
--==================================================================================
local function track(conn)
	table.insert(Library.Connections, conn)
	return conn
end

local function new(class, props, children)
	local inst = Instance.new(class)
	if props then
		for k, v in pairs(props) do
			if k ~= "Parent" then inst[k] = v end
		end
	end
	if children then
		for _, c in ipairs(children) do c.Parent = inst end
	end
	if props and props.Parent then inst.Parent = props.Parent end
	return inst
end

local function corner(parent, radius)
	return new("UICorner", { CornerRadius = UDim.new(0, radius or 4), Parent = parent })
end

local function stroke(parent, color, thickness, transparency)
	return new("UIStroke", {
		Color = color or Library.Theme.Border,
		Thickness = thickness or 1,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

local function pad(parent, l, t, r, b)
	return new("UIPadding", {
		PaddingLeft   = UDim.new(0, l or 0),
		PaddingTop    = UDim.new(0, t or 0),
		PaddingRight  = UDim.new(0, r or 0),
		PaddingBottom = UDim.new(0, b or 0),
		Parent = parent,
	})
end

local function vlist(parent, padding, align)
	return new("UIListLayout", {
		Padding = UDim.new(0, padding or 6),
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = align or Enum.HorizontalAlignment.Left,
		Parent = parent,
	})
end

local function tween(inst, time, props)
	local t = TweenService:Create(inst, TweenInfo.new(time or 0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

local function round(n, decimals)
	local m = 10 ^ (decimals or 0)
	return math.floor(n * m + 0.5) / m
end

local function clamp(n, lo, hi) return math.max(lo, math.min(hi, n)) end

-- Base64 (for config export/import)
local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local function base64Encode(data)
	return ((data:gsub('.', function(x)
		local r, b = '', x:byte()
		for i = 8, 1, -1 do r = r .. (b % 2 ^ i - b % 2 ^ (i - 1) > 0 and '1' or '0') end
		return r
	end) .. '0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
		if #x < 6 then return '' end
		local c = 0
		for i = 1, 6 do c = c + (x:sub(i, i) == '1' and 2 ^ (6 - i) or 0) end
		return B64:sub(c + 1, c + 1)
	end) .. ({ '', '==', '=' })[#data % 3 + 1])
end
local function base64Decode(data)
	data = string.gsub(data, '[^' .. B64 .. '=]', '')
	return (data:gsub('.', function(x)
		if x == '=' then return '' end
		local r, f = '', (B64:find(x) - 1)
		for i = 6, 1, -1 do r = r .. (f % 2 ^ i - f % 2 ^ (i - 1) > 0 and '1' or '0') end
		return r
	end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
		if #x ~= 8 then return '' end
		local c = 0
		for i = 1, 8 do c = c + (x:sub(i, i) == '1' and 2 ^ (8 - i) or 0) end
		return string.char(c)
	end))
end

-- color (de)serialization for configs
local function encColor(c) return { __color = true, R = round(c.R*255,0), G = round(c.G*255,0), B = round(c.B*255,0) } end
local function isEncColor(v) return typeof(v) == "table" and v.__color end
local function decColor(v) return Color3.fromRGB(v.R, v.G, v.B) end

--==================================================================================
--  GUI ROOT
--==================================================================================
local ScreenGui = new("ScreenGui", {
	Name = "GameSenseLib_" .. tostring(math.random(10000, 99999)),
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = 9999,
	IgnoreGuiInset = true,
})

-- parent to the safest available container
do
	local ok = false
	if typeof(_gethui) == "function" then
		ok = pcall(function() ScreenGui.Parent = _gethui() end)
	end
	if not ok then
		ok = pcall(function()
			_protectgui(ScreenGui)
			ScreenGui.Parent = CoreGui
		end)
	end
	if not ok then
		pcall(function() ScreenGui.Parent = CoreGui end)
	end
	if not ScreenGui.Parent then
		ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
	end
end
Library.ScreenGui = ScreenGui

-- shared popup layer (dropdowns / color pickers float above everything)
local PopupLayer = new("Frame", {
	Name = "PopupLayer", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
	ZIndex = 50, Parent = ScreenGui,
})

local function closeAllPopups()
	for _, c in ipairs(PopupLayer:GetChildren()) do c.Visible = false end
	if Library._activePopup then Library._activePopup = nil end
end

--==================================================================================
--  CONFIG (filesystem) HELPERS
--==================================================================================
local function ensureFolder()
	if not HAS_FS then return false end
	pcall(function()
		if _isfolder and not _isfolder(Library.ConfigFolder) then _makefolder(Library.ConfigFolder) end
		local sub = Library.ConfigFolder .. "/configs"
		if _isfolder and not _isfolder(sub) then _makefolder(sub) end
	end)
	return true
end

local function configPath(name)
	return Library.ConfigFolder .. "/configs/" .. name .. ".json"
end

--==================================================================================
--  KEY HANDLING
--==================================================================================
local KeyDisplay = {
	MouseButton1 = "MB1", MouseButton2 = "MB2", MouseButton3 = "MB3",
	LeftControl = "LCtrl", RightControl = "RCtrl",
	LeftShift = "LShift", RightShift = "RShift",
	LeftAlt = "LAlt", RightAlt = "RAlt",
}
local function keyName(input)
	if input == nil then return "None" end
	if typeof(input) == "EnumItem" then
		local n = input.Name
		return KeyDisplay[n] or n
	end
	return tostring(input)
end
local function displayKey(stored)
	if not stored or stored == "None" then return "None" end
	return KeyDisplay[stored] or stored
end

-- list of bound keybinds: { stored=keyName, mode="Toggle"/"Hold"/"Always", state=bool, onChange=fn }
local KeyBinds = {}

--==================================================================================
--  LIBRARY-LEVEL METHODS
--==================================================================================
function Library:SetAccent(color)
	self.Theme.Accent = color
	for _, fn in ipairs(self._accentListeners or {}) do pcall(fn, color) end
end
Library._accentListeners = {}
local function onAccent(fn) table.insert(Library._accentListeners, fn); fn(Library.Theme.Accent) end

function Library:GetFlag(flag) return self.Flags[flag] end
function Library:SetFlag(flag, value)
	local el = self.Registry[flag]
	if el and el.Set then el:Set(value) else self.Flags[flag] = value end
end

function Library:Toggle(state)
	if state == nil then state = not self.Open end
	self.Open = state
	for _, w in ipairs(self.Windows) do
		if w.Root then w.Root.Visible = state end
	end
	if not state then closeAllPopups() end
	-- free / lock mouse
	pcall(function()
		if state then
			UserInputService.MouseIconEnabled = true
		end
	end)
end

function Library:Notify(opts)
	opts = opts or {}
	local holder = ScreenGui:FindFirstChild("Notifications")
	if not holder then
		holder = new("Frame", {
			Name = "Notifications", BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -12, 1, -12),
			Size = UDim2.new(0, 260, 1, -24), ZIndex = 200, Parent = ScreenGui,
		})
		new("UIListLayout", {
			Padding = UDim.new(0, 8), VerticalAlignment = Enum.VerticalAlignment.Bottom,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			SortOrder = Enum.SortOrder.LayoutOrder, Parent = holder,
		})
	end

	local card = new("Frame", {
		BackgroundColor3 = self.Theme.Panel, Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y, ClipsDescendants = true,
		ZIndex = 201, Parent = holder,
	})
	corner(card, 5); stroke(card, self.Theme.Border, 1)
	new("Frame", { BackgroundColor3 = self.Theme.Accent, Size = UDim2.new(0, 3, 1, 0),
		BorderSizePixel = 0, ZIndex = 202, Parent = card })
	local inner = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), ZIndex = 202, Parent = card })
	pad(inner, 12, 8, 10, 8); vlist(inner, 2)
	new("TextLabel", {
		BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 14), Font = self.FontBold,
		Text = opts.Title or "Notification", TextColor3 = self.Theme.Text, TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 203, Parent = inner,
	})
	if opts.Text then
		new("TextLabel", {
			BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 14), Font = self.Font,
			Text = opts.Text, TextColor3 = self.Theme.TextDim, TextSize = 11,
			TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y,
			TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 203, Parent = inner,
		})
	end
	card.BackgroundTransparency = 1
	tween(card, 0.18, { BackgroundTransparency = 0 })
	task.delay(opts.Duration or 4, function()
		if card and card.Parent then
			tween(card, 0.2, { BackgroundTransparency = 1 })
			task.wait(0.22); card:Destroy()
		end
	end)
end

function Library:Unload()
	self.Unloaded = true
	for _, c in ipairs(self.Connections) do pcall(function() c:Disconnect() end) end
	table.clear(self.Connections)
	pcall(function() ScreenGui:Destroy() end)
end

--==================================================================================
--  CONFIG SAVE / LOAD / EXPORT
--==================================================================================
local function serializeFlags()
	local out = {}
	for flag, value in pairs(Library.Flags) do
		if typeof(value) == "Color3" then
			out[flag] = encColor(value)
		elseif typeof(value) == "EnumItem" then
			out[flag] = { __enum = tostring(value) }
		elseif typeof(value) == "table" then
			-- multi-dropdown set: shallow copy (strings/bools)
			out[flag] = value
		else
			out[flag] = value
		end
	end
	return out
end

local function applyFlags(data)
	for flag, value in pairs(data) do
		if isEncColor(value) then value = decColor(value) end
		local el = Library.Registry[flag]
		if el and el.Set then
			pcall(function() el:Set(value) end)
		else
			Library.Flags[flag] = value
		end
	end
end

function Library:SaveConfig(name)
	if not name or name == "" then return false, "no name" end
	local data = serializeFlags()
	local json = HttpService:JSONEncode(data)
	if HAS_FS then
		ensureFolder()
		local ok, err = pcall(function() _writefile(configPath(name), json) end)
		if not ok then return false, tostring(err) end
	end
	self._memConfigs = self._memConfigs or {}
	self._memConfigs[name] = json
	return true
end

function Library:LoadConfig(name)
	local json
	if HAS_FS and _isfile and pcall(function() return _isfile(configPath(name)) end) and _isfile(configPath(name)) then
		json = _readfile(configPath(name))
	elseif self._memConfigs and self._memConfigs[name] then
		json = self._memConfigs[name]
	end
	if not json then return false, "not found" end
	local ok, data = pcall(function() return HttpService:JSONDecode(json) end)
	if not ok then return false, "decode error" end
	applyFlags(data)
	return true
end

function Library:DeleteConfig(name)
	if HAS_FS and _delfile and _isfile and _isfile(configPath(name)) then
		pcall(function() _delfile(configPath(name)) end)
	end
	if self._memConfigs then self._memConfigs[name] = nil end
	return true
end

function Library:ListConfigs()
	local list, seen = {}, {}
	if HAS_FS and _listfiles then
		ensureFolder()
		local ok, files = pcall(function() return _listfiles(self.ConfigFolder .. "/configs") end)
		if ok and files then
			for _, f in ipairs(files) do
				local n = tostring(f):match("([^/\\]+)%.json$")
				if n and not seen[n] then seen[n] = true; table.insert(list, n) end
			end
		end
	end
	if self._memConfigs then
		for n in pairs(self._memConfigs) do if not seen[n] then seen[n] = true; table.insert(list, n) end end
	end
	table.sort(list)
	return list
end

function Library:ExportConfig(name)
	local json
	if name then
		local ok = self:SaveConfig(name)
		json = self._memConfigs and self._memConfigs[name]
	end
	json = json or HttpService:JSONEncode(serializeFlags())
	local b64 = base64Encode(json)
	if _setclip then pcall(function() _setclip(b64) end) end
	return b64
end

function Library:ImportConfig(str)
	if not str or str == "" then return false, "empty" end
	local ok, json = pcall(function() return base64Decode(str) end)
	if not ok then return false, "bad base64" end
	local ok2, data = pcall(function() return HttpService:JSONDecode(json) end)
	if not ok2 then return false, "bad json" end
	applyFlags(data)
	return true
end

--==================================================================================
--  ELEMENT BUILDERS  (attached to Section objects)
--==================================================================================
local Section = {}
Section.__index = Section

local attachColorPicker  -- forward declaration (defined below, used by toggle attachments)

-- register a flag's value + element so config can read/write it
local function register(flag, element, defaultValue)
	if flag == nil then return end
	Library.Registry[flag] = element
	if Library.Flags[flag] == nil then Library.Flags[flag] = defaultValue end
end

----------------------------------------------------------------- LABEL
function Section:AddLabel(text)
	local lbl = new("TextLabel", {
		BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 16), Font = Library.Font,
		Text = text or "", TextColor3 = Library.Theme.TextDim, TextSize = Library.FontSize,
		TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true,
		AutomaticSize = Enum.AutomaticSize.Y, Parent = self.Container,
	})
	return { SetText = function(_, t) lbl.Text = t end, Instance = lbl }
end

----------------------------------------------------------------- DIVIDER
function Section:AddDivider()
	local holder = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 6), Parent = self.Container })
	new("Frame", {
		BackgroundColor3 = Library.Theme.BorderLight, BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 0.5, 0), Parent = holder,
	})
	return {}
end

----------------------------------------------------------------- TOGGLE
function Section:AddToggle(o)
	o = o or {}
	local flag = o.Flag
	local state = o.Default and true or false

	local row = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 18), Parent = self.Container })
	local box = new("Frame", {
		BackgroundColor3 = Library.Theme.ElementDark, Size = UDim2.new(0, 12, 0, 12),
		Position = UDim2.new(0, 0, 0.5, -6), Parent = row,
	})
	corner(box, 3); local bStroke = stroke(box, Library.Theme.BorderLight, 1)
	local fill = new("Frame", {
		BackgroundColor3 = Library.Theme.Accent, Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1, Parent = box,
	})
	corner(fill, 3)
	local label = new("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.new(0, 20, 0, 0),
		Size = UDim2.new(1, -20, 1, 0), Font = Library.Font, Text = o.Text or "Toggle",
		TextColor3 = state and Library.Theme.Text or Library.Theme.TextDim,
		TextSize = Library.FontSize, TextXAlignment = Enum.TextXAlignment.Left, Parent = row,
	})
	-- a slot on the right for attached keybind / colorpicker labels
	local rightSlot = new("Frame", {
		BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0, 70, 1, 0), Parent = row,
	})
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 5),
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder, Parent = rightSlot,
	})

	local element = {}
	local function visual()
		tween(fill, 0.12, { BackgroundTransparency = state and 0 or 1 })
		tween(box, 0.12, { BackgroundColor3 = state and Library.Theme.Accent or Library.Theme.ElementDark })
		bStroke.Color = state and Library.Theme.Accent or Library.Theme.BorderLight
		label.TextColor3 = state and Library.Theme.Text or Library.Theme.TextDim
	end

	function element:Set(v, skip)
		state = v and true or false
		if flag then Library.Flags[flag] = state end
		visual()
		if not skip and o.Callback then pcall(o.Callback, state) end
	end
	function element:Get() return state end
	function element:SetText(t) label.Text = t end

	local btn = new("TextButton", { BackgroundTransparency = 1, Text = "", Size = UDim2.new(1, -72, 1, 0), Parent = row })
	track(btn.MouseButton1Click:Connect(function() element:Set(not state) end))
	track(box.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 then element:Set(not state) end
	end))

	register(flag, element, state)
	visual()
	if o.Callback and state then pcall(o.Callback, state) end
	onAccent(function() if state then box.BackgroundColor3 = Library.Theme.Accent; fill.BackgroundColor3 = Library.Theme.Accent end end)

	-- chainable attachments stored so they float into rightSlot
	element._rightSlot = element._rightSlot or rightSlot

	-- ---- chained: keybind pill attached to this toggle
	function element:AddKeybind(k)
		k = k or {}
		local kFlag = k.Flag
		local stored = k.Default and keyName(k.Default) or "None"
		local mode = k.Mode or "Toggle"   -- Toggle / Hold / Always
		local pill = new("TextButton", {
			BackgroundColor3 = Library.Theme.ElementDark, AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 0, 0, 14), Font = Library.Font, Text = "[" .. displayKey(stored) .. "]",
			TextColor3 = Library.Theme.TextDim, TextSize = 11, Parent = rightSlot,
		})
		corner(pill, 3); pad(pill, 5, 0, 5, 0); stroke(pill, Library.Theme.Border, 1)
		local obj = { Mode = mode, Key = stored, _active = false }
		local function refresh() pill.Text = "[" .. displayKey(obj.Key) .. "]" end
		local listening = false
		track(pill.MouseButton1Click:Connect(function()
			listening = true; pill.Text = "[ ... ]"; pill.TextColor3 = Library.Theme.Accent
		end))
		track(UserInputService.InputBegan:Connect(function(input, gpe)
			if listening then
				local name
				if input.UserInputType == Enum.UserInputType.Keyboard then name = input.KeyCode.Name
				elseif input.UserInputType == Enum.UserInputType.MouseButton1 then name = "MouseButton1"
				elseif input.UserInputType == Enum.UserInputType.MouseButton2 then name = "MouseButton2"
				elseif input.UserInputType == Enum.UserInputType.MouseButton3 then name = "MouseButton3" end
				if name == "Escape" or name == "Backspace" then name = "None" end
				if name then
					obj.Key = name; listening = false; pill.TextColor3 = Library.Theme.TextDim
					if kFlag then Library.Flags[kFlag] = obj.Key end
					refresh()
				end
				return
			end
		end))
		-- Hold/Toggle behavior driving the parent toggle (optional)
		track(UserInputService.InputBegan:Connect(function(input, gpe)
			if gpe or obj.Key == "None" then return end
			local n = (input.KeyCode and input.KeyCode.Name) or (input.UserInputType and input.UserInputType.Name)
			if n == obj.Key then
				if obj.Mode == "Toggle" then element:Set(not state)
				elseif obj.Mode == "Hold" then element:Set(true, false) end
				if k.Callback then pcall(k.Callback, obj.Key) end
			end
		end))
		track(UserInputService.InputEnded:Connect(function(input)
			if obj.Key == "None" then return end
			local n = (input.KeyCode and input.KeyCode.Name) or (input.UserInputType and input.UserInputType.Name)
			if n == obj.Key and obj.Mode == "Hold" then element:Set(false) end
		end))
		local kelement = {
			Set = function(_, v) obj.Key = (typeof(v)=="EnumItem" and keyName(v)) or v; if kFlag then Library.Flags[kFlag]=obj.Key end; refresh() end,
			Get = function() return obj.Key end,
		}
		if kFlag then register(kFlag, kelement, obj.Key) end
		refresh()
		return element  -- keep chaining on toggle
	end

	-- ---- chained: color picker swatch attached to this toggle
	function element:AddColorPicker(c)
		attachColorPicker(rightSlot, c)   -- defined later; forward declared via upvalue
		return element
	end

	return element
end

----------------------------------------------------------------- SLIDER
function Section:AddSlider(o)
	o = o or {}
	local flag = o.Flag
	local min, max = o.Min or 0, o.Max or 100
	local decimals = o.Decimals or 0
	local suffix = o.Suffix or ""
	local value = clamp(o.Default or min, min, max)

	local holder = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 30), Parent = self.Container })
	local top = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 14), Parent = holder })
	new("TextLabel", {
		BackgroundTransparency = 1, Size = UDim2.new(1, -40, 1, 0), Font = Library.Font,
		Text = o.Text or "Slider", TextColor3 = Library.Theme.TextDim, TextSize = Library.FontSize,
		TextXAlignment = Enum.TextXAlignment.Left, Parent = top,
	})
	local valLabel = new("TextLabel", {
		BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.new(0, 60, 1, 0), Font = Library.FontBold,
		Text = tostring(round(value, decimals)) .. suffix, TextColor3 = Library.Theme.Accent,
		TextSize = Library.FontSize, TextXAlignment = Enum.TextXAlignment.Right, Parent = top,
	})
	local bar = new("Frame", {
		BackgroundColor3 = Library.Theme.ElementDark, Position = UDim2.new(0, 0, 0, 18),
		Size = UDim2.new(1, 0, 0, 8), Parent = holder,
	})
	corner(bar, 3); stroke(bar, Library.Theme.Border, 1)
	local fill = new("Frame", {
		BackgroundColor3 = Library.Theme.Accent, Size = UDim2.new((value - min) / (max - min), 0, 1, 0),
		Parent = bar,
	})
	corner(fill, 3)
	new("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(110, 150, 30)),
			ColorSequenceKeypoint.new(1, Library.Theme.Accent),
		}), Parent = fill,
	})

	local element = {}
	local function visual()
		local a = (value - min) / (max - min)
		tween(fill, 0.06, { Size = UDim2.new(clamp(a, 0, 1), 0, 1, 0) })
		valLabel.Text = tostring(round(value, decimals)) .. suffix
	end
	function element:Set(v, skip)
		value = clamp(round(tonumber(v) or min, decimals), min, max)
		if flag then Library.Flags[flag] = value end
		visual()
		if not skip and o.Callback then pcall(o.Callback, value) end
	end
	function element:Get() return value end

	local dragging = false
	local function setFromX(px)
		local rel = clamp((px - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
		element:Set(min + (max - min) * rel)
	end
	track(bar.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true; setFromX(i.Position.X) end
	end))
	track(UserInputService.InputChanged:Connect(function(i)
		if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then setFromX(i.Position.X) end
	end))
	track(UserInputService.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
	end))

	register(flag, element, value)
	visual()
	if o.Callback then pcall(o.Callback, value) end
	onAccent(function() fill.BackgroundColor3 = Library.Theme.Accent; valLabel.TextColor3 = Library.Theme.Accent end)
	return element
end

----------------------------------------------------------------- DROPDOWN
function Section:AddDropdown(o)
	o = o or {}
	local flag = o.Flag
	local options = o.Options or {}
	local multi = o.Multi and true or false
	local value
	if multi then
		value = {}
		if typeof(o.Default) == "table" then for _, v in ipairs(o.Default) do value[v] = true end end
	else
		value = o.Default or options[1]
	end

	local holder = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 30), Parent = self.Container })
	if o.Text then
		new("TextLabel", {
			BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 13), Font = Library.Font,
			Text = o.Text, TextColor3 = Library.Theme.TextDim, TextSize = Library.FontSize,
			TextXAlignment = Enum.TextXAlignment.Left, Parent = holder,
		})
		holder.Size = UDim2.new(1, 0, 0, 34)
	end
	local btn = new("TextButton", {
		BackgroundColor3 = Library.Theme.Element, Position = UDim2.new(0, 0, 1, -18),
		Size = UDim2.new(1, 0, 0, 18), Font = Library.Font, Text = "", AutoButtonColor = false,
		Parent = holder,
	})
	corner(btn, 3); stroke(btn, Library.Theme.Border, 1); pad(btn, 7, 0, 7, 0)
	local sel = new("TextLabel", {
		BackgroundTransparency = 1, Size = UDim2.new(1, -16, 1, 0), Font = Library.Font,
		Text = "", TextColor3 = Library.Theme.Text, TextSize = Library.FontSize,
		TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = btn,
	})
	local arrow = new("TextLabel", {
		BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.new(0, 12, 1, 0), Font = Library.FontBold, Text = "v",
		TextColor3 = Library.Theme.TextDim, TextSize = 10, Parent = btn,
	})

	local element = {}
	local function currentText()
		if multi then
			local t = {}
			for _, opt in ipairs(options) do if value[opt] then table.insert(t, opt) end end
			return #t > 0 and table.concat(t, ", ") or "None"
		else
			return tostring(value or "None")
		end
	end
	local function visual() sel.Text = currentText() end

	-- popup list (floats on PopupLayer)
	local popup = new("Frame", {
		BackgroundColor3 = Library.Theme.Panel, Visible = false, ZIndex = 60,
		Size = UDim2.new(0, 10, 0, 10), Parent = PopupLayer,
	})
	corner(popup, 4); stroke(popup, Library.Theme.Border, 1)
	local plist = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), ZIndex = 61, Parent = popup })
	pad(plist, 3, 3, 3, 3)
	local pLayout = new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder, Parent = plist })

	local optButtons = {}
	local function rebuild()
		for _, b in ipairs(optButtons) do b:Destroy() end
		table.clear(optButtons)
		for i, opt in ipairs(options) do
			local active = multi and value[opt] or (not multi and value == opt)
			local ob = new("TextButton", {
				BackgroundColor3 = Library.Theme.Element, BackgroundTransparency = active and 0 or 1,
				Size = UDim2.new(1, 0, 0, 18), Font = Library.Font, Text = "  " .. tostring(opt),
				TextColor3 = active and Library.Theme.Accent or Library.Theme.TextDim,
				TextSize = Library.FontSize, TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 62, AutoButtonColor = false, LayoutOrder = i, Parent = plist,
			})
			corner(ob, 3)
			track(ob.MouseEnter:Connect(function() if not (multi and value[opt]) and value ~= opt then ob.BackgroundTransparency = 0.6 end end))
			track(ob.MouseLeave:Connect(function() if not (multi and value[opt]) and value ~= opt then ob.BackgroundTransparency = 1 end end))
			track(ob.MouseButton1Click:Connect(function()
				if multi then
					value[opt] = not value[opt] or nil
				else
					value = opt
					popup.Visible = false
				end
				if flag then Library.Flags[flag] = multi and (function() local t={} for k,v in pairs(value) do if v then t[#t+1]=k end end return t end)() or value end
				visual(); rebuild()
				if o.Callback then pcall(o.Callback, multi and value or value) end
			end))
			table.insert(optButtons, ob)
		end
		local h = #options * 20 + 6
		popup.Size = UDim2.new(0, btn.AbsoluteSize.X, 0, math.min(h, 200))
	end

	track(btn.MouseButton1Click:Connect(function()
		local wasVisible = popup.Visible
		closeAllPopups()
		if not wasVisible then
			rebuild()
			popup.Position = UDim2.fromOffset(btn.AbsolutePosition.X, btn.AbsolutePosition.Y + btn.AbsoluteSize.Y + 2)
			popup.Size = UDim2.new(0, btn.AbsoluteSize.X, 0, math.min(#options * 20 + 6, 200))
			popup.Visible = true
			Library._activePopup = popup
			tween(arrow, 0.1, { Rotation = 180 })
		else
			tween(arrow, 0.1, { Rotation = 0 })
		end
	end))

	function element:Set(v, skip)
		if multi then
			value = {}
			if typeof(v) == "table" then
				-- array of selected OR map
				local isArray = (v[1] ~= nil)
				if isArray then for _, k in ipairs(v) do value[k] = true end
				else for k, on in pairs(v) do if on then value[k] = true end end end
			end
			if flag then local t={} for k,on in pairs(value) do if on then t[#t+1]=k end end Library.Flags[flag]=t end
		else
			value = v
			if flag then Library.Flags[flag] = value end
		end
		visual(); if popup.Visible then rebuild() end
		if not skip and o.Callback then pcall(o.Callback, multi and value or value) end
	end
	function element:Get() return value end
	function element:SetOptions(opts) options = opts or {}; if popup.Visible then rebuild() end end

	register(flag, element, multi and (function() local t={} for k,on in pairs(value) do if on then t[#t+1]=k end end return t end)() or value)
	visual()
	if o.Callback then pcall(o.Callback, multi and value or value) end
	onAccent(function() if popup.Visible then rebuild() end end)
	return element
end

----------------------------------------------------------------- BUTTON
function Section:AddButton(o)
	o = o or {}
	local btn = new("TextButton", {
		BackgroundColor3 = Library.Theme.Element, Size = UDim2.new(1, 0, 0, 20),
		Font = Library.Font, Text = o.Text or "Button", TextColor3 = Library.Theme.Text,
		TextSize = Library.FontSize, AutoButtonColor = false, Parent = self.Container,
	})
	corner(btn, 3); stroke(btn, Library.Theme.Border, 1)
	track(btn.MouseEnter:Connect(function() tween(btn, 0.1, { BackgroundColor3 = Library.Theme.BorderLight }) end))
	track(btn.MouseLeave:Connect(function() tween(btn, 0.1, { BackgroundColor3 = Library.Theme.Element }) end))
	track(btn.MouseButton1Down:Connect(function() btn.TextColor3 = Library.Theme.Accent end))
	track(btn.MouseButton1Up:Connect(function() btn.TextColor3 = Library.Theme.Text end))
	track(btn.MouseButton1Click:Connect(function() if o.Callback then pcall(o.Callback) end end))
	return { Instance = btn, SetText = function(_, t) btn.Text = t end }
end

----------------------------------------------------------------- TEXTBOX
function Section:AddTextbox(o)
	o = o or {}
	local flag = o.Flag
	local holder = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, o.Text and 34 or 20), Parent = self.Container })
	if o.Text then
		new("TextLabel", {
			BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 13), Font = Library.Font,
			Text = o.Text, TextColor3 = Library.Theme.TextDim, TextSize = Library.FontSize,
			TextXAlignment = Enum.TextXAlignment.Left, Parent = holder,
		})
	end
	local box = new("TextBox", {
		BackgroundColor3 = Library.Theme.Element, Position = UDim2.new(0, 0, 1, -18),
		Size = UDim2.new(1, 0, 0, 18), Font = Library.Font, Text = o.Default or "",
		PlaceholderText = o.Placeholder or "...", PlaceholderColor3 = Library.Theme.TextDark,
		TextColor3 = Library.Theme.Text, TextSize = Library.FontSize, ClearTextOnFocus = false,
		TextXAlignment = Enum.TextXAlignment.Left, Parent = holder,
	})
	corner(box, 3); stroke(box, Library.Theme.Border, 1); pad(box, 7, 0, 7, 0)
	local element = {}
	function element:Set(v, skip) box.Text = tostring(v or ""); if flag then Library.Flags[flag] = box.Text end; if not skip and o.Callback then pcall(o.Callback, box.Text) end end
	function element:Get() return box.Text end
	track(box.FocusLost:Connect(function()
		if flag then Library.Flags[flag] = box.Text end
		if o.Callback then pcall(o.Callback, box.Text) end
	end))
	register(flag, element, o.Default or "")
	return element
end

----------------------------------------------------------------- KEYBIND (standalone)
function Section:AddKeybind(o)
	o = o or {}
	local flag = o.Flag
	local stored = o.Default and keyName(o.Default) or "None"
	local row = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 18), Parent = self.Container })
	new("TextLabel", {
		BackgroundTransparency = 1, Size = UDim2.new(1, -70, 1, 0), Font = Library.Font,
		Text = o.Text or "Keybind", TextColor3 = Library.Theme.TextDim, TextSize = Library.FontSize,
		TextXAlignment = Enum.TextXAlignment.Left, Parent = row,
	})
	local pill = new("TextButton", {
		BackgroundColor3 = Library.Theme.Element, AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0, 60, 0, 16), Font = Library.Font,
		Text = "[" .. displayKey(stored) .. "]", TextColor3 = Library.Theme.TextDim, TextSize = 11, Parent = row,
	})
	corner(pill, 3); stroke(pill, Library.Theme.Border, 1)
	local obj = { Key = stored }
	local listening = false
	local function refresh() pill.Text = "[" .. displayKey(obj.Key) .. "]" end
	track(pill.MouseButton1Click:Connect(function() listening = true; pill.Text = "[...]"; pill.TextColor3 = Library.Theme.Accent end))
	track(UserInputService.InputBegan:Connect(function(input)
		if listening then
			local name
			if input.UserInputType == Enum.UserInputType.Keyboard then name = input.KeyCode.Name
			elseif input.UserInputType == Enum.UserInputType.MouseButton2 then name = "MouseButton2"
			elseif input.UserInputType == Enum.UserInputType.MouseButton3 then name = "MouseButton3" end
			if name == "Escape" then name = "None" end
			if name then obj.Key = name; listening = false; pill.TextColor3 = Library.Theme.TextDim; if flag then Library.Flags[flag]=obj.Key end; refresh() end
			return
		end
		if obj.Key ~= "None" then
			local n = (input.KeyCode and input.KeyCode.Name) or (input.UserInputType and input.UserInputType.Name)
			if n == obj.Key and o.Callback then pcall(o.Callback, obj.Key) end
		end
	end))
	local element = { Set = function(_, v) obj.Key = (typeof(v)=="EnumItem" and keyName(v)) or v; if flag then Library.Flags[flag]=obj.Key end; refresh() end, Get = function() return obj.Key end }
	register(flag, element, obj.Key)
	return element
end

----------------------------------------------------------------- COLOR PICKER
-- forward-declared helper used by toggle:AddColorPicker and Section:AddColorPicker
attachColorPicker = function(parent, o)
	o = o or {}
	local flag = o.Flag
	local color = o.Default or Color3.fromRGB(255, 255, 255)
	local alpha = o.Alpha ~= nil and o.Alpha or 1

	local swatch = new("TextButton", {
		BackgroundColor3 = color, Size = UDim2.new(0, 20, 0, 12), Text = "", Parent = parent,
	})
	corner(swatch, 3); stroke(swatch, Library.Theme.Border, 1)

	-- popup picker
	local popup = new("Frame", {
		BackgroundColor3 = Library.Theme.Panel, Visible = false, ZIndex = 70,
		Size = UDim2.new(0, 180, 0, 160), Parent = PopupLayer,
	})
	corner(popup, 5); stroke(popup, Library.Theme.Border, 1); pad(popup, 8, 8, 8, 8)
	local h, s, v = color:ToHSV()

	local svBox = new("ImageButton", {
		Size = UDim2.new(1, -18, 0, 110), Position = UDim2.new(0, 0, 0, 0),
		BackgroundColor3 = Color3.fromHSV(h, 1, 1), ZIndex = 71, AutoButtonColor = false, Parent = popup,
	})
	corner(svBox, 3)
	-- white gradient (saturation) left->right, black gradient (value) top->bottom
	local whiteOv = new("Frame", { BackgroundColor3 = Color3.new(1,1,1), Size = UDim2.new(1,0,1,0), ZIndex = 72, Parent = svBox }); corner(whiteOv,3)
	new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0,0), NumberSequenceKeypoint.new(1,1) }), Parent = whiteOv })
	local blackOv = new("Frame", { BackgroundColor3 = Color3.new(0,0,0), Size = UDim2.new(1,0,1,0), ZIndex = 73, Parent = svBox }); corner(blackOv,3)
	new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0,1), NumberSequenceKeypoint.new(1,0) }), Parent = blackOv })
	local svCursor = new("Frame", { BackgroundColor3 = Color3.new(1,1,1), Size = UDim2.new(0,6,0,6), AnchorPoint = Vector2.new(0.5,0.5), ZIndex = 74, Parent = svBox }); corner(svCursor,3); stroke(svCursor, Color3.new(0,0,0),1)

	local hueBar = new("ImageButton", {
		Size = UDim2.new(0, 12, 0, 110), Position = UDim2.new(1, -12, 0, 0),
		BackgroundColor3 = Color3.new(1,1,1), ZIndex = 71, AutoButtonColor = false, Parent = popup,
	})
	corner(hueBar, 3)
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255,0,0)),
		ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255,255,0)),
		ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0,255,0)),
		ColorSequenceKeypoint.new(0.50, Color3.fromRGB(0,255,255)),
		ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0,0,255)),
		ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255,0,255)),
		ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255,0,0)),
	}), Parent = hueBar })
	local hueCursor = new("Frame", { BackgroundColor3 = Color3.new(1,1,1), Size = UDim2.new(1,0,0,2), AnchorPoint = Vector2.new(0,0.5), ZIndex = 74, Parent = hueBar }); stroke(hueCursor, Color3.new(0,0,0),1)

	local hexBox = new("TextBox", {
		BackgroundColor3 = Library.Theme.Element, Position = UDim2.new(0,0,1,-18), Size = UDim2.new(1,0,0,18),
		Font = Library.Font, Text = "", TextColor3 = Library.Theme.Text, TextSize = 11,
		ClearTextOnFocus = false, ZIndex = 72, Parent = popup,
	})
	corner(hexBox, 3); stroke(hexBox, Library.Theme.Border, 1); pad(hexBox, 6,0,6,0)

	local element = {}
	local function toHex(c) return string.format("#%02X%02X%02X", c.R*255, c.G*255, c.B*255) end
	local function updateVisual()
		color = Color3.fromHSV(h, s, v)
		swatch.BackgroundColor3 = color
		svBox.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
		svCursor.Position = UDim2.new(s, 0, 1 - v, 0)
		hueCursor.Position = UDim2.new(0, 0, h, 0)
		hexBox.Text = toHex(color)
		if flag then Library.Flags[flag] = color end
	end
	function element:Set(c, skip)
		if typeof(c) == "Color3" then color = c; h, s, v = c:ToHSV() end
		updateVisual()
		if not skip and o.Callback then pcall(o.Callback, color, alpha) end
	end
	function element:Get() return color, alpha end

	local function pickSV(px, py)
		s = clamp((px - svBox.AbsolutePosition.X) / svBox.AbsoluteSize.X, 0, 1)
		v = 1 - clamp((py - svBox.AbsolutePosition.Y) / svBox.AbsoluteSize.Y, 0, 1)
		updateVisual(); if o.Callback then pcall(o.Callback, color, alpha) end
	end
	local function pickHue(py)
		h = clamp((py - hueBar.AbsolutePosition.Y) / hueBar.AbsoluteSize.Y, 0, 0.9999)
		updateVisual(); if o.Callback then pcall(o.Callback, color, alpha) end
	end
	local dragSV, dragHue = false, false
	track(svBox.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then dragSV=true; pickSV(i.Position.X,i.Position.Y) end end))
	track(hueBar.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then dragHue=true; pickHue(i.Position.Y) end end))
	track(UserInputService.InputChanged:Connect(function(i)
		if i.UserInputType==Enum.UserInputType.MouseMovement then
			if dragSV then pickSV(i.Position.X,i.Position.Y) end
			if dragHue then pickHue(i.Position.Y) end
		end
	end))
	track(UserInputService.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then dragSV=false; dragHue=false end end))
	track(hexBox.FocusLost:Connect(function()
		local hex = hexBox.Text:gsub("#","")
		if #hex == 6 then
			local r = tonumber(hex:sub(1,2),16); local g = tonumber(hex:sub(3,4),16); local b = tonumber(hex:sub(5,6),16)
			if r and g and b then element:Set(Color3.fromRGB(r,g,b)) end
		end
	end))
	track(swatch.MouseButton1Click:Connect(function()
		local was = popup.Visible
		closeAllPopups()
		if not was then
			popup.Position = UDim2.fromOffset(
				clamp(swatch.AbsolutePosition.X - 160, 10, workspace.CurrentCamera.ViewportSize.X - 190),
				swatch.AbsolutePosition.Y + 18)
			popup.Visible = true; Library._activePopup = popup
		end
	end))

	if flag then register(flag, element, color) end
	updateVisual()
	if o.Callback then pcall(o.Callback, color, alpha) end
	return element
end
-- Section-level standalone color picker (label + swatch on one row)
function Section:AddColorPicker(o)
	o = o or {}
	local row = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 18), Parent = self.Container })
	new("TextLabel", {
		BackgroundTransparency = 1, Size = UDim2.new(1, -30, 1, 0), Font = Library.Font,
		Text = o.Text or "Color", TextColor3 = Library.Theme.TextDim, TextSize = Library.FontSize,
		TextXAlignment = Enum.TextXAlignment.Left, Parent = row,
	})
	local slot = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1,0.5), Position = UDim2.new(1,0,0.5,0), Size = UDim2.new(0,24,1,0), Parent = row })
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right, VerticalAlignment = Enum.VerticalAlignment.Center, Parent = slot })
	return attachColorPicker(slot, o)
end

--==================================================================================
--  TAB  (sidebar entry + two-column page)
--==================================================================================
local Tab = {}
Tab.__index = Tab

function Tab:AddSection(title, side)
	side = (side == "Right") and "Right" or "Left"
	local parent = side == "Right" and self.RightCol or self.LeftCol

	local sec = new("Frame", {
		BackgroundColor3 = Library.Theme.Section, Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y, Parent = parent,
	})
	corner(sec, 5); stroke(sec, Library.Theme.Border, 1)
	-- title
	local header = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 24), Parent = sec })
	new("Frame", { BackgroundColor3 = Library.Theme.Accent, Size = UDim2.new(0, 2, 0, 11),
		Position = UDim2.new(0, 10, 0.5, -5), BorderSizePixel = 0, Parent = header })
	new("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.new(0, 18, 0, 0), Size = UDim2.new(1, -26, 1, 0),
		Font = Library.FontBold, Text = title or "Section", TextColor3 = Library.Theme.Text,
		TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, Parent = header,
	})
	new("Frame", { BackgroundColor3 = Library.Theme.Border, Size = UDim2.new(1, 0, 0, 1),
		Position = UDim2.new(0, 0, 0, 24), BorderSizePixel = 0, Parent = sec })

	local container = new("Frame", {
		BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 25), Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y, Parent = sec,
	})
	pad(container, 12, 8, 12, 10); vlist(container, 7)

	local s = setmetatable({ Frame = sec, Container = container, Window = self.Window }, Section)
	return s
end

--==================================================================================
--  WINDOW
--==================================================================================
local Window = {}
Window.__index = Window

function Window:AddTab(name, iconText)
	-- sidebar button
	local btn = new("TextButton", {
		BackgroundColor3 = Library.Theme.Element, BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 34), Font = Library.FontBold, Text = iconText or string.sub(name,1,1),
		TextColor3 = Library.Theme.TextDim, TextSize = 14, AutoButtonColor = false,
		Parent = self.TabBar,
	})
	corner(btn, 5)
	local ind = new("Frame", {
		BackgroundColor3 = Library.Theme.Accent, Size = UDim2.new(0, 2, 0.6, 0),
		Position = UDim2.new(0, 0, 0.2, 0), BorderSizePixel = 0, Visible = false, Parent = btn,
	})

	-- page
	local page = new("ScrollingFrame", {
		BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Visible = false,
		CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 3, ScrollBarImageColor3 = Library.Theme.BorderLight,
		BorderSizePixel = 0, Parent = self.Pages,
	})
	pad(page, 0, 0, 4, 10)
	local cols = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = page })
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder, Parent = cols })
	local leftCol = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(0.5, -4, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = cols })
	vlist(leftCol, 8)
	local rightCol = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(0.5, -4, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = cols })
	vlist(rightCol, 8)

	local tab = setmetatable({
		Window = self, Button = btn, Page = page, LeftCol = leftCol, RightCol = rightCol, Indicator = ind,
	}, Tab)

	local function select()
		for _, t in ipairs(self.Tabs) do
			t.Page.Visible = false
			t.Button.BackgroundTransparency = 1
			t.Button.TextColor3 = Library.Theme.TextDim
			t.Indicator.Visible = false
		end
		page.Visible = true
		btn.BackgroundTransparency = 0
		btn.BackgroundColor3 = Library.Theme.Element
		btn.TextColor3 = Library.Theme.Accent
		ind.Visible = true
		self.ActiveTab = tab
	end
	tab.Select = select
	track(btn.MouseButton1Click:Connect(select))
	track(btn.MouseEnter:Connect(function() if self.ActiveTab ~= tab then btn.TextColor3 = Library.Theme.Text end end))
	track(btn.MouseLeave:Connect(function() if self.ActiveTab ~= tab then btn.TextColor3 = Library.Theme.TextDim end end))

	table.insert(self.Tabs, tab)
	if #self.Tabs == 1 then select() end
	return tab
end

function Window:SetToggleKey(k)
	self.ToggleKey = typeof(k) == "EnumItem" and k.Name or k
	if self._tkLabel then self._tkLabel.Text = "[" .. displayKey(self.ToggleKey) .. "] menu" end
end

-- a ready-made Config tab
function Window:AddConfigTab()
	local tab = self:AddTab("Config", "⚙")
	local left = tab:AddSection("Configs", "Left")
	local right = tab:AddSection("Transfer", "Right")

	local selected = nil
	local dd = left:AddDropdown({ Text = "Config list", Flag = nil, Options = Library:ListConfigs(),
		Callback = function(v) selected = v end })
	local nameBox = left:AddTextbox({ Text = "Config name", Placeholder = "my_config" })

	local function refresh() dd:SetOptions(Library:ListConfigs()) end

	left:AddButton({ Text = "Create / Save", Callback = function()
		local nm = nameBox:Get(); if nm == "" then nm = selected end
		if not nm or nm == "" then Library:Notify({ Title = "Config", Text = "Enter a name first." }); return end
		Library:SaveConfig(nm); refresh(); dd:Set(nm)
		Library:Notify({ Title = "Config", Text = "Saved '" .. nm .. "'." })
	end })
	left:AddButton({ Text = "Load selected", Callback = function()
		if not selected then Library:Notify({ Title = "Config", Text = "Select a config." }); return end
		local ok = Library:LoadConfig(selected)
		Library:Notify({ Title = "Config", Text = ok and ("Loaded '" .. selected .. "'.") or "Load failed." })
	end })
	left:AddButton({ Text = "Delete selected", Callback = function()
		if not selected then return end
		Library:DeleteConfig(selected); refresh()
		Library:Notify({ Title = "Config", Text = "Deleted '" .. selected .. "'." })
	end })
	left:AddButton({ Text = "Refresh list", Callback = refresh })

	right:AddButton({ Text = "Export -> clipboard", Callback = function()
		local b64 = Library:ExportConfig(nameBox:Get() ~= "" and nameBox:Get() or nil)
		Library:Notify({ Title = "Config", Text = "Exported (" .. #b64 .. " chars) to clipboard." })
	end })
	local importBox = right:AddTextbox({ Text = "Import string (base64)", Placeholder = "paste here" })
	right:AddButton({ Text = "Import from string", Callback = function()
		local ok, err = Library:ImportConfig(importBox:Get())
		Library:Notify({ Title = "Config", Text = ok and "Imported config." or ("Import failed: " .. tostring(err)) })
	end })
	right:AddLabel("Autoload applies a config on next launch.")
	right:AddToggle({ Text = "Autoload selected config", Flag = "cfg_autoload" })

	return tab
end

--==================================================================================
--  CREATE WINDOW
--==================================================================================
function Library:CreateWindow(opts)
	opts = opts or {}
	if opts.Accent then self.Theme.Accent = opts.Accent end
	local size = opts.Size or Vector2.new(560, 460)

	local root = new("Frame", {
		Name = "Window", BackgroundColor3 = self.Theme.Window,
		Size = UDim2.fromOffset(size.X, size.Y),
		Position = UDim2.new(0.5, -size.X/2, 0.5, -size.Y/2),
		Visible = self.Open, Active = true, Parent = ScreenGui,
	})
	corner(root, 7); stroke(root, self.Theme.Border, 1)

	-- outer glow border (accent-tinted)
	local glow = stroke(root, self.Theme.Accent, 1, 0.55)
	onAccent(function() glow.Color = self.Theme.Accent end)

	-- top rainbow strip (animated)
	local strip = new("Frame", {
		BackgroundColor3 = Color3.new(1,1,1), BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 2), Position = UDim2.new(0, 0, 0, 0), ZIndex = 5, Parent = root,
	})
	new("UICorner", { CornerRadius = UDim.new(0, 2), Parent = strip })
	local stripGrad = new("UIGradient", { Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0.0, Color3.fromRGB(255,80,80)),
		ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255,220,80)),
		ColorSequenceKeypoint.new(0.5, self.Theme.Accent),
		ColorSequenceKeypoint.new(0.75, Color3.fromRGB(80,200,255)),
		ColorSequenceKeypoint.new(1.0, Color3.fromRGB(200,120,255)),
	}), Parent = strip })
	track(RunService.Heartbeat:Connect(function()
		if self.Unloaded then return end
		stripGrad.Offset = Vector2.new((tick() * 0.15) % 1, 0)
	end))

	-- title bar (drag handle)
	local titleBar = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 30), Position = UDim2.new(0,0,0,2), Parent = root })
	new("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.new(0, 14, 0, 0), Size = UDim2.new(0.5, 0, 1, 0),
		Font = self.FontBold, Text = opts.Title or "gamesense", TextColor3 = self.Theme.Text,
		TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, Parent = titleBar,
	})
	local tkLabel = new("TextLabel", {
		BackgroundTransparency = 1, AnchorPoint = Vector2.new(1,0.5), Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.new(0, 120, 1, 0), Font = self.Font, Text = "[RShift] menu",
		TextColor3 = self.Theme.TextDark, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Right, Parent = titleBar,
	})
	new("Frame", { BackgroundColor3 = self.Theme.Border, BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 0, 32), Parent = root })

	-- sidebar
	local sidebar = new("Frame", {
		BackgroundColor3 = self.Theme.Panel, BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 0, 33), Size = UDim2.new(0, 54, 1, -33), Parent = root,
	})
	new("Frame", { BackgroundColor3 = self.Theme.Border, BorderSizePixel = 0,
		Size = UDim2.new(0, 1, 1, 0), Position = UDim2.new(1, 0, 0, 0), Parent = sidebar })
	local tabBar = new("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0, 8, 0, 10), Size = UDim2.new(1, -16, 1, -20), Parent = sidebar })
	vlist(tabBar, 6, Enum.HorizontalAlignment.Center)

	-- content area
	local content = new("Frame", {
		BackgroundTransparency = 1, Position = UDim2.new(0, 62, 0, 40), Size = UDim2.new(1, -70, 1, -48), Parent = root,
	})
	local pages = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Parent = content })

	local w = setmetatable({
		Root = root, TabBar = tabBar, Pages = pages, Tabs = {}, ActiveTab = nil,
		ToggleKey = (opts.ToggleKey and (typeof(opts.ToggleKey)=="EnumItem" and opts.ToggleKey.Name or opts.ToggleKey)) or "RightShift",
		_tkLabel = tkLabel,
	}, Window)
	w:SetToggleKey(w.ToggleKey)
	table.insert(self.Windows, w)

	-- dragging
	local dragging, dragStart, startPos = false, nil, nil
	track(titleBar.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true; dragStart = i.Position; startPos = root.Position
		end
	end))
	track(UserInputService.InputChanged:Connect(function(i)
		if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
			local d = i.Position - dragStart
			root.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end))
	track(UserInputService.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
	end))

	-- intro tween
	root.Size = UDim2.fromOffset(size.X, size.Y - 20)
	tween(root, 0.2, { Size = UDim2.fromOffset(size.X, size.Y) })

	return w
end

--==================================================================================
--  GLOBAL INPUT:  toggle key + popup dismissal
--==================================================================================
track(UserInputService.InputBegan:Connect(function(input, gpe)
	if Library.Unloaded then return end
	-- menu toggle
	for _, w in ipairs(Library.Windows) do
		local key = w.ToggleKey
		local n = (input.KeyCode and input.KeyCode.Name) or (input.UserInputType and input.UserInputType.Name)
		if n == key and not gpe then
			Library:Toggle()
			break
		end
	end
	-- click outside popup closes it
	if input.UserInputType == Enum.UserInputType.MouseButton1 and Library._activePopup then
		local p = Library._activePopup
		local mp = input.Position
		local pos, sz = p.AbsolutePosition, p.AbsoluteSize
		local inside = mp.X >= pos.X and mp.X <= pos.X + sz.X and mp.Y >= pos.Y and mp.Y <= pos.Y + sz.Y
		if not inside then
			task.defer(function()
				-- allow the triggering button's own handler to run first
				if Library._activePopup == p then closeAllPopups() end
			end)
		end
	end
end))

return Library
