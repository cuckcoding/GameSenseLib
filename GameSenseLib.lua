--[[
	GameSenseLib v2  —  a modern Roblox UI library (Luau / executors)
	Design language inspired by Linoria / Obsidian: left icon+label tab rail,
	titled groupboxes in two columns, rounded panels, drop shadow, Lucide icons,
	and a full config system (save / load / export / import).

	Reference only — not a copy of any menu.

	--------------------------------------------------------------------------------------
	QUICK START
	--------------------------------------------------------------------------------------
		local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/cuckcoding/GameSenseLib/main/GameSenseLib.lua"))()

		local Window = Library:CreateWindow({ Title = "gamesense", Accent = Color3.fromRGB(114,132,255) })

		local Rage = Window:AddTab("Rage", "crosshair")        -- 2nd arg = Lucide icon name
		local Aim  = Rage:AddGroupbox("Aimbot", "Left")        -- (AddSection is an alias)

		Aim:AddToggle({ Text = "Enabled", Flag = "aim_enabled", Default = true })
		   :AddKeybind({ Flag = "aim_key", Default = "MouseButton2", Mode = "Hold" })
		Aim:AddSlider({ Text = "Maximum FOV", Flag = "aim_fov", Min = 0, Max = 180, Default = 10, Suffix = "°" })

		Window:AddConfigTab()

	Lucide icon names bundled: crosshair, eye, settings, wrench, save, folder, user, zap,
	target, sword, sliders, palette, cpu, shield, home, menu, star, bell. You can also pass
	a raw "rbxassetid://123" string, or nil to fall back to the tab's first letter.
]]

--==================================================================================
--  SERVICES
--==================================================================================
local Players           = game:GetService("Players")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")
local RunService        = game:GetService("RunService")
local HttpService       = game:GetService("HttpService")
local CoreGui           = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer

local _writefile  = writefile
local _readfile   = readfile
local _isfile     = isfile
local _isfolder   = isfolder
local _makefolder = makefolder
local _listfiles  = listfiles
local _delfile    = delfile
local _gethui     = gethui
local _setclip    = (setclipboard or toclipboard or (syn and syn.write_clipboard))
local _protectgui = (protectgui or (syn and syn.protect_gui) or function() end)

local HAS_FS = (typeof(_writefile) == "function" and typeof(_readfile) == "function")

--==================================================================================
--  LUCIDE ICONS (verbatim 48px crops from latte-soft/lucide-roblox)
--==================================================================================
local ICONS = {
	crosshair = { 16898613044, {48,48}, {453,869} },
	eye       = { 16898613353, {48,48}, {771,563} },
	settings  = { 16898613777, {48,48}, {771,257} },
	wrench    = { 16898613869, {48,48}, {820,906} },
	save      = { 16898613699, {48,48}, {918,453} },
	folder    = { 16898613353, {48,48}, {404,967} },
	user      = { 16898613869, {48,48}, {661,869} },
	zap       = { 16898613869, {48,48}, {918,906} },
}
-- a few friendly aliases -> bundled icons (so common names still resolve)
local ICON_ALIAS = {
	target = "crosshair", aim = "crosshair", rage = "crosshair",
	sword = "zap", combat = "zap", legit = "zap",
	sliders = "settings", config = "settings", gear = "settings",
	visuals = "eye", esp = "eye", vision = "eye",
	misc = "wrench", tools = "wrench", world = "wrench",
	players = "user", player = "user", account = "user",
	home = "folder", files = "folder", configs = "folder",
}

--==================================================================================
--  LIBRARY TABLE / THEME
--==================================================================================
local Library = {
	Flags        = {},
	Registry     = {},
	Connections  = {},
	Windows      = {},
	Open         = true,
	Unloaded     = false,
	ConfigFolder = "GameSenseLib",
	Theme = {
		Accent      = Color3.fromRGB(114, 132, 255),  -- modern indigo-blue
		AccentDim   = Color3.fromRGB(78, 92, 190),
		Window      = Color3.fromRGB(21, 21, 26),
		Sidebar     = Color3.fromRGB(16, 16, 20),
		Groupbox    = Color3.fromRGB(27, 27, 33),
		Element     = Color3.fromRGB(35, 35, 43),
		ElementDark = Color3.fromRGB(15, 15, 19),
		Border      = Color3.fromRGB(10, 10, 13),
		BorderLight = Color3.fromRGB(50, 50, 60),
		Text        = Color3.fromRGB(236, 236, 242),
		TextDim     = Color3.fromRGB(150, 150, 162),
		TextDark    = Color3.fromRGB(96, 96, 108),
	},
	Font       = Enum.Font.Gotham,
	FontMedium = Enum.Font.GothamMedium,
	FontBold   = Enum.Font.GothamBold,
	FontSize   = 13,
}

--==================================================================================
--  UTILITIES
--==================================================================================
local function track(c) table.insert(Library.Connections, c); return c end

local function new(class, props, children)
	local inst = Instance.new(class)
	if props then for k, v in pairs(props) do if k ~= "Parent" then inst[k] = v end end end
	if children then for _, c in ipairs(children) do c.Parent = inst end end
	if props and props.Parent then inst.Parent = props.Parent end
	return inst
end
local function corner(p, r) return new("UICorner", { CornerRadius = UDim.new(0, r or 6), Parent = p }) end
local function stroke(p, c, t, tr) return new("UIStroke", { Color = c or Library.Theme.Border, Thickness = t or 1, Transparency = tr or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = p }) end
local function pad(p, l, t, r, b) return new("UIPadding", { PaddingLeft = UDim.new(0,l or 0), PaddingTop = UDim.new(0,t or 0), PaddingRight = UDim.new(0,r or 0), PaddingBottom = UDim.new(0,b or 0), Parent = p }) end
local function vlist(p, g, align) return new("UIListLayout", { Padding = UDim.new(0, g or 8), FillDirection = Enum.FillDirection.Vertical, SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = align or Enum.HorizontalAlignment.Left, Parent = p }) end
local function tween(i, t, props) local tw = TweenService:Create(i, TweenInfo.new(t or 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props); tw:Play(); return tw end
local function round(n, d) local m = 10 ^ (d or 0); return math.floor(n * m + 0.5) / m end
local function clamp(n, lo, hi) return math.max(lo, math.min(hi, n)) end

local function resolveIcon(name)
	if typeof(name) ~= "string" or name == "" then return nil end
	if name:match("^rbxassetid://") or name:match("^http") then
		return { Image = name }
	end
	local key = name:lower()
	local d = ICONS[key] or (ICON_ALIAS[key] and ICONS[ICON_ALIAS[key]])
	if d then
		return { Image = "rbxassetid://" .. d[1], RectSize = Vector2.new(d[2][1], d[2][2]), RectOffset = Vector2.new(d[3][1], d[3][2]) }
	end
	return nil
end

-- Base64 for config export/import
local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local function base64Encode(data)
	return ((data:gsub('.', function(x) local r,b='',x:byte(); for i=8,1,-1 do r=r..(b%2^i-b%2^(i-1)>0 and '1' or '0') end return r end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x) if #x<6 then return '' end local c=0; for i=1,6 do c=c+(x:sub(i,i)=='1' and 2^(6-i) or 0) end return B64:sub(c+1,c+1) end)..({'','==','='})[#data%3+1])
end
local function base64Decode(data)
	data = string.gsub(data, '[^'..B64..'=]', '')
	return (data:gsub('.', function(x) if x=='=' then return '' end local r,f='',(B64:find(x)-1); for i=6,1,-1 do r=r..(f%2^i-f%2^(i-1)>0 and '1' or '0') end return r end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x) if #x~=8 then return '' end local c=0; for i=1,8 do c=c+(x:sub(i,i)=='1' and 2^(8-i) or 0) end return string.char(c) end))
end
local function encColor(c) return { __color = true, R = round(c.R*255,0), G = round(c.G*255,0), B = round(c.B*255,0) } end
local function isEncColor(v) return typeof(v) == "table" and v.__color end
local function decColor(v) return Color3.fromRGB(v.R, v.G, v.B) end

-- accent listeners
Library._accentListeners = {}
local function onAccent(fn) table.insert(Library._accentListeners, fn); fn(Library.Theme.Accent) end

--==================================================================================
--  GUI ROOT
--==================================================================================
local ScreenGui = new("ScreenGui", {
	Name = "GameSenseLib_" .. tostring(math.random(10000, 99999)),
	ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = 99999, IgnoreGuiInset = true,
})
do
	local ok = false
	if typeof(_gethui) == "function" then ok = pcall(function() ScreenGui.Parent = _gethui() end) end
	if not ok then ok = pcall(function() _protectgui(ScreenGui); ScreenGui.Parent = CoreGui end) end
	if not ok then pcall(function() ScreenGui.Parent = CoreGui end) end
	if not ScreenGui.Parent then ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end
end
Library.ScreenGui = ScreenGui

local PopupLayer = new("Frame", { Name = "PopupLayer", BackgroundTransparency = 1, Size = UDim2.fromScale(1,1), ZIndex = 500, Parent = ScreenGui })
local function closeAllPopups()
	for _, c in ipairs(PopupLayer:GetChildren()) do c.Visible = false end
	Library._activePopup = nil
end

--==================================================================================
--  CONFIG FS HELPERS
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
local function configPath(name) return Library.ConfigFolder .. "/configs/" .. name .. ".json" end

--==================================================================================
--  KEY HELPERS
--==================================================================================
local KeyDisplay = {
	MouseButton1="MB1", MouseButton2="MB2", MouseButton3="MB3",
	LeftControl="CTRL", RightControl="RCTRL", LeftShift="SHIFT", RightShift="RSHIFT",
	LeftAlt="ALT", RightAlt="RALT",
}
local function keyName(input)
	if input == nil then return "None" end
	if typeof(input) == "EnumItem" then return KeyDisplay[input.Name] or input.Name end
	return tostring(input)
end
local function displayKey(s) if not s or s == "None" then return "None" end return KeyDisplay[s] or s end

--==================================================================================
--  LIBRARY METHODS
--==================================================================================
function Library:SetAccent(color)
	self.Theme.Accent = color
	self.Theme.AccentDim = Color3.fromRGB(color.R*255*0.68, color.G*255*0.68, color.B*255*0.68)
	for _, fn in ipairs(self._accentListeners) do pcall(fn, color) end
end
function Library:GetFlag(f) return self.Flags[f] end
function Library:SetFlag(f, v) local e = self.Registry[f]; if e and e.Set then e:Set(v) else self.Flags[f] = v end end

function Library:Toggle(state)
	if state == nil then state = not self.Open end
	self.Open = state
	for _, w in ipairs(self.Windows) do if w.Root then w.Root.Visible = state end end
	if not state then closeAllPopups() end
end

function Library:Notify(opts)
	opts = opts or {}
	local holder = ScreenGui:FindFirstChild("Notifications")
	if not holder then
		holder = new("Frame", { Name = "Notifications", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1,1), Position = UDim2.new(1,-14,1,-14), Size = UDim2.new(0,280,1,-28), ZIndex = 600, Parent = ScreenGui })
		new("UIListLayout", { Padding = UDim.new(0,8), VerticalAlignment = Enum.VerticalAlignment.Bottom, HorizontalAlignment = Enum.HorizontalAlignment.Right, SortOrder = Enum.SortOrder.LayoutOrder, Parent = holder })
	end
	local card = new("Frame", { BackgroundColor3 = self.Theme.Groupbox, Size = UDim2.new(1,0,0,0), AutomaticSize = Enum.AutomaticSize.Y, ClipsDescendants = true, ZIndex = 601, Parent = holder })
	corner(card, 7); stroke(card, self.Theme.Border, 1)
	local accentBar = new("Frame", { BackgroundColor3 = self.Theme.Accent, Size = UDim2.new(0,3,1,0), BorderSizePixel = 0, ZIndex = 602, Parent = card }); corner(accentBar, 2)
	onAccent(function() accentBar.BackgroundColor3 = self.Theme.Accent end)
	local inner = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1,0,1,0), ZIndex = 602, Parent = card }); pad(inner, 14, 9, 11, 9); vlist(inner, 2)
	new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(1,0,0,15), Font = self.FontBold, Text = opts.Title or "Notification", TextColor3 = self.Theme.Text, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 603, Parent = inner })
	if opts.Text then
		new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(1,0,0,14), Font = self.Font, Text = opts.Text, TextColor3 = self.Theme.TextDim, TextSize = 12, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 603, Parent = inner })
	end
	card.BackgroundTransparency = 1; tween(card, 0.2, { BackgroundTransparency = 0 })
	task.delay(opts.Duration or 4, function() if card and card.Parent then tween(card, 0.22, { BackgroundTransparency = 1 }); task.wait(0.24); card:Destroy() end end)
end

function Library:Unload()
	self.Unloaded = true
	for _, c in ipairs(self.Connections) do pcall(function() c:Disconnect() end) end
	table.clear(self.Connections)
	pcall(function() ScreenGui:Destroy() end)
end

-- config serialize/apply
local function serializeFlags()
	local out = {}
	for flag, value in pairs(Library.Flags) do
		if typeof(value) == "Color3" then out[flag] = encColor(value)
		elseif typeof(value) == "EnumItem" then out[flag] = { __enum = tostring(value) }
		else out[flag] = value end
	end
	return out
end
local function applyFlags(data)
	for flag, value in pairs(data) do
		if isEncColor(value) then value = decColor(value) end
		local el = Library.Registry[flag]
		if el and el.Set then pcall(function() el:Set(value) end) else Library.Flags[flag] = value end
	end
end
function Library:SaveConfig(name)
	if not name or name == "" then return false, "no name" end
	local json = HttpService:JSONEncode(serializeFlags())
	if HAS_FS then ensureFolder(); local ok, err = pcall(function() _writefile(configPath(name), json) end); if not ok then return false, tostring(err) end end
	self._memConfigs = self._memConfigs or {}; self._memConfigs[name] = json
	return true
end
function Library:LoadConfig(name)
	local json
	if HAS_FS and _isfile and pcall(function() return _isfile(configPath(name)) end) and _isfile(configPath(name)) then json = _readfile(configPath(name))
	elseif self._memConfigs and self._memConfigs[name] then json = self._memConfigs[name] end
	if not json then return false, "not found" end
	local ok, data = pcall(function() return HttpService:JSONDecode(json) end)
	if not ok then return false, "decode error" end
	applyFlags(data); return true
end
function Library:DeleteConfig(name)
	if HAS_FS and _delfile and _isfile and _isfile(configPath(name)) then pcall(function() _delfile(configPath(name)) end) end
	if self._memConfigs then self._memConfigs[name] = nil end
	return true
end
function Library:ListConfigs()
	local list, seen = {}, {}
	if HAS_FS and _listfiles then
		ensureFolder()
		local ok, files = pcall(function() return _listfiles(self.ConfigFolder .. "/configs") end)
		if ok and files then for _, f in ipairs(files) do local n = tostring(f):match("([^/\\]+)%.json$"); if n and not seen[n] then seen[n]=true; table.insert(list, n) end end end
	end
	if self._memConfigs then for n in pairs(self._memConfigs) do if not seen[n] then seen[n]=true; table.insert(list, n) end end end
	table.sort(list); return list
end
function Library:ExportConfig(name)
	local json
	if name then self:SaveConfig(name); json = self._memConfigs and self._memConfigs[name] end
	json = json or HttpService:JSONEncode(serializeFlags())
	local b64 = base64Encode(json)
	if _setclip then pcall(function() _setclip(b64) end) end
	return b64
end
function Library:ImportConfig(str)
	if not str or str == "" then return false, "empty" end
	local ok, json = pcall(function() return base64Decode(str) end); if not ok then return false, "bad base64" end
	local ok2, data = pcall(function() return HttpService:JSONDecode(json) end); if not ok2 then return false, "bad json" end
	applyFlags(data); return true
end

--==================================================================================
--  GROUPBOX (elements live here)
--==================================================================================
local Groupbox = {}
Groupbox.__index = Groupbox

local attachColorPicker  -- forward decl

local function register(flag, element, defaultValue)
	if flag == nil then return end
	Library.Registry[flag] = element
	if Library.Flags[flag] == nil then Library.Flags[flag] = defaultValue end
end

----------------------------------------------------------------- LABEL / DIVIDER
function Groupbox:AddLabel(text)
	local lbl = new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(1,0,0,16), Font = Library.Font, Text = text or "", TextColor3 = Library.Theme.TextDim, TextSize = Library.FontSize, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, Parent = self.Container })
	return { SetText = function(_, t) lbl.Text = t end, Instance = lbl }
end
function Groupbox:AddDivider()
	local h = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1,0,0,5), Parent = self.Container })
	new("Frame", { BackgroundColor3 = Library.Theme.BorderLight, BorderSizePixel = 0, Size = UDim2.new(1,0,0,1), Position = UDim2.new(0,0,0.5,0), Parent = h })
	return {}
end

----------------------------------------------------------------- TOGGLE
function Groupbox:AddToggle(o)
	o = o or {}
	local flag, state = o.Flag, (o.Default and true or false)
	local row = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1,0,0,19), Parent = self.Container })
	local box = new("Frame", { BackgroundColor3 = Library.Theme.ElementDark, Size = UDim2.new(0,16,0,16), Position = UDim2.new(0,0,0.5,-8), Parent = row })
	corner(box, 5); local bStroke = stroke(box, Library.Theme.BorderLight, 1)
	local check = new("ImageLabel", { BackgroundTransparency = 1, Size = UDim2.new(1,-5,1,-5), Position = UDim2.fromScale(0.5,0.5), AnchorPoint = Vector2.new(0.5,0.5), Image = "rbxassetid://"..ICONS.eye[1], ImageTransparency = 1, Parent = box })
	-- (use a filled accent box, Linoria-style — the check image stays hidden; fill is the indicator)
	local label = new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.new(0,24,0,0), Size = UDim2.new(1,-24,1,0), Font = Library.Font, Text = o.Text or "Toggle", TextColor3 = state and Library.Theme.Text or Library.Theme.TextDim, TextSize = Library.FontSize, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
	local rightSlot = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1,0.5), Position = UDim2.new(1,0,0.5,0), Size = UDim2.new(0,90,1,0), Parent = row })
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0,5), HorizontalAlignment = Enum.HorizontalAlignment.Right, VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Parent = rightSlot })

	local element = {}
	local function visual()
		tween(box, 0.13, { BackgroundColor3 = state and Library.Theme.Accent or Library.Theme.ElementDark })
		bStroke.Color = state and Library.Theme.Accent or Library.Theme.BorderLight
		label.TextColor3 = state and Library.Theme.Text or Library.Theme.TextDim
	end
	function element:Set(v, skip) state = v and true or false; if flag then Library.Flags[flag] = state end; visual(); if not skip and o.Callback then pcall(o.Callback, state) end end
	function element:Get() return state end
	function element:SetText(t) label.Text = t end

	local btn = new("TextButton", { BackgroundTransparency = 1, Text = "", Size = UDim2.new(1,-92,1,0), Parent = row })
	track(btn.MouseButton1Click:Connect(function() element:Set(not state) end))
	track(box.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then element:Set(not state) end end))
	track(btn.MouseEnter:Connect(function() if not state then bStroke.Color = Library.Theme.TextDark end end))
	track(btn.MouseLeave:Connect(function() if not state then bStroke.Color = Library.Theme.BorderLight end end))

	register(flag, element, state); visual()
	if o.Callback and state then pcall(o.Callback, state) end
	onAccent(function() if state then box.BackgroundColor3 = Library.Theme.Accent; bStroke.Color = Library.Theme.Accent end end)

	function element:AddKeybind(k)
		k = k or {}
		local kFlag = k.Flag
		local stored = k.Default and keyName(k.Default) or "None"
		local obj = { Mode = k.Mode or "Toggle", Key = stored }
		local pill = new("TextButton", { BackgroundColor3 = Library.Theme.ElementDark, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0,0,0,16), Font = Library.FontMedium, Text = "["..displayKey(stored).."]", TextColor3 = Library.Theme.TextDim, TextSize = 11, Parent = rightSlot })
		corner(pill, 4); pad(pill, 6, 0, 6, 0); stroke(pill, Library.Theme.Border, 1)
		local function refresh() pill.Text = "["..displayKey(obj.Key).."]" end
		local listening = false
		track(pill.MouseButton1Click:Connect(function() listening = true; pill.Text = "[ ... ]"; pill.TextColor3 = Library.Theme.Accent end))
		track(UserInputService.InputBegan:Connect(function(input)
			if listening then
				local name
				if input.UserInputType == Enum.UserInputType.Keyboard then name = input.KeyCode.Name
				elseif input.UserInputType == Enum.UserInputType.MouseButton1 then name = "MouseButton1"
				elseif input.UserInputType == Enum.UserInputType.MouseButton2 then name = "MouseButton2"
				elseif input.UserInputType == Enum.UserInputType.MouseButton3 then name = "MouseButton3" end
				if name == "Escape" or name == "Backspace" then name = "None" end
				if name then obj.Key = name; listening = false; pill.TextColor3 = Library.Theme.TextDim; if kFlag then Library.Flags[kFlag] = obj.Key end; refresh() end
				return
			end
			if obj.Key ~= "None" then
				local n = (input.KeyCode and input.KeyCode.Name) or (input.UserInputType and input.UserInputType.Name)
				if n == obj.Key then
					if obj.Mode == "Toggle" then element:Set(not state)
					elseif obj.Mode == "Hold" then element:Set(true) end
					if k.Callback then pcall(k.Callback, obj.Key) end
				end
			end
		end))
		track(UserInputService.InputEnded:Connect(function(input)
			if obj.Key == "None" then return end
			local n = (input.KeyCode and input.KeyCode.Name) or (input.UserInputType and input.UserInputType.Name)
			if n == obj.Key and obj.Mode == "Hold" then element:Set(false) end
		end))
		local ke = { Set = function(_, v) obj.Key = (typeof(v)=="EnumItem" and keyName(v)) or v; if kFlag then Library.Flags[kFlag]=obj.Key end; refresh() end, Get = function() return obj.Key end }
		if kFlag then register(kFlag, ke, obj.Key) end
		refresh()
		return element
	end
	function element:AddColorPicker(c) attachColorPicker(rightSlot, c); return element end

	return element
end

----------------------------------------------------------------- SLIDER
function Groupbox:AddSlider(o)
	o = o or {}
	local flag = o.Flag
	local min, max = o.Min or 0, o.Max or 100
	local decimals = o.Decimals or 0
	local suffix = o.Suffix or ""
	local value = clamp(o.Default or min, min, max)

	local holder = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1,0,0,34), Parent = self.Container })
	local top = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1,0,0,15), Parent = holder })
	new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(1,-50,1,0), Font = Library.Font, Text = o.Text or "Slider", TextColor3 = Library.Theme.TextDim, TextSize = Library.FontSize, TextXAlignment = Enum.TextXAlignment.Left, Parent = top })
	local valLabel = new("TextLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1,0), Position = UDim2.new(1,0,0,0), Size = UDim2.new(0,70,1,0), Font = Library.FontBold, Text = tostring(round(value,decimals))..suffix, TextColor3 = Library.Theme.Accent, TextSize = Library.FontSize, TextXAlignment = Enum.TextXAlignment.Right, Parent = top })
	local bar = new("Frame", { BackgroundColor3 = Library.Theme.ElementDark, Position = UDim2.new(0,0,0,20), Size = UDim2.new(1,0,0,8), Parent = holder })
	corner(bar, 4); stroke(bar, Library.Theme.Border, 1)
	local fill = new("Frame", { BackgroundColor3 = Library.Theme.Accent, Size = UDim2.new((value-min)/(max-min),0,1,0), Parent = bar }); corner(fill, 4)

	local element = {}
	local function visual()
		local a = (value - min) / (max - min)
		tween(fill, 0.06, { Size = UDim2.new(clamp(a,0,1),0,1,0) })
		valLabel.Text = tostring(round(value, decimals)) .. suffix
	end
	function element:Set(v, skip) value = clamp(round(tonumber(v) or min, decimals), min, max); if flag then Library.Flags[flag]=value end; visual(); if not skip and o.Callback then pcall(o.Callback, value) end end
	function element:Get() return value end

	local dragging = false
	local function setFromX(px) local rel = clamp((px - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1); element:Set(min + (max-min)*rel) end
	track(bar.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true; setFromX(i.Position.X) end end))
	track(UserInputService.InputChanged:Connect(function(i) if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then setFromX(i.Position.X) end end))
	track(UserInputService.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end))

	register(flag, element, value); visual()
	if o.Callback then pcall(o.Callback, value) end
	onAccent(function() fill.BackgroundColor3 = Library.Theme.Accent; valLabel.TextColor3 = Library.Theme.Accent end)
	return element
end

----------------------------------------------------------------- DROPDOWN
function Groupbox:AddDropdown(o)
	o = o or {}
	local flag = o.Flag
	local options = o.Options or {}
	local multi = o.Multi and true or false
	local value
	if multi then value = {}; if typeof(o.Default)=="table" then for _,v in ipairs(o.Default) do value[v]=true end end
	else value = o.Default or options[1] end

	local holder = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1,0, 0, o.Text and 40 or 22), Parent = self.Container })
	if o.Text then new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(1,0,0,14), Font = Library.Font, Text = o.Text, TextColor3 = Library.Theme.TextDim, TextSize = Library.FontSize, TextXAlignment = Enum.TextXAlignment.Left, Parent = holder }) end
	local btn = new("TextButton", { BackgroundColor3 = Library.Theme.Element, Position = UDim2.new(0,0,1,-20), Size = UDim2.new(1,0,0,20), Text = "", AutoButtonColor = false, Parent = holder })
	corner(btn, 5); local btnStroke = stroke(btn, Library.Theme.Border, 1); pad(btn, 9, 0, 9, 0)
	local sel = new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(1,-18,1,0), Font = Library.Font, Text = "", TextColor3 = Library.Theme.Text, TextSize = Library.FontSize, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = btn })
	local arrow = new("TextLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1,0.5), Position = UDim2.new(1,0,0.5,0), Size = UDim2.new(0,12,1,0), Font = Library.FontBold, Text = "⌄", TextColor3 = Library.Theme.TextDim, TextSize = 14, Parent = btn })

	local element = {}
	local function currentText()
		if multi then local t={} for _,opt in ipairs(options) do if value[opt] then table.insert(t,opt) end end return #t>0 and table.concat(t,", ") or "None"
		else return tostring(value or "None") end
	end
	local function visual() sel.Text = currentText() end

	local popup = new("Frame", { BackgroundColor3 = Library.Theme.Groupbox, Visible = false, ZIndex = 510, Size = UDim2.new(0,10,0,10), Parent = PopupLayer })
	corner(popup, 6); stroke(popup, Library.Theme.BorderLight, 1)
	local scroller = new("ScrollingFrame", { BackgroundTransparency = 1, Size = UDim2.new(1,0,1,0), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 3, ScrollBarImageColor3 = Library.Theme.BorderLight, BorderSizePixel = 0, ZIndex = 511, Parent = popup })
	pad(scroller, 4,4,4,4); local pLayout = new("UIListLayout", { Padding = UDim.new(0,2), SortOrder = Enum.SortOrder.LayoutOrder, Parent = scroller })

	local optButtons = {}
	local function rebuild()
		for _, b in ipairs(optButtons) do b:Destroy() end
		table.clear(optButtons)
		for i, opt in ipairs(options) do
			local active = (multi and value[opt]) or (not multi and value == opt)
			local ob = new("TextButton", { BackgroundColor3 = Library.Theme.Accent, BackgroundTransparency = active and 0.82 or 1, Size = UDim2.new(1,0,0,22), Font = Library.Font, Text = "  "..tostring(opt), TextColor3 = active and Library.Theme.Accent or Library.Theme.TextDim, TextSize = Library.FontSize, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 512, AutoButtonColor = false, LayoutOrder = i, Parent = scroller })
			corner(ob, 4)
			track(ob.MouseEnter:Connect(function() if not active then ob.BackgroundColor3 = Library.Theme.Element; ob.BackgroundTransparency = 0 end end))
			track(ob.MouseLeave:Connect(function() if not active then ob.BackgroundTransparency = 1 end end))
			track(ob.MouseButton1Click:Connect(function()
				if multi then value[opt] = (not value[opt]) or nil else value = opt; popup.Visible = false; Library._activePopup = nil; tween(arrow, 0.1, { Rotation = 0 }) end
				if flag then Library.Flags[flag] = multi and (function() local t={} for k,v in pairs(value) do if v then t[#t+1]=k end end return t end)() or value end
				visual(); rebuild(); if o.Callback then pcall(o.Callback, value) end
			end))
			table.insert(optButtons, ob)
		end
		popup.Size = UDim2.new(0, btn.AbsoluteSize.X, 0, math.min(#options*24 + 8, 220))
	end

	track(btn.MouseButton1Click:Connect(function()
		local was = popup.Visible
		closeAllPopups()
		if not was then
			rebuild()
			popup.Position = UDim2.fromOffset(btn.AbsolutePosition.X, btn.AbsolutePosition.Y + btn.AbsoluteSize.Y + 3)
			popup.Visible = true; Library._activePopup = popup
			btnStroke.Color = Library.Theme.Accent; tween(arrow, 0.12, { Rotation = 180 })
		else btnStroke.Color = Library.Theme.Border; tween(arrow, 0.12, { Rotation = 0 }) end
	end))
	track(popup:GetPropertyChangedSignal("Visible"):Connect(function() if not popup.Visible then btnStroke.Color = Library.Theme.Border; arrow.Rotation = 0 end end))

	function element:Set(v, skip)
		if multi then
			value = {}
			if typeof(v)=="table" then local isArr=(v[1]~=nil); if isArr then for _,k in ipairs(v) do value[k]=true end else for k,on in pairs(v) do if on then value[k]=true end end end end
			if flag then local t={} for k,on in pairs(value) do if on then t[#t+1]=k end end Library.Flags[flag]=t end
		else value = v; if flag then Library.Flags[flag]=value end end
		visual(); if popup.Visible then rebuild() end
		if not skip and o.Callback then pcall(o.Callback, value) end
	end
	function element:Get() return value end
	function element:SetOptions(opts) options = opts or {}; if popup.Visible then rebuild() end end

	register(flag, element, multi and (function() local t={} for k,on in pairs(value) do if on then t[#t+1]=k end end return t end)() or value)
	visual(); if o.Callback then pcall(o.Callback, value) end
	return element
end

----------------------------------------------------------------- BUTTON
function Groupbox:AddButton(o)
	o = o or {}
	local btn = new("TextButton", { BackgroundColor3 = Library.Theme.Element, Size = UDim2.new(1,0,0,24), Font = Library.FontMedium, Text = o.Text or "Button", TextColor3 = Library.Theme.Text, TextSize = Library.FontSize, AutoButtonColor = false, Parent = self.Container })
	corner(btn, 5); local bs = stroke(btn, Library.Theme.Border, 1)
	track(btn.MouseEnter:Connect(function() tween(btn, 0.12, { BackgroundColor3 = Library.Theme.Accent }); bs.Color = Library.Theme.Accent end))
	track(btn.MouseLeave:Connect(function() tween(btn, 0.12, { BackgroundColor3 = Library.Theme.Element }); bs.Color = Library.Theme.Border; btn.TextColor3 = Library.Theme.Text end))
	track(btn.MouseButton1Down:Connect(function() btn.TextColor3 = Color3.new(1,1,1) end))
	track(btn.MouseButton1Click:Connect(function() if o.Callback then pcall(o.Callback) end end))
	return { Instance = btn, SetText = function(_, t) btn.Text = t end }
end

----------------------------------------------------------------- TEXTBOX
function Groupbox:AddTextbox(o)
	o = o or {}
	local flag = o.Flag
	local holder = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1,0,0, o.Text and 40 or 22), Parent = self.Container })
	if o.Text then new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(1,0,0,14), Font = Library.Font, Text = o.Text, TextColor3 = Library.Theme.TextDim, TextSize = Library.FontSize, TextXAlignment = Enum.TextXAlignment.Left, Parent = holder }) end
	local box = new("TextBox", { BackgroundColor3 = Library.Theme.Element, Position = UDim2.new(0,0,1,-20), Size = UDim2.new(1,0,0,20), Font = Library.Font, Text = o.Default or "", PlaceholderText = o.Placeholder or "...", PlaceholderColor3 = Library.Theme.TextDark, TextColor3 = Library.Theme.Text, TextSize = Library.FontSize, ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left, Parent = holder })
	corner(box, 5); local bs = stroke(box, Library.Theme.Border, 1); pad(box, 9, 0, 9, 0)
	track(box.Focused:Connect(function() bs.Color = Library.Theme.Accent end))
	local element = {}
	function element:Set(v, skip) box.Text = tostring(v or ""); if flag then Library.Flags[flag]=box.Text end; if not skip and o.Callback then pcall(o.Callback, box.Text) end end
	function element:Get() return box.Text end
	track(box.FocusLost:Connect(function() bs.Color = Library.Theme.Border; if flag then Library.Flags[flag]=box.Text end; if o.Callback then pcall(o.Callback, box.Text) end end))
	register(flag, element, o.Default or "")
	return element
end

----------------------------------------------------------------- KEYBIND (standalone)
function Groupbox:AddKeybind(o)
	o = o or {}
	local flag = o.Flag
	local stored = o.Default and keyName(o.Default) or "None"
	local row = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1,0,0,19), Parent = self.Container })
	new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(1,-70,1,0), Font = Library.Font, Text = o.Text or "Keybind", TextColor3 = Library.Theme.TextDim, TextSize = Library.FontSize, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
	local pill = new("TextButton", { BackgroundColor3 = Library.Theme.Element, AnchorPoint = Vector2.new(1,0.5), Position = UDim2.new(1,0,0.5,0), Size = UDim2.new(0,64,0,18), Font = Library.FontMedium, Text = "["..displayKey(stored).."]", TextColor3 = Library.Theme.TextDim, TextSize = 11, Parent = row })
	corner(pill, 4); stroke(pill, Library.Theme.Border, 1)
	local obj = { Key = stored }; local listening = false
	local function refresh() pill.Text = "["..displayKey(obj.Key).."]" end
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
		if obj.Key ~= "None" then local n = (input.KeyCode and input.KeyCode.Name) or (input.UserInputType and input.UserInputType.Name); if n == obj.Key and o.Callback then pcall(o.Callback, obj.Key) end end
	end))
	local element = { Set = function(_, v) obj.Key = (typeof(v)=="EnumItem" and keyName(v)) or v; if flag then Library.Flags[flag]=obj.Key end; refresh() end, Get = function() return obj.Key end }
	register(flag, element, obj.Key)
	return element
end

----------------------------------------------------------------- COLOR PICKER
attachColorPicker = function(parent, o)
	o = o or {}
	local flag = o.Flag
	local color = o.Default or Color3.fromRGB(255,255,255)
	local alpha = o.Alpha ~= nil and o.Alpha or 1
	local swatch = new("TextButton", { BackgroundColor3 = color, Size = UDim2.new(0,24,0,14), Text = "", Parent = parent }); corner(swatch, 4); stroke(swatch, Library.Theme.Border, 1)

	local popup = new("Frame", { BackgroundColor3 = Library.Theme.Groupbox, Visible = false, ZIndex = 520, Size = UDim2.new(0,190,0,168), Parent = PopupLayer })
	corner(popup, 7); stroke(popup, Library.Theme.BorderLight, 1); pad(popup, 9, 9, 9, 9)
	local h, s, v = color:ToHSV()
	local svBox = new("ImageButton", { Size = UDim2.new(1,-20,0,112), BackgroundColor3 = Color3.fromHSV(h,1,1), ZIndex = 521, AutoButtonColor = false, Parent = popup }); corner(svBox, 5)
	local whiteOv = new("Frame", { BackgroundColor3 = Color3.new(1,1,1), Size = UDim2.new(1,0,1,0), ZIndex = 522, Parent = svBox }); corner(whiteOv,5); new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0,0), NumberSequenceKeypoint.new(1,1) }), Parent = whiteOv })
	local blackOv = new("Frame", { BackgroundColor3 = Color3.new(0,0,0), Size = UDim2.new(1,0,1,0), ZIndex = 523, Parent = svBox }); corner(blackOv,5); new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0,1), NumberSequenceKeypoint.new(1,0) }), Parent = blackOv })
	local svCur = new("Frame", { BackgroundColor3 = Color3.new(1,1,1), Size = UDim2.new(0,7,0,7), AnchorPoint = Vector2.new(0.5,0.5), ZIndex = 524, Parent = svBox }); corner(svCur, 4); stroke(svCur, Color3.new(0,0,0), 1)
	local hueBar = new("ImageButton", { Size = UDim2.new(0,14,0,112), Position = UDim2.new(1,-14,0,0), BackgroundColor3 = Color3.new(1,1,1), ZIndex = 521, AutoButtonColor = false, Parent = popup }); corner(hueBar, 4)
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new({ ColorSequenceKeypoint.new(0,Color3.fromRGB(255,0,0)), ColorSequenceKeypoint.new(0.17,Color3.fromRGB(255,255,0)), ColorSequenceKeypoint.new(0.33,Color3.fromRGB(0,255,0)), ColorSequenceKeypoint.new(0.5,Color3.fromRGB(0,255,255)), ColorSequenceKeypoint.new(0.67,Color3.fromRGB(0,0,255)), ColorSequenceKeypoint.new(0.83,Color3.fromRGB(255,0,255)), ColorSequenceKeypoint.new(1,Color3.fromRGB(255,0,0)) }), Parent = hueBar })
	local hueCur = new("Frame", { BackgroundColor3 = Color3.new(1,1,1), Size = UDim2.new(1,0,0,2), AnchorPoint = Vector2.new(0,0.5), ZIndex = 524, Parent = hueBar }); stroke(hueCur, Color3.new(0,0,0), 1)
	local hexBox = new("TextBox", { BackgroundColor3 = Library.Theme.Element, Position = UDim2.new(0,0,1,-20), Size = UDim2.new(1,0,0,20), Font = Library.Font, Text = "", TextColor3 = Library.Theme.Text, TextSize = 12, ClearTextOnFocus = false, ZIndex = 522, Parent = popup }); corner(hexBox, 5); stroke(hexBox, Library.Theme.Border, 1); pad(hexBox, 7,0,7,0)

	local element = {}
	local function toHex(c) return string.format("#%02X%02X%02X", c.R*255, c.G*255, c.B*255) end
	local function updateVisual()
		color = Color3.fromHSV(h,s,v); swatch.BackgroundColor3 = color; svBox.BackgroundColor3 = Color3.fromHSV(h,1,1)
		svCur.Position = UDim2.new(s,0,1-v,0); hueCur.Position = UDim2.new(0,0,h,0); hexBox.Text = toHex(color)
		if flag then Library.Flags[flag] = color end
	end
	function element:Set(c, skip) if typeof(c)=="Color3" then color=c; h,s,v=c:ToHSV() end updateVisual(); if not skip and o.Callback then pcall(o.Callback, color, alpha) end end
	function element:Get() return color, alpha end
	local function pickSV(px,py) s = clamp((px - svBox.AbsolutePosition.X)/svBox.AbsoluteSize.X,0,1); v = 1 - clamp((py - svBox.AbsolutePosition.Y)/svBox.AbsoluteSize.Y,0,1); updateVisual(); if o.Callback then pcall(o.Callback, color, alpha) end end
	local function pickHue(py) h = clamp((py - hueBar.AbsolutePosition.Y)/hueBar.AbsoluteSize.Y,0,0.9999); updateVisual(); if o.Callback then pcall(o.Callback, color, alpha) end end
	local dragSV, dragHue = false, false
	track(svBox.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then dragSV=true; pickSV(i.Position.X,i.Position.Y) end end))
	track(hueBar.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then dragHue=true; pickHue(i.Position.Y) end end))
	track(UserInputService.InputChanged:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseMovement then if dragSV then pickSV(i.Position.X,i.Position.Y) end if dragHue then pickHue(i.Position.Y) end end end))
	track(UserInputService.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then dragSV=false; dragHue=false end end))
	track(hexBox.FocusLost:Connect(function() local hex = hexBox.Text:gsub("#",""); if #hex==6 then local r=tonumber(hex:sub(1,2),16); local g=tonumber(hex:sub(3,4),16); local b=tonumber(hex:sub(5,6),16); if r and g and b then element:Set(Color3.fromRGB(r,g,b)) end end end))
	track(swatch.MouseButton1Click:Connect(function()
		local was = popup.Visible; closeAllPopups()
		if not was then
			local cam = workspace.CurrentCamera
			popup.Position = UDim2.fromOffset(clamp(swatch.AbsolutePosition.X - 166, 10, cam.ViewportSize.X - 200), swatch.AbsolutePosition.Y + 20)
			popup.Visible = true; Library._activePopup = popup
		end
	end))
	if flag then register(flag, element, color) end
	updateVisual(); if o.Callback then pcall(o.Callback, color, alpha) end
	return element
end
function Groupbox:AddColorPicker(o)
	o = o or {}
	local row = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1,0,0,19), Parent = self.Container })
	new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(1,-30,1,0), Font = Library.Font, Text = o.Text or "Color", TextColor3 = Library.Theme.TextDim, TextSize = Library.FontSize, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
	local slot = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1,0.5), Position = UDim2.new(1,0,0.5,0), Size = UDim2.new(0,24,1,0), Parent = row })
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right, VerticalAlignment = Enum.VerticalAlignment.Center, Parent = slot })
	return attachColorPicker(slot, o)
end

--==================================================================================
--  TAB
--==================================================================================
local Tab = {}
Tab.__index = Tab

function Tab:AddGroupbox(title, side)
	side = (side == "Right") and "Right" or "Left"
	local parent = side == "Right" and self.RightCol or self.LeftCol
	local box = new("Frame", { BackgroundColor3 = Library.Theme.Groupbox, Size = UDim2.new(1,0,0,0), AutomaticSize = Enum.AutomaticSize.Y, Parent = parent })
	corner(box, 7); stroke(box, Library.Theme.Border, 1)
	local header = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1,0,0,28), Parent = box })
	local tick = new("Frame", { BackgroundColor3 = Library.Theme.Accent, Size = UDim2.new(0,3,0,13), Position = UDim2.new(0,12,0.5,-6), BorderSizePixel = 0, Parent = header }); corner(tick, 2)
	onAccent(function() tick.BackgroundColor3 = Library.Theme.Accent end)
	new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.new(0,22,0,0), Size = UDim2.new(1,-30,1,0), Font = Library.FontBold, Text = title or "Groupbox", TextColor3 = Library.Theme.Text, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, Parent = header })
	new("Frame", { BackgroundColor3 = Library.Theme.Border, Size = UDim2.new(1,-24,0,1), Position = UDim2.new(0,12,0,28), BorderSizePixel = 0, Parent = box })
	local container = new("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0,0,0,29), Size = UDim2.new(1,0,0,0), AutomaticSize = Enum.AutomaticSize.Y, Parent = box })
	pad(container, 14, 10, 14, 12); vlist(container, 8)
	return setmetatable({ Frame = box, Container = container, Window = self.Window }, Groupbox)
end
Tab.AddSection = Tab.AddGroupbox  -- backward-compatible alias

--==================================================================================
--  WINDOW
--==================================================================================
local Window = {}
Window.__index = Window

function Window:AddTab(name, icon, desc)
	local iconData = resolveIcon(icon)

	local row = new("TextButton", { BackgroundColor3 = Library.Theme.Element, BackgroundTransparency = 1, Size = UDim2.new(1,0,0,36), Text = "", AutoButtonColor = false, Parent = self.TabList })
	corner(row, 6)
	local activeBar = new("Frame", { BackgroundColor3 = Library.Theme.Accent, Size = UDim2.new(0,3,0,18), Position = UDim2.new(0,0,0.5,-9), BorderSizePixel = 0, Visible = false, Parent = row }); corner(activeBar, 2)
	onAccent(function() activeBar.BackgroundColor3 = Library.Theme.Accent end)

	local iconObj
	if iconData then
		iconObj = new("ImageLabel", { BackgroundTransparency = 1, Size = UDim2.new(0,18,0,18), Position = UDim2.new(0,14,0.5,-9), Image = iconData.Image, ImageColor3 = Library.Theme.TextDim, ScaleType = Enum.ScaleType.Fit, Parent = row })
		if iconData.RectSize then iconObj.ImageRectSize = iconData.RectSize; iconObj.ImageRectOffset = iconData.RectOffset end
	else
		iconObj = new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(0,18,0,18), Position = UDim2.new(0,14,0.5,-9), Font = Library.FontBold, Text = string.sub(name,1,1):upper(), TextColor3 = Library.Theme.TextDim, TextSize = 14, Parent = row })
	end
	local label = new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.new(0,42,0,0), Size = UDim2.new(1,-50,1,0), Font = Library.FontMedium, Text = name, TextColor3 = Library.Theme.TextDim, TextSize = Library.FontSize, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })

	local page = new("ScrollingFrame", { BackgroundTransparency = 1, Size = UDim2.new(1,0,1,0), Visible = false, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 3, ScrollBarImageColor3 = Library.Theme.BorderLight, BorderSizePixel = 0, Parent = self.Pages })
	pad(page, 0, 0, 6, 12)
	local cols = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1,0,0,0), AutomaticSize = Enum.AutomaticSize.Y, Parent = page })
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0,10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = cols })
	local leftCol = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(0.5,-5,0,0), AutomaticSize = Enum.AutomaticSize.Y, Parent = cols }); vlist(leftCol, 10)
	local rightCol = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(0.5,-5,0,0), AutomaticSize = Enum.AutomaticSize.Y, Parent = cols }); vlist(rightCol, 10)

	local tab = setmetatable({ Window = self, Button = row, Page = page, LeftCol = leftCol, RightCol = rightCol, ActiveBar = activeBar, Icon = iconObj, Label = label, Desc = desc }, Tab)

	local function select()
		for _, t in ipairs(self.Tabs) do
			t.Page.Visible = false; t.Button.BackgroundTransparency = 1; t.Label.TextColor3 = Library.Theme.TextDim; t.ActiveBar.Visible = false
			if t.Icon:IsA("ImageLabel") then t.Icon.ImageColor3 = Library.Theme.TextDim else t.Icon.TextColor3 = Library.Theme.TextDim end
		end
		page.Visible = true; row.BackgroundColor3 = Library.Theme.Element; tween(row, 0.12, { BackgroundTransparency = 0 })
		label.TextColor3 = Library.Theme.Text; activeBar.Visible = true
		if iconObj:IsA("ImageLabel") then iconObj.ImageColor3 = Library.Theme.Accent else iconObj.TextColor3 = Library.Theme.Accent end
		self.ActiveTab = tab
	end
	tab.Select = select
	track(row.MouseButton1Click:Connect(select))
	track(row.MouseEnter:Connect(function() if self.ActiveTab ~= tab then row.BackgroundTransparency = 0.6; label.TextColor3 = Library.Theme.Text end end))
	track(row.MouseLeave:Connect(function() if self.ActiveTab ~= tab then row.BackgroundTransparency = 1; label.TextColor3 = Library.Theme.TextDim end end))

	table.insert(self.Tabs, tab)
	if #self.Tabs == 1 then select() end
	return tab
end

function Window:SetToggleKey(k)
	self.ToggleKey = typeof(k) == "EnumItem" and k.Name or k
	if self._tkLabel then self._tkLabel.Text = "[" .. displayKey(self.ToggleKey) .. "]" end
end

function Window:AddConfigTab()
	local tab = self:AddTab("Config", "settings")
	local left = tab:AddGroupbox("Configs", "Left")
	local right = tab:AddGroupbox("Transfer", "Right")
	local selected = nil
	local dd = left:AddDropdown({ Text = "Config list", Options = Library:ListConfigs(), Callback = function(v) selected = v end })
	local nameBox = left:AddTextbox({ Text = "Config name", Placeholder = "my_config" })
	local function refresh() dd:SetOptions(Library:ListConfigs()) end
	left:AddButton({ Text = "Create / Save", Callback = function()
		local nm = nameBox:Get(); if nm == "" then nm = selected end
		if not nm or nm == "" then Library:Notify({ Title = "Config", Text = "Enter a name first." }); return end
		Library:SaveConfig(nm); refresh(); dd:Set(nm); Library:Notify({ Title = "Config", Text = "Saved '"..nm.."'." })
	end })
	left:AddButton({ Text = "Load selected", Callback = function()
		if not selected then Library:Notify({ Title = "Config", Text = "Select a config." }); return end
		local ok = Library:LoadConfig(selected); Library:Notify({ Title = "Config", Text = ok and ("Loaded '"..selected.."'.") or "Load failed." })
	end })
	left:AddButton({ Text = "Delete selected", Callback = function() if selected then Library:DeleteConfig(selected); refresh(); Library:Notify({ Title = "Config", Text = "Deleted '"..selected.."'." }) end end })
	left:AddButton({ Text = "Refresh list", Callback = refresh })
	right:AddButton({ Text = "Export → clipboard", Callback = function()
		local b64 = Library:ExportConfig(nameBox:Get() ~= "" and nameBox:Get() or nil)
		Library:Notify({ Title = "Config", Text = "Exported ("..#b64.." chars) to clipboard." })
	end })
	local importBox = right:AddTextbox({ Text = "Import string (base64)", Placeholder = "paste here" })
	right:AddButton({ Text = "Import from string", Callback = function()
		local ok, err = Library:ImportConfig(importBox:Get()); Library:Notify({ Title = "Config", Text = ok and "Imported config." or ("Import failed: "..tostring(err)) })
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
	if opts.Accent then self:SetAccent(opts.Accent) end
	local size = opts.Size or Vector2.new(720, 560)

	local root = new("Frame", { Name = "Window", BackgroundColor3 = self.Theme.Window, Size = UDim2.fromOffset(size.X, size.Y), Position = UDim2.new(0.5,-size.X/2,0.5,-size.Y/2), Visible = self.Open, Active = true, Parent = ScreenGui })
	corner(root, 9); stroke(root, self.Theme.Border, 1)

	-- drop shadow
	new("ImageLabel", { BackgroundTransparency = 1, Image = "rbxassetid://6014261993", ImageColor3 = Color3.new(0,0,0), ImageTransparency = 0.4, ScaleType = Enum.ScaleType.Slice, SliceCenter = Rect.new(49,49,450,450), Size = UDim2.new(1,48,1,48), Position = UDim2.new(0,-24,0,-24), ZIndex = 0, Parent = root })

	-- ===== sidebar =====
	local sidebar = new("Frame", { BackgroundColor3 = self.Theme.Sidebar, BorderSizePixel = 0, Size = UDim2.new(0,166,1,0), Parent = root })
	corner(sidebar, 9)
	new("Frame", { BackgroundColor3 = self.Theme.Sidebar, BorderSizePixel = 0, Size = UDim2.new(0,12,1,0), Position = UDim2.new(1,-12,0,0), Parent = sidebar }) -- square off right edge
	new("Frame", { BackgroundColor3 = self.Theme.Border, BorderSizePixel = 0, Size = UDim2.new(0,1,1,0), Position = UDim2.new(1,0,0,0), Parent = sidebar })

	-- brand / title (drag handle)
	local brand = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1,0,0,54), Parent = sidebar })
	local dot = new("Frame", { BackgroundColor3 = self.Theme.Accent, Size = UDim2.new(0,10,0,10), Position = UDim2.new(0,18,0.5,-5), Parent = brand }); corner(dot, 3)
	onAccent(function() dot.BackgroundColor3 = self.Theme.Accent end)
	new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.new(0,36,0,0), Size = UDim2.new(1,-44,1,0), Font = self.FontBold, Text = opts.Title or "gamesense", TextColor3 = self.Theme.Text, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left, Parent = brand })
	new("Frame", { BackgroundColor3 = self.Theme.Border, BorderSizePixel = 0, Size = UDim2.new(1,-28,0,1), Position = UDim2.new(0,14,1,-1), Parent = brand })

	local tabList = new("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0,10,0,62), Size = UDim2.new(1,-20,1,-110), Parent = sidebar })
	vlist(tabList, 4)

	-- sidebar footer: toggle key hint + unload
	local footer = new("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0,10,1,-42), Size = UDim2.new(1,-20,0,34), Parent = sidebar })
	local tkLabel = new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(1,-24,1,0), Font = self.Font, Text = "[RSHIFT]", TextColor3 = self.Theme.TextDark, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, Parent = footer })
	local closeBtn = new("TextButton", { BackgroundColor3 = self.Theme.Element, AnchorPoint = Vector2.new(1,0.5), Position = UDim2.new(1,0,0.5,0), Size = UDim2.new(0,22,0,22), Text = "✕", Font = self.FontBold, TextColor3 = self.Theme.TextDim, TextSize = 12, AutoButtonColor = false, Parent = footer })
	corner(closeBtn, 5); stroke(closeBtn, self.Theme.Border, 1)
	track(closeBtn.MouseEnter:Connect(function() closeBtn.TextColor3 = Color3.fromRGB(255,110,110) end))
	track(closeBtn.MouseLeave:Connect(function() closeBtn.TextColor3 = self.Theme.TextDim end))
	track(closeBtn.MouseButton1Click:Connect(function() Library:Toggle(false) end))

	-- ===== content =====
	local header = new("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0,166,0,0), Size = UDim2.new(1,-166,0,54), Parent = root })
	local tkRight = new("TextLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1,0.5), Position = UDim2.new(1,-18,0.5,0), Size = UDim2.new(0,160,0,20), Font = self.Font, Text = "press [RSHIFT] to toggle", TextColor3 = self.Theme.TextDark, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Right, Parent = header })
	new("Frame", { BackgroundColor3 = self.Theme.Border, BorderSizePixel = 0, Size = UDim2.new(1,-166,0,1), Position = UDim2.new(0,166,0,54), Parent = root })

	local content = new("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0,178,0,66), Size = UDim2.new(1,-190,1,-78), Parent = root })
	local pages = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1,0,1,0), Parent = content })

	local w = setmetatable({ Root = root, TabList = tabList, Pages = pages, Tabs = {}, ActiveTab = nil, ToggleKey = (opts.ToggleKey and (typeof(opts.ToggleKey)=="EnumItem" and opts.ToggleKey.Name or opts.ToggleKey)) or "RightShift", _tkLabel = tkLabel }, Window)
	w:SetToggleKey(w.ToggleKey)
	table.insert(self.Windows, w)

	-- dragging (brand area + header)
	local dragging, dragStart, startPos = false, nil, nil
	local function hookDrag(handle)
		track(handle.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true; dragStart = i.Position; startPos = root.Position end end))
	end
	hookDrag(brand); hookDrag(header)
	track(UserInputService.InputChanged:Connect(function(i) if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then local d = i.Position - dragStart; root.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y) end end))
	track(UserInputService.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end))

	-- intro
	root.Size = UDim2.fromOffset(size.X, size.Y - 24)
	tween(root, 0.22, { Size = UDim2.fromOffset(size.X, size.Y) })

	return w
end

--==================================================================================
--  GLOBAL INPUT
--==================================================================================
track(UserInputService.InputBegan:Connect(function(input, gpe)
	if Library.Unloaded then return end
	for _, w in ipairs(Library.Windows) do
		local n = (input.KeyCode and input.KeyCode.Name) or (input.UserInputType and input.UserInputType.Name)
		if n == w.ToggleKey and not gpe then Library:Toggle(); break end
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 and Library._activePopup then
		local p = Library._activePopup; local mp = input.Position; local pos, sz = p.AbsolutePosition, p.AbsoluteSize
		local inside = mp.X >= pos.X and mp.X <= pos.X+sz.X and mp.Y >= pos.Y and mp.Y <= pos.Y+sz.Y
		if not inside then task.defer(function() if Library._activePopup == p then closeAllPopups() end end) end
	end
end))

return Library
