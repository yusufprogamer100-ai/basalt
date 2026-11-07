-- Basalt UI Library
-- build: 2026-11-07 04:12
-- modules: 27
-- Do not edit the build directly; see src/ and tools/build.py.

local __modules = {}
local __cache = {}

local function require(name)
	local cached = __cache[name]
	if cached ~= nil then
		return cached
	end
	local factory = __modules[name]
	if not factory then
		error('Basalt: module not found: ' .. tostring(name), 0)
	end
	local module = factory()
	__cache[name] = module
	return module
end

__modules["version"] = function()
-- Basalt / version
-- Kept separate so window and init can both read it without a require cycle.

return {
	name = "Basalt",
	version = "0.2.1",
	build = "dev",
}
end

__modules["core.class"] = function()
-- Basalt / core.class
-- Minimal object model. Two levels of inheritance are enough for a UI library:
--   Class -> (Object, Window, Tab, Section, Component) -> concrete component
-- Instances inherit through the class table; nothing else is magic.

local Class = {}
Class.__index = Class

function Class.new(constructor, ...)
	local self = setmetatable({}, constructor)
	self._connections = {}
	self._instances = {}
	self._destroyed = false
	self:init(...)
	return self
end

function Class:extends(name)
	local subclass = setmetatable({}, { __index = self })
	subclass.__index = subclass
	subclass.super = self
	subclass.__name = name
	subclass.new = function(...)
		return Class.new(subclass, ...)
	end
	return subclass
end

function Class:init()
end

-- Store a connection so :Destroy() can clean it up.
function Class:Track(connection)
	if self._destroyed or connection == nil then
		return connection
	end
	table.insert(self._connections, connection)
	return connection
end

-- Store an instance owned by this object (destroyed with it).
function Class:Own(instance)
	if self._destroyed or instance == nil then
		return instance
	end
	table.insert(self._instances, instance)
	return instance
end

function Class:Destroy()
	if self._destroyed then
		return
	end
	self._destroyed = true

	for index = #self._connections, 1, -1 do
		local connection = self._connections[index]
		self._connections[index] = nil
		pcall(function()
			connection:Disconnect()
		end)
	end

	for index = #self._instances, 1, -1 do
		local instance = self._instances[index]
		self._instances[index] = nil
		pcall(function()
			instance:Destroy()
		end)
	end

	self._connections = {}
	self._instances = {}
end

return Class
end

__modules["core.signal"] = function()
-- Basalt / core.signal
-- Dependency-free event. Handlers are isolated with pcall so one broken
-- consumer can never take the interface down with it.

local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({ _handlers = {} }, Signal)
end

function Signal:Connect(handler)
	assert(type(handler) == "function", "Basalt:Signal expects a function")

	local entry = { handler = handler, alive = true }
	table.insert(self._handlers, entry)

	return {
		Disconnect = function()
			if not entry.alive then
				return
			end
			entry.alive = false
			for index = #self._handlers, 1, -1 do
				if self._handlers[index] == entry then
					table.remove(self._handlers, index)
					break
				end
			end
		end,
	}
end

function Signal:Once(handler)
	local connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		handler(...)
	end)
	return connection
end

function Signal:Fire(...)
	-- Snapshot: a handler may connect or disconnect while we iterate.
	local snapshot = table.clone and table.clone(self._handlers) or {}
	if not table.clone then
		for index, entry in ipairs(self._handlers) do
			snapshot[index] = entry
		end
	end

	for _, entry in ipairs(snapshot) do
		if entry.alive then
			local ok, err = pcall(entry.handler, ...)
			if not ok then
				warn("[Basalt] signal handler failed: " .. tostring(err))
			end
		end
	end
end

function Signal:DisconnectAll()
	for _, entry in ipairs(self._handlers) do
		entry.alive = false
	end
	table.clear(self._handlers)
end

return Signal
end

__modules["core.instance"] = function()
-- Basalt / core.instance
-- Instance construction helpers. Property writes happen before parenting so
-- the engine never lays out a half-configured frame.

local Create = {}

local function apply(instance, props)
	for key, value in pairs(props) do
		if key ~= "Parent" then
			instance[key] = value
		end
	end
end

local TEXT_CLASSES = {
	TextLabel = true,
	TextButton = true,
	TextBox = true,
}

function Create.new(className, props, children)
	local instance = Instance.new(className)

	-- Roblox auto-localises text whose value matches a translation key.
	-- A menu must show exactly what the author wrote.
	if TEXT_CLASSES[className] then
		pcall(function()
			instance.AutoLocalize = false
		end)
	end

	if props then
		apply(instance, props)
	end

	if children then
		for _, child in ipairs(children) do
			child.Parent = instance
		end
	end

	if props and props.Parent ~= nil then
		instance.Parent = props.Parent
	end

	return instance
end

function Create.corner(radius)
	return Create.new("UICorner", { CornerRadius = UDim.new(0, radius) })
end

function Create.stroke(color, thickness)
	return Create.new("UIStroke", {
		Color = color,
		Thickness = thickness or 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Create.padding(top, right, bottom, left)
	return Create.new("UIPadding", {
		PaddingTop = UDim.new(0, top or 0),
		PaddingRight = UDim.new(0, right or 0),
		PaddingBottom = UDim.new(0, bottom or 0),
		PaddingLeft = UDim.new(0, left or 0),
	})
end

function Create.list(padding, horizontalAlignment)
	return Create.new("UIListLayout", {
		Padding = UDim.new(0, padding or 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = horizontalAlignment or Enum.HorizontalAlignment.Left,
	})
end

-- Frame with the properties Basalt uses on almost every surface.
function Create.surface(props)
	props = props or {}
	props.BackgroundTransparency = props.BackgroundTransparency or 0
	props.BorderSizePixel = 0
	return Create.new("Frame", props)
end

-- Auto-sized vertical container: children stack, height follows content.
function Create.stack(props)
	props = props or {}
	props.BackgroundTransparency = 1
	props.BorderSizePixel = 0
	props.Size = props.Size or UDim2.new(1, 0, 0, 0)
	props.AutomaticSize = Enum.AutomaticSize.Y
	return Create.new("Frame", props)
end

function Create.label(props)
	props = props or {}
	props.BackgroundTransparency = 1
	props.BorderSizePixel = 0
	props.RichText = props.RichText ~= false
	props.Font = props.Font or Enum.Font.Gotham
	props.TextSize = props.TextSize or 13
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	return Create.new("TextLabel", props)
end

function Create.textButton(props)
	props = props or {}
	props.BorderSizePixel = 0
	props.AutoButtonColor = false
	props.Font = props.Font or Enum.Font.GothamMedium
	props.TextSize = props.TextSize or 13
	return Create.new("TextButton", props)
end

return Create
end

__modules["core.guard"] = function()
-- Basalt / core.guard
-- Every executor difference lives here. Feature detection only; a missing
-- function must never be an error. Globals are read directly: in Luau an
-- undefined global is simply nil.

local Guard = {}

local function attempt(callback)
	local ok, result = pcall(callback)
	if ok then
		return result
	end
	return nil
end

function Guard.getParent()
	if type(gethui) == "function" then
		local hidden = attempt(gethui)
		if hidden then
			return hidden
		end
	end

	local coreGui = attempt(function()
		return game:GetService("CoreGui")
	end)
	if coreGui then
		return coreGui
	end

	return game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
end

function Guard.protect(screenGui)
	local protect = nil
	if type(protectgui) == "function" then
		protect = protectgui
	elseif type(syn) == "table" and type(syn.protect_gui) == "function" then
		protect = syn.protect_gui
	end

	if protect then
		attempt(function()
			protect(screenGui)
		end)
	end
end

function Guard.newScreenGui(name, layer)
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = name
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
	if layer then
		screenGui.DisplayOrder = layer
	end

	Guard.protect(screenGui)
	screenGui.Parent = Guard.getParent()

	-- Some environments disable the GUI after load; keep it visible.
	screenGui:GetPropertyChangedSignal("Enabled"):Connect(function()
		if not screenGui.Enabled then
			screenGui.Enabled = true
		end
	end)

	return screenGui
end

function Guard.hasStorage()
	return type(writefile) == "function" and type(readfile) == "function"
end

function Guard.hasFolderApi()
	return type(makefolder) == "function"
end

function Guard.hasClipboard()
	return type(setclipboard) == "function"
		or type(writeclipboard) == "function"
		or type(toclipboard) == "function"
end

function Guard.copy(text)
	local writer = nil
	if type(setclipboard) == "function" then
		writer = setclipboard
	elseif type(writeclipboard) == "function" then
		writer = writeclipboard
	elseif type(toclipboard) == "function" then
		writer = toclipboard
	end

	if not writer then
		return false
	end

	return (pcall(writer, text))
end

return Guard
end

__modules["services.theme"] = function()
-- Basalt / services.theme
-- Semantic tokens, four presets, and a binding list. A theme change walks the
-- bindings, never the instance tree.

local Create = require("core.instance")

local Theme = {}
Theme.__index = Theme

-- Fine-grained surface steps: the interface gets depth from value, not shadow.
local PRESETS = {
	["basalt-dark"] = {
		bg = { 9, 11, 15 },
		surface = { 16, 19, 24 },
		surfaceAlt = { 23, 27, 33 },
		raised = { 30, 35, 43 },
		border = { 37, 42, 52 },
		borderStrong = { 58, 65, 79 },
		text = { 235, 238, 244 },
		textMuted = { 140, 148, 162 },
		textDim = { 98, 106, 120 },
		accent = { 132, 150, 255 },
		accentSoft = { 28, 34, 54 },
		accentText = { 9, 11, 15 },
		success = { 104, 198, 148 },
		warning = { 222, 170, 96 },
		danger = { 231, 112, 102 },
	},
	["basalt-dusk"] = {
		bg = { 14, 11, 17 },
		surface = { 21, 18, 26 },
		surfaceAlt = { 29, 24, 35 },
		raised = { 37, 31, 45 },
		border = { 45, 38, 54 },
		borderStrong = { 69, 58, 82 },
		text = { 238, 233, 241 },
		textMuted = { 158, 147, 166 },
		textDim = { 112, 103, 120 },
		accent = { 198, 142, 246 },
		accentSoft = { 45, 32, 58 },
		accentText = { 14, 11, 17 },
		success = { 128, 200, 152 },
		warning = { 224, 174, 110 },
		danger = { 232, 120, 120 },
	},
	["basalt-light"] = {
		bg = { 243, 244, 247 },
		surface = { 255, 255, 255 },
		surfaceAlt = { 236, 238, 242 },
		raised = { 228, 231, 236 },
		border = { 214, 218, 225 },
		borderStrong = { 176, 182, 194 },
		text = { 24, 27, 33 },
		textMuted = { 88, 95, 108 },
		textDim = { 130, 137, 150 },
		accent = { 64, 82, 206 },
		accentSoft = { 224, 228, 248 },
		accentText = { 255, 255, 255 },
		success = { 36, 138, 88 },
		warning = { 156, 104, 20 },
		danger = { 188, 54, 46 },
	},
	["basalt-contrast"] = {
		bg = { 0, 0, 0 },
		surface = { 12, 12, 14 },
		surfaceAlt = { 22, 22, 26 },
		raised = { 32, 32, 38 },
		border = { 96, 96, 106 },
		borderStrong = { 168, 168, 180 },
		text = { 255, 255, 255 },
		textMuted = { 202, 204, 212 },
		textDim = { 172, 174, 182 },
		accent = { 150, 196, 255 },
		accentSoft = { 18, 40, 70 },
		accentText = { 0, 0, 0 },
		success = { 122, 244, 176 },
		warning = { 255, 204, 112 },
		danger = { 255, 132, 122 },
	},
}

Theme.tokenOrder = {
	"bg",
	"surface",
	"surfaceAlt",
	"raised",
	"border",
	"borderStrong",
	"text",
	"textMuted",
	"textDim",
	"accent",
	"accentSoft",
	"accentText",
	"success",
	"warning",
	"danger",
}

Theme.presets = {}
for name in pairs(PRESETS) do
	table.insert(Theme.presets, name)
end
table.sort(Theme.presets)

function Theme.new(presetName)
	local self = setmetatable({}, Theme)
	self.name = "basalt-dark"
	self.values = {}
	self.bindings = {}
	self.changed = require("core.signal").new()
	self:_load(presetName or "basalt-dark")
	return self
end

function Theme:_load(presetName)
	local fallback = PRESETS["basalt-dark"]
	local source = PRESETS[presetName] or fallback
	self.name = PRESETS[presetName] and presetName or "basalt-dark"

	for _, token in ipairs(Theme.tokenOrder) do
		local rgb = source[token] or fallback[token]
		self.values[token] = Color3.fromRGB(rgb[1], rgb[2], rgb[3])
	end
end

function Theme:Color(token)
	return self.values[token] or self.values.text
end

function Theme:Bind(instance, property, token)
	if not instance then
		return
	end

	local binding = { instance = instance, property = property, token = token }
	table.insert(self.bindings, binding)
	instance[property] = self:Color(token)
	return binding
end

function Theme:BindStroke(stroke, token)
	return self:Bind(stroke, "Color", token)
end

function Theme:Set(presetName)
	if not PRESETS[presetName] then
		return false
	end
	self:_load(presetName)
	self:Apply()
	self.changed:Fire(self)
	return true
end

function Theme:Apply()
	for index = #self.bindings, 1, -1 do
		local binding = self.bindings[index]
		local ok = pcall(function()
			binding.instance[binding.property] = self:Color(binding.token)
		end)
		if not ok then
			table.remove(self.bindings, index)
		end
	end
	self.changed:Fire(self)
end

function Theme:ForegroundOn(token)
	local colour = self:Color(token)
	local luma = 0.299 * colour.R + 0.587 * colour.G + 0.114 * colour.B
	return luma > 0.55 and self:Color("accentText") or Color3.fromRGB(250, 250, 252)
end

function Theme:NewStroke()
	return Create.stroke(self:Color("border"), 1)
end

return Theme
end

__modules["services.motion"] = function()
-- Basalt / services.motion
-- One place for timing. Reduced motion collapses every duration to zero so
-- screenshots, low-end devices and accessibility settings all behave.

local TweenService = game:GetService("TweenService")

local Motion = {}

Motion.reduced = false

Motion.duration = {
	micro = 0.12,
	panel = 0.18,
	window = 0.24,
	slow = 0.32,
}

Motion.easing = {
	enter = Enum.EasingStyle.Quad,
	exit = Enum.EasingStyle.Quad,
	panel = Enum.EasingStyle.Cubic,
}

local active = setmetatable({}, { __mode = "k" })

function Motion.tween(instance, properties, kind, easing)
	if not instance then
		return nil
	end

	local previous = active[instance]
	if previous then
		pcall(function()
			previous:Cancel()
		end)
	end

	local duration = Motion.reduced and 0 or (Motion.duration[kind or "micro"] or Motion.duration.micro)
	local info = TweenInfo.new(
		duration,
		easing or (kind == "panel" and Motion.easing.panel) or Motion.easing.enter,
		Enum.EasingDirection.Out
	)

	local tween = TweenService:Create(instance, info, properties)
	active[instance] = tween
	tween:Play()
	tween.Completed:Connect(function()
		if active[instance] == tween then
			active[instance] = nil
		end
	end)

	return tween
end

function Motion.cancel(instance)
	local tween = active[instance]
	if tween then
		pcall(function()
			tween:Cancel()
		end)
		active[instance] = nil
	end
end

-- Instant assignment when animation is disabled; otherwise a tween.
function Motion.to(instance, properties, kind)
	if Motion.reduced then
		for property, value in pairs(properties) do
			instance[property] = value
		end
		return nil
	end
	return Motion.tween(instance, properties, kind)
end

return Motion
end

__modules["services.flags"] = function()
-- Basalt / services.flags
-- Controls write here, config reads here. One value per key, one signal per
-- key. A control never owns state; the flag does.

local Signal = require("core.signal")

local Flags = {}

local registry = {}
local order = {}
local syncing = false

function Flags:Register(key, default)
	assert(type(key) == "string" and key ~= "", "Basalt:Flags needs a string key")

	local existing = registry[key]
	if existing then
		return existing
	end

	local flag = {
		key = key,
		value = default,
		default = default,
		changed = Signal.new(),
	}
	registry[key] = flag
	table.insert(order, key)

	return flag
end

function Flags:Has(key)
	return registry[key] ~= nil
end

function Flags:Get(key)
	local flag = registry[key]
	return flag and flag.value
end

function Flags:Set(key, value)
	local flag = registry[key]
	if not flag then
		return false
	end
	if flag.value == value then
		return false
	end

	flag.value = value
	flag.changed:Fire(value, key)
	return true
end

-- Set without firing the flag signal (config apply, initial sync).
function Flags:SetSilent(key, value)
	local flag = registry[key]
	if not flag then
		return false
	end
	flag.value = value
	return true
end

function Flags:OnChanged(key, callback)
	local flag = registry[key]
	if not flag then
		return nil
	end
	return flag.changed:Connect(callback)
end

function Flags:IsSyncing()
	return syncing
end

-- Apply a decoded config table. Unknown keys are ignored, missing keys keep
-- their current value.
function Flags:Apply(values)
	if type(values) ~= "table" then
		return 0
	end

	syncing = true
	local applied = 0
	for key, value in pairs(values) do
		local flag = registry[key]
		if flag and type(value) == type(flag.value) then
			flag.value = value
			flag.changed:Fire(value, key)
			applied = applied + 1
		end
	end
	syncing = false

	return applied
end

function Flags:Snapshot()
	local values = {}
	for key, flag in pairs(registry) do
		values[key] = flag.value
	end
	return values
end

function Flags:Reset()
	for _, key in ipairs(order) do
		Flags:Set(key, registry[key].default)
	end
end

function Flags:Keys()
	local keys = {}
	for _, key in ipairs(order) do
		table.insert(keys, key)
	end
	return keys
end

return Flags
end

__modules["services.input"] = function()
-- Basalt / services.input
-- Pointer abstraction. Mouse and touch behave identically here so components
-- never branch on input type.

local UserInputService = game:GetService("UserInputService")

local Input = {}

local MOUSE = Enum.UserInputType.MouseButton1
local TOUCH = Enum.UserInputType.Touch
local MOVE = Enum.UserInputType.MouseMovement

function Input.isPrimary(input)
	return input.UserInputType == MOUSE or input.UserInputType == TOUCH
end

function Input.isMove(input)
	return input.UserInputType == MOVE or input.UserInputType == TOUCH
end

function Input.contains(gui, position)
	if not gui or not gui.Visible then
		return false
	end

	local origin = gui.AbsolutePosition
	local size = gui.AbsoluteSize

	return position.X >= origin.X
		and position.X <= origin.X + size.X
		and position.Y >= origin.Y
		and position.Y <= origin.Y + size.Y
end

-- Drag a frame by its handle. Position is offset-based so the window keeps
-- its pixel position when the viewport changes.
function Input.drag(frame, handle, onStart, onFinish)
	local dragging = false
	local dragStart = nil
	local startPosition = nil

	local began = handle.InputBegan:Connect(function(input)
		if not Input.isPrimary(input) then
			return
		end

		dragging = true
		dragStart = input.Position
		startPosition = frame.Position
		if onStart then
			onStart()
		end

		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				dragging = false
				if onFinish then
					onFinish()
				end
			end
		end)
	end)

	local moved = UserInputService.InputChanged:Connect(function(input)
		if not dragging or not Input.isMove(input) then
			return
		end

		local delta = input.Position - dragStart
		frame.Position = UDim2.new(
			startPosition.X.Scale,
			startPosition.X.Offset + delta.X,
			startPosition.Y.Scale,
			startPosition.Y.Offset + delta.Y
		)
	end)

	return function()
		began:Disconnect()
		moved:Disconnect()
	end
end

-- Fires when a primary click lands outside `gui`. Used by dropdowns and
-- popovers; returns a disconnect function.
function Input.onOutside(gui, callback)
	local connection = UserInputService.InputBegan:Connect(function(input)
		if not Input.isPrimary(input) then
			return
		end
		if not Input.contains(gui, input.Position) then
			callback()
		end
	end)

	return function()
		connection:Disconnect()
	end
end

-- Next key press (used by the keybind component). Ignores input already
-- consumed by the game, so chat and menus stay usable.
function Input.captureKey(callback)
	local connection
	connection = UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end

		local isKey = input.UserInputType == Enum.UserInputType.Keyboard
		local isMouse = input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.MouseButton2

		if not isKey and not isMouse then
			return
		end

		connection:Disconnect()
		callback(input.KeyCode, input.UserInputType)
	end)

	return function()
		connection:Disconnect()
	end
end

function Input.keyName(keyCode)
	if typeof(keyCode) == "EnumItem" then
		if keyCode == Enum.KeyCode.Unknown then
			return "None"
		end
		return keyCode.Name
	end
	return "None"
end

return Input
end

__modules["services.config"] = function()
-- Basalt / services.config
-- File-backed profiles. Every save is schema-tagged so a future release can
-- migrate instead of guessing. Storage is optional: the library still runs
-- in memory when the executor has no filesystem.

local HttpService = game:GetService("HttpService")
local Guard = require("core.guard")
local Flags = require("services.flags")

local Config = {}

Config.folder = "Basalt"
Config.schema = 1
Config.autosaveDelay = 2

local autosaveToken = 0
local autosaveProfile = nil
local autosaveConnection = nil

-- JSON has no EnumItem and no Color3. Everything is tagged so a file written
-- by an older build still decodes into the right runtime type.
local function encode(value)
	local kind = typeof(value)

	if kind == "EnumItem" then
		return { __enum = tostring(value) }
	end

	if kind == "Color3" then
		return {
			__color = {
				math.floor(value.R * 255 + 0.5),
				math.floor(value.G * 255 + 0.5),
				math.floor(value.B * 255 + 0.5),
			},
		}
	end

	if kind == "table" then
		local encoded = {}
		for key, item in pairs(value) do
			encoded[key] = encode(item)
		end
		return encoded
	end

	if kind == "Vector2" then
		return { __vector2 = { value.X, value.Y } }
	end

	return value
end

local function decode(value)
	if type(value) ~= "table" then
		return value
	end

	if value.__enum then
		local enumName, itemName = tostring(value.__enum):match("^Enum%.(%w+)%.(.+)$")
		local enum = enumName and Enum[enumName]
		return (enum and enum[itemName]) or Enum.KeyCode.Unknown
	end

	if value.__color then
		return Color3.fromRGB(value.__color[1], value.__color[2], value.__color[3])
	end

	if value.__vector2 then
		return Vector2.new(value.__vector2[1], value.__vector2[2])
	end

	local decoded = {}
	for key, item in pairs(value) do
		decoded[key] = decode(item)
	end
	return decoded
end

local function ensureFolder(path)
	if not Guard.hasFolderApi() then
		return
	end

	local function exists()
		if type(isfolder) ~= "function" then
			return false
		end
		local ok, result = pcall(isfolder, path)
		return ok and result
	end

	if not exists() then
		pcall(makefolder, path)
	end
end

local function safeName(profile)
	local name = tostring(profile or ""):gsub("[<>:\"/\\|%?%*%c]", "_")
	name = name:sub(1, 48)
	if name == "" then
		name = "profile"
	end
	return name
end

function Config:SetFolder(folder)
	Config.folder = tostring(folder or "Basalt")
end

function Config:Path(profile)
	return Config.folder .. "/" .. safeName(profile) .. ".json"
end

function Config:Available()
	return Guard.hasStorage()
end

function Config:Payload()
	return {
		schema = Config.schema,
		saved = os.time(),
		values = encode(Flags:Snapshot()),
	}
end

function Config:Save(profile)
	if not Guard.hasStorage() then
		return false, "storage unavailable"
	end

	local okEncode, encoded = pcall(function()
		return HttpService:JSONEncode(Config:Payload())
	end)
	if not okEncode then
		return false, "encode failed: " .. tostring(encoded)
	end

	ensureFolder(Config.folder)
	local path = Config:Path(profile)
	local okWrite = pcall(writefile, path, encoded)
	if not okWrite then
		return false, "write failed: " .. path
	end

	return true, path
end

function Config:Load(profile)
	if not Guard.hasStorage() then
		return false, "storage unavailable"
	end

	local path = Config:Path(profile)
	local okRead, contents = pcall(readfile, path)
	if not okRead or type(contents) ~= "string" then
		return false, "profile not found: " .. tostring(profile)
	end

	local okDecode, payload = pcall(function()
		return HttpService:JSONDecode(contents)
	end)
	if not okDecode or type(payload) ~= "table" then
		return false, "invalid json"
	end

	-- Schema migration: v0 payloads were a bare value table.
	local values = payload.values
	if values == nil then
		values = payload
	end

	local applied = Flags:Apply(decode(values))
	return true, applied
end

function Config:List()
	if not Guard.hasStorage() or type(listfiles) ~= "function" then
		return {}
	end

	ensureFolder(Config.folder)
	local ok, files = pcall(listfiles, Config.folder)
	if not ok or type(files) ~= "table" then
		return {}
	end

	local names = {}
	for _, file in ipairs(files) do
		local match = tostring(file):gsub("\\", "/"):match("([^/]+)%.json$")
		if match then
			table.insert(names, match)
		end
	end
	table.sort(names)
	return names
end

function Config:Delete(profile)
	if type(delfile) ~= "function" then
		return false, "delete unavailable"
	end
	local ok = pcall(delfile, Config:Path(profile))
	return ok
end

function Config:Export()
	local ok, encoded = pcall(function()
		return HttpService:JSONEncode(encode(Flags:Snapshot()))
	end)
	if not ok then
		return nil, tostring(encoded)
	end
	return encoded
end

function Config:Import(json)
	local ok, values = pcall(function()
		return HttpService:JSONDecode(json)
	end)
	if not ok or type(values) ~= "table" then
		return false, "invalid json"
	end
	return true, Flags:Apply(decode(values))
end

-- Debounced autosave: a slider drag produces one write, not sixty.
function Config:EnableAutosave(profile)
	if autosaveConnection then
		autosaveConnection:Disconnect()
	end

	autosaveProfile = profile or autosaveProfile or "default"

	local function schedule()
		autosaveToken = autosaveToken + 1
		local token = autosaveToken
		task.delay(Config.autosaveDelay, function()
			if token == autosaveToken then
				Config:Save(autosaveProfile)
			end
		end)
	end

	autosaveConnection = {
		Disconnect = function() end,
		connections = {},
	}

	for _, key in ipairs(Flags:Keys()) do
		local connection = Flags:OnChanged(key, schedule)
		if connection then
			table.insert(autosaveConnection.connections, connection)
		end
	end

	return true
end

function Config:DisableAutosave()
	if autosaveConnection then
		for _, connection in ipairs(autosaveConnection.connections or {}) do
			connection:Disconnect()
		end
		autosaveConnection = nil
	end
end

return Config
end

__modules["services.notify"] = function()
-- Basalt / services.notify
-- Toasts in their own layer, stacked bottom-right. One accent strip carries
-- the type; everything else stays quiet.

local Create = require("core.instance")
local Motion = require("services.motion")

local Notify = {}
Notify.__index = Notify

Notify.MAX_VISIBLE = 4
Notify.WIDTH = 300

local TYPE_TOKEN = {
	info = "accent",
	success = "success",
	warning = "warning",
	error = "danger",
}

local function closeGlyph(parent, colour)
	local glyph = Create.new("TextButton", {
		Name = "Close",
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 22, 0, 22),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 8),
		Parent = parent,
	})

	for _, rotation in ipairs({ 45, -45 }) do
		Create.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, 0),
			Size = UDim2.new(0, 10, 0, 1),
			BackgroundColor3 = colour,
			BorderSizePixel = 0,
			Rotation = rotation,
			Parent = glyph,
		})
	end

	return glyph
end

function Notify.new(theme, screenGui)
	local self = setmetatable({ theme = theme, toasts = {} }, Notify)

	self.container = Create.new("Frame", {
		Name = "BasaltNotifications",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -14, 1, -14),
		Size = UDim2.new(0, Notify.WIDTH, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = screenGui,
	})

	Create.new("UIListLayout", {
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		Parent = self.container,
	})

	return self
end

function Notify:_trim()
	while #self.toasts > Notify.MAX_VISIBLE - 1 do
		local oldest = table.remove(self.toasts, 1)
		if oldest then
			oldest:Destroy()
		end
	end
end

function Notify:Push(config)
	config = config or {}
	self:_trim()

	local order = (#self.toasts + 1) * 10
	local kind = tostring(config.Type or "info"):lower()
	local token = TYPE_TOKEN[kind] or "accent"

	local toast = Create.new("Frame", {
		Name = "Toast",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = self.theme:Color("surfaceAlt"),
		LayoutOrder = order,
		ClipsDescendants = true,
		Parent = self.container,
	})
	local corner = Create.corner(8)
	corner.Parent = toast

	local strip = Create.new("Frame", {
		Size = UDim2.new(0, 2, 1, 0),
		BackgroundColor3 = self.theme:Color(token),
		BorderSizePixel = 0,
		Parent = toast,
	})
	self.theme:Bind(strip, "BackgroundColor3", token)

	local body = Create.stack({
		Size = UDim2.new(1, 0, 0, 0),
		Parent = toast,
	})
	local bodyPadding = Create.padding(12, 34, 14, 14)
	bodyPadding.Parent = body

	local title = Create.label({
		Text = config.Title or "Notification",
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
		Size = UDim2.new(1, 0, 0, 16),
		Parent = body,
	})
	self.theme:Bind(title, "TextColor3", "text")

	local content = Create.label({
		Text = config.Content or "",
		Font = Enum.Font.Gotham,
		TextSize = 11,
		TextWrapped = true,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = body,
	})
	self.theme:Bind(content, "TextColor3", "textMuted")

	local close = closeGlyph(toast, self.theme:Color("textDim"))

	local progress = Create.new("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 2),
		BackgroundColor3 = self.theme:Color(token),
		BorderSizePixel = 0,
		Parent = toast,
	})
	self.theme:Bind(progress, "BackgroundColor3", token)

	local entry = { frame = toast }
	function entry:Destroy()
		if toast and toast.Parent then
			toast:Destroy()
		end
		toast = nil
	end

	table.insert(self.toasts, entry)

	local function dismiss()
		for index, item in ipairs(self.toasts) do
			if item == entry then
				table.remove(self.toasts, index)
				break
			end
		end
		Motion.tween(toast, { BackgroundTransparency = 1 }, "micro")
		task.delay(Motion.reduced and 0 or 0.12, function()
			entry:Destroy()
		end)
	end

	close.MouseButton1Click:Connect(dismiss)

	local lifetime = tonumber(config.Duration) or 4
	if lifetime > 0 then
		local tween = Motion.tween(progress, { Size = UDim2.new(0, 0, 0, 2) }, "slow")
		if tween then
			tween.Completed:Connect(dismiss)
		end
	end

	return entry
end

return Notify
end

__modules["components.base"] = function()
-- Basalt / components.base
-- Shared behaviour for every control: row sizing, typography, hover, flag
-- binding and teardown. Concrete components only describe what makes them
-- different.

local Class = require("core.class")
local Create = require("core.instance")
local Flags = require("services.flags")
local Motion = require("services.motion")

local Component = Class:extends("Component")

Component.LABEL_SIZE = 13
Component.DESC_SIZE = 11
Component.ROW_HEIGHT = 34
Component.ROW_HEIGHT_DESCRIPTION = 46

function Component:init(section, config, height)
	self.section = section
	self.window = section.window
	self.theme = section.theme
	self.config = config or {}
	self.key = self.config.Key
	self.title = self.config.Title or self.key or "Control"
	self.description = self.config.Description
	self.height = height or (self.description and Component.ROW_HEIGHT_DESCRIPTION or Component.ROW_HEIGHT)
	self.disabled = false
	self.value = self.config.Default

	self.row = Create.new("Frame", {
		Name = "Control",
		Size = UDim2.new(1, 0, 0, self.height),
		BackgroundColor3 = self.theme:Color("surfaceAlt"),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = section.content,
	})
	local rowCorner = Create.corner(5)
	rowCorner.Parent = self.row

	self.label = Create.label({
		Name = "Label",
		Text = self.title,
		Font = Enum.Font.Gotham,
		TextSize = Component.LABEL_SIZE,
		Size = UDim2.new(1, -112, 0, 16),
		Position = UDim2.new(0, 2, 0, self.description and 4 or math.floor((self.height - 16) / 2)),
		Parent = self.row,
	})
	self.theme:Bind(self.label, "TextColor3", "text")

	if self.description then
		self.hint = Create.label({
			Name = "Hint",
			Text = self.description,
			Font = Enum.Font.Gotham,
			TextSize = Component.DESC_SIZE,
			Size = UDim2.new(1, -112, 0, 14),
			Position = UDim2.new(0, 2, 0, 23),
			Parent = self.row,
		})
		self.theme:Bind(self.hint, "TextColor3", "textMuted")
	end

	self.row.MouseEnter:Connect(function()
		if not self.disabled then
			Motion.tween(self.row, { BackgroundTransparency = 0.55 }, "micro")
		end
	end)
	self.row.MouseLeave:Connect(function()
		Motion.tween(self.row, { BackgroundTransparency = 1 }, "micro")
	end)

	if self.key then
		Flags:Register(self.key, self.config.Default)
		self.value = Flags:Get(self.key)
		self.connection = Flags:OnChanged(self.key, function(value)
			self:Sync(value)
		end)
	end

	section:Track(self)
end

function Component:PlaceRight(gui, width, height)
	gui.AnchorPoint = Vector2.new(1, 0.5)
	gui.Position = UDim2.new(1, -2, 0.5, 0)
	gui.Size = UDim2.new(0, width, 0, height or 20)
	return gui
end

function Component:Commit(value)
	if self.key then
		if Flags:Get(self.key) == value then
			self:Sync(value)
			return
		end
		Flags:Set(self.key, value)
		return
	end

	self.value = value
	if self.config.Callback then
		pcall(self.config.Callback, value)
	end
end

function Component:Get()
	if self.key then
		return Flags:Get(self.key)
	end
	return self.value
end

function Component:Sync(value)
	self.value = value
	self:Render(value)
end

function Component:Render()
end

function Component:SetDisabled(disabled)
	self.disabled = not not disabled
	self.row.Active = not self.disabled
	if self.label then
		self.label.TextTransparency = self.disabled and 0.5 or 0
	end
	if self.hint then
		self.hint.TextTransparency = self.disabled and 0.55 or 0
	end
end

-- Hover feedback is functional: a surface step, not decoration.
function Component:Hover(gui, onEnter, onLeave)
	local entered = gui.MouseEnter:Connect(function()
		if not self.disabled and onEnter then
			onEnter()
		end
	end)
	local left = gui.MouseLeave:Connect(function()
		if onLeave then
			onLeave()
		end
	end)
	self:Track(entered)
	self:Track(left)
end

function Component:Filter(query)
	if query == "" then
		self.row.Visible = true
		return true
	end

	local haystack = string.lower(self.title .. " " .. (self.description or ""))
	local matches = string.find(haystack, query, 1, true) ~= nil
	self.row.Visible = matches
	return matches
end

function Component:Destroy()
	if self.connection then
		self.connection:Disconnect()
	end
	if self.row then
		self.row:Destroy()
	end
	self.row = nil
end

return Component
end

__modules["components.label"] = function()
-- Basalt / components.label
-- Static text. `Text` supports rich text; `Description` renders a muted
-- second line. No box, no card: labels exist to explain, not to decorate.

local Component = require("components.base")

local Label = Component:extends("Label")

function Label:init(section, config)
	config = config or {}
	config.Title = config.Text or config.Title or ""
	Component.init(self, section, config, config.Description and 34 or 18)

	self.label.Size = UDim2.new(1, 0, 0, 16)
	self.label.Font = Enum.Font.Gotham
	self.label.TextSize = 13
	self.label.TextWrapped = true
	self.theme:Bind(self.label, "TextColor3", config.Muted and "textMuted" or "text")

	if self.hint then
		self.hint.Size = UDim2.new(1, 0, 0, 14)
	end
end

function Label:SetText(text)
	self.label.Text = text
end

return Label
end

__modules["components.divider"] = function()
-- Basalt / components.divider
-- A one pixel rule with breathing room. The only "decoration" the library
-- allows itself, because grouping is a function.

local Create = require("core.instance")

local Divider = {}
Divider.__index = Divider

function Divider.new(section, config)
	local self = setmetatable({}, Divider)
	config = config or {}

	self.section = section
	self.theme = section.theme

	self.row = Create.new("Frame", {
		Name = "Divider",
		Size = UDim2.new(1, 0, 0, config.Spacing or 11),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = section.content,
	})

	local line = Create.new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.new(1, 0, 0, 1),
		BorderSizePixel = 0,
		Parent = self.row,
	})
	self.theme:Bind(line, "BackgroundColor3", "border")

	section:Track(self)
	return self
end

function Divider:Filter()
	self.row.Visible = true
	return true
end

function Divider:Destroy()
	if self.row then
		self.row:Destroy()
		self.row = nil
	end
end

return Divider
end

__modules["components.button"] = function()
-- Basalt / components.button
-- Three variants, one primary per screen is the caller's responsibility but
-- the styling makes the hierarchy obvious on its own.

local Component = require("components.base")
local Create = require("core.instance")
local Motion = require("services.motion")

local Button = Component:extends("Button")

local STYLES = {
	primary = { background = "accent", text = "accentText", stroke = nil },
	secondary = { background = "raised", text = "text", stroke = nil },
	quiet = { background = "surface", text = "textMuted", stroke = nil },
	danger = { background = "surface", text = "danger", stroke = nil },
}

function Button:init(section, config)
	config = config or {}
	Component.init(self, section, config, 34)

	self.label.Visible = false
	if self.hint then
		self.hint.Visible = false
	end

	self.variant = config.Variant or "secondary"
	local style = STYLES[self.variant] or STYLES.secondary

	self.box = Create.textButton({
		Name = "Button",
		Text = config.Title or "Button",
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		AutoButtonColor = false,
		BackgroundColor3 = self.theme:Color(style.background),
		Size = UDim2.new(1, 0, 0, 30),
		Parent = self.row,
	})

	local corner = Create.corner(6)
	corner.Parent = self.box

	if style.stroke then
		self.stroke = Create.stroke(self.theme:Color(style.stroke), 1)
		self.stroke.Parent = self.box
		self.theme:Bind(self.stroke, "Color", style.stroke)
	end

	self.textToken = style.text
	self.baseToken = style.background
	self.theme:Bind(self.box, "TextColor3", style.text)
	self.theme:Bind(self.box, "BackgroundColor3", style.background)

	self:Hover(
		self.box,
		function()
			Motion.tween(self.box, { BackgroundColor3 = self.theme:Color(self.variant == "primary" and "accent" or "raised") }, "micro")
			if self.stroke then
				Motion.tween(self.stroke, { Color = self.theme:Color("borderStrong") }, "micro")
			end
		end,
		function()
			Motion.tween(self.box, { BackgroundColor3 = self.theme:Color(self.baseToken) }, "micro")
			if self.stroke then
				Motion.tween(self.stroke, { Color = self.theme:Color(style.stroke) }, "micro")
			end
		end
	)

	self.box.MouseButton1Click:Connect(function()
		if self.disabled then
			return
		end
		if self.config.Callback then
			local ok, err = pcall(self.config.Callback)
			if not ok then
				warn("[Basalt] button callback failed: " .. tostring(err))
			end
		end
	end)

	if config.Confirm then
		self.box.Text = config.Title or "Button"
	end
end

function Button:SetText(text)
	self.box.Text = text
end

function Button:SetDisabled(disabled)
	Component.SetDisabled(self, disabled)
	self.box.TextTransparency = disabled and 0.5 or 0
	self.box.BackgroundTransparency = disabled and 0.4 or 0
end

return Button
end

__modules["components.toggle"] = function()
-- Basalt / components.toggle
-- The whole row is the hit target. Off is a surface step, on is the accent;
-- nothing else in the row changes, so scanning stays calm.

local Component = require("components.base")
local Create = require("core.instance")
local Input = require("services.input")
local Motion = require("services.motion")

local Toggle = Component:extends("Toggle")

local SWITCH_W = 32
local SWITCH_H = 18
local KNOB = 14

function Toggle:init(section, config)
	config = config or {}
	Component.init(self, section, config)

	self.track = Create.new("Frame", {
		Name = "Switch",
		BackgroundColor3 = self.theme:Color("raised"),
		BorderSizePixel = 0,
		Parent = self.row,
	})
	self:PlaceRight(self.track, SWITCH_W, SWITCH_H)

	local corner = Create.corner(SWITCH_H / 2)
	corner.Parent = self.track

	self.stroke = Create.stroke(self.theme:Color("border"), 1)
	self.stroke.Parent = self.track

	self.knob = Create.new("Frame", {
		Name = "Knob",
		BackgroundColor3 = self.theme:Color("textMuted"),
		BorderSizePixel = 0,
		Position = UDim2.new(0, 2, 0.5, -KNOB / 2),
		Size = UDim2.new(0, KNOB, 0, KNOB),
		Parent = self.track,
	})
	local knobCorner = Create.corner(KNOB / 2)
	knobCorner.Parent = self.knob

	self.row.InputBegan:Connect(function(input)
		if self.disabled or not Input.isPrimary(input) then
			return
		end
		self:Set(not self:Get())
	end)

	self:Hover(
		self.track,
		function()
			Motion.tween(self.stroke, { Color = self.theme:Color("borderStrong") }, "micro")
		end,
		function()
			if not self:Get() then
				Motion.tween(self.stroke, { Color = self.theme:Color("border") }, "micro")
			end
		end
	)

	self:Render(self:Get())
end

function Toggle:Render(value)
	local on = value == true

	Motion.tween(self.track, {
		BackgroundColor3 = self.theme:Color(on and "accent" or "raised"),
	}, "micro")

	Motion.tween(self.stroke, {
		Color = self.theme:Color(on and "accent" or "border"),
	}, "micro")

	Motion.tween(self.knob, {
		Position = UDim2.new(0, on and (SWITCH_W - KNOB - 2) or 2, 0.5, -KNOB / 2),
		BackgroundColor3 = self.theme:Color(on and "accentText" or "textMuted"),
	}, "micro", Enum.EasingStyle.Back)
end

function Toggle:Set(value)
	self:Commit(value == true)
end

function Toggle:SetDisabled(disabled)
	Component.SetDisabled(self, disabled)
	local alpha = disabled and 0.68 or 0
	self.track.BackgroundTransparency = alpha
	self.knob.BackgroundTransparency = alpha
	self.stroke.Transparency = alpha
end

return Toggle
end

__modules["components.slider"] = function()
-- Basalt / components.slider
-- Continuous value with optional rounding. The track is a real hit target:
-- click to jump, drag to scrub, no invisible padding tricks.

local Component = require("components.base")
local Create = require("core.instance")
local Input = require("services.input")
local Motion = require("services.motion")
local UserInputService = game:GetService("UserInputService")

local Slider = Component:extends("Slider")

function Slider:init(section, config)
	config = config or {}
	Component.init(self, section, config, 46)

	self.label.Size = UDim2.new(1, -130, 0, 16)
	self.min = tonumber(config.Min) or 0
	self.max = tonumber(config.Max) or 100
	self.decimals = tonumber(config.Rounding) or 0
	self.suffix = config.Suffix or ""
	self.dragging = false
	self.connections = {}

	self.valueLabel = Create.label({
		Name = "Value",
		Text = "",
		Font = Enum.Font.Code,
		TextSize = 10,
		TextXAlignment = Enum.TextXAlignment.Right,
		Size = UDim2.new(0, 120, 0, 16),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -2, 0, 3),
		Parent = self.row,
	})
	self.theme:Bind(self.valueLabel, "TextColor3", "textMuted")

	self.bar = Create.new("Frame", {
		Name = "Track",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 2, 0, 30),
		Size = UDim2.new(1, -2, 0, 12),
		Parent = self.row,
	})

	self.rail = Create.new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.new(1, 0, 0, 3),
		BorderSizePixel = 0,
		BackgroundColor3 = self.theme:Color("surfaceAlt"),
		Parent = self.bar,
	})
	local railCorner = Create.corner(2)
	railCorner.Parent = self.rail

	self.fill = Create.new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.new(0, 0, 0, 3),
		BorderSizePixel = 0,
		BackgroundColor3 = self.theme:Color("accent"),
		Parent = self.bar,
	})
	local fillCorner = Create.corner(2)
	fillCorner.Parent = self.fill
	self.theme:Bind(self.fill, "BackgroundColor3", "accent")

	self.knob = Create.new("Frame", {
		Name = "Knob",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.new(0, 11, 0, 11),
		BorderSizePixel = 0,
		BackgroundColor3 = self.theme:Color("text"),
		Parent = self.bar,
	})
	local knobCorner = Create.corner(6)
	knobCorner.Parent = self.knob
	self.theme:Bind(self.knob, "BackgroundColor3", "text")

	self:_bind()
	self:Render(self:Get())
end

function Slider:_round(value)
	local clamped = math.clamp(value, math.min(self.min, self.max), math.max(self.min, self.max))
	if self.decimals <= 0 then
		return math.floor(clamped + 0.5)
	end
	local factor = 10 ^ self.decimals
	return math.floor(clamped * factor + 0.5) / factor
end

function Slider:_valueAt(positionX)
	local origin = self.bar.AbsolutePosition.X
	local width = self.bar.AbsoluteSize.X
	if width <= 0 then
		return self.min
	end
	local alpha = math.clamp((positionX - origin) / width, 0, 1)
	return self:_round(self.min + alpha * (self.max - self.min))
end

function Slider:_bind()
	local parent = self

	table.insert(self.connections, self.bar.InputBegan:Connect(function(input)
		if parent.disabled or not Input.isPrimary(input) then
			return
		end
		parent.dragging = true
		parent:Set(parent:_valueAt(input.Position.X))

		table.insert(parent.connections, input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				parent.dragging = false
			end
		end))
	end))

	table.insert(self.connections, UserInputService.InputChanged:Connect(function(input)
		if not parent.dragging or not Input.isMove(input) then
			return
		end
		parent:Set(parent:_valueAt(input.Position.X))
	end))
end

function Slider:Render(value)
	value = self:_round(tonumber(value) or self.min)
	local span = self.max - self.min
	local alpha = span == 0 and 0 or (value - self.min) / span
	alpha = math.clamp(alpha, 0, 1)

	self.fill.Size = UDim2.new(alpha, 0, 0, 3)
	self.knob.Position = UDim2.new(alpha, 0, 0.5, 0)

	local decimals = math.max(0, self.decimals)
	self.valueLabel.Text = string.format("%." .. decimals .. "f", value) .. self.suffix
end

function Slider:Set(value)
	self:Commit(self:_round(tonumber(value) or self.min))
end

function Slider:SetDisabled(disabled)
	Component.SetDisabled(self, disabled)
	self.bar.Active = not disabled
	self.fill.BackgroundTransparency = disabled and 0.5 or 0
	self.knob.BackgroundTransparency = disabled and 0.5 or 0
	self.valueLabel.TextTransparency = disabled and 0.5 or 0
end

return Slider
end

__modules["components.range"] = function()
-- Basalt / components.range
-- Two-handle slider for intervals (FOV, lead range, ...). Handles are chosen
-- by proximity on press so the drag always feels predictable.

local Component = require("components.base")
local Create = require("core.instance")
local Input = require("services.input")
local UserInputService = game:GetService("UserInputService")

local Range = Component:extends("Range")

function Range:init(section, config)
	config = config or {}
	Component.init(self, section, config, 46)

	self.label.Size = UDim2.new(1, -150, 0, 16)
	self.min = tonumber(config.Min) or 0
	self.max = tonumber(config.Max) or 100
	self.decimals = tonumber(config.Rounding) or 0
	self.suffix = config.Suffix or ""
	self.dragging = nil
	self.connections = {}

	local default = self:Get()
	if type(default) ~= "table" then
		default = { self.min, self.max }
	end
	self.low = math.clamp(tonumber(default[1]) or self.min, self.min, self.max)
	self.high = math.clamp(tonumber(default[2]) or self.max, self.min, self.max)
	if self.low > self.high then
		self.low, self.high = self.high, self.low
	end

	self.valueLabel = Create.label({
		Text = "",
		Font = Enum.Font.Code,
		TextSize = 10,
		TextXAlignment = Enum.TextXAlignment.Right,
		Size = UDim2.new(0, 140, 0, 16),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Parent = self.row,
	})
	self.theme:Bind(self.valueLabel, "TextColor3", "textMuted")

	self.bar = Create.new("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 2, 0, 30),
		Size = UDim2.new(1, -2, 0, 12),
		Parent = self.row,
	})

	self.rail = Create.new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.new(1, 0, 0, 3),
		BorderSizePixel = 0,
		BackgroundColor3 = self.theme:Color("surfaceAlt"),
		Parent = self.bar,
	})
	local railCorner = Create.corner(2)
	railCorner.Parent = self.rail

	self.fill = Create.new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.new(0, 0, 0, 3),
		BorderSizePixel = 0,
		BackgroundColor3 = self.theme:Color("accentSoft"),
		Parent = self.bar,
	})
	local fillCorner = Create.corner(2)
	fillCorner.Parent = self.fill
	self.theme:Bind(self.fill, "BackgroundColor3", "accent")

	self.lowKnob = Create.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.new(0, 11, 0, 11),
		BorderSizePixel = 0,
		BackgroundColor3 = self.theme:Color("text"),
		Parent = self.bar,
	})
	local lowCorner = Create.corner(6)
	lowCorner.Parent = self.lowKnob
	self.theme:Bind(self.lowKnob, "BackgroundColor3", "text")

	self.highKnob = Create.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.new(0, 11, 0, 11),
		BorderSizePixel = 0,
		BackgroundColor3 = self.theme:Color("text"),
		Parent = self.bar,
	})
	local highCorner = Create.corner(6)
	highCorner.Parent = self.highKnob
	self.theme:Bind(self.highKnob, "BackgroundColor3", "text")

	self:_bind()
	self:Render()
end

function Range:_round(value)
	local clamped = math.clamp(value, self.min, self.max)
	if self.decimals <= 0 then
		return math.floor(clamped + 0.5)
	end
	local factor = 10 ^ self.decimals
	return math.floor(clamped * factor + 0.5) / factor
end

function Range:_valueAt(positionX)
	local origin = self.bar.AbsolutePosition.X
	local width = self.bar.AbsoluteSize.X
	if width <= 0 then
		return self.min
	end
	local alpha = math.clamp((positionX - origin) / width, 0, 1)
	return self:_round(self.min + alpha * (self.max - self.min))
end

function Range:_bind()
	local self_ = self

	table.insert(self.connections, self.bar.InputBegan:Connect(function(input)
		if self_.disabled or not Input.isPrimary(input) then
			return
		end

		local value = self_:_valueAt(input.Position.X)
		if math.abs(value - self_.low) <= math.abs(value - self_.high) then
			self_.dragging = "low"
		else
			self_.dragging = "high"
		end
		self_:_apply(self_.dragging, value)

		table.insert(self_.connections, input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				self_.dragging = nil
			end
		end))
	end))

	table.insert(self.connections, UserInputService.InputChanged:Connect(function(input)
		if not self_.dragging or not Input.isMove(input) then
			return
		end
		self_:_apply(self_.dragging, self_:_valueAt(input.Position.X))
	end))
end

function Range:_apply(which, value)
	if which == "low" then
		self.low = math.min(value, self.high)
	else
		self.high = math.max(value, self.low)
	end
	self:Render()
	self:Commit({ self.low, self.high })
end

function Range:Render()
	local span = self.max - self.min
	local alphaLow = span == 0 and 0 or (self.low - self.min) / span
	local alphaHigh = span == 0 and 1 or (self.high - self.min) / span

	self.lowKnob.Position = UDim2.new(alphaLow, 0, 0.5, 0)
	self.highKnob.Position = UDim2.new(alphaHigh, 0, 0.5, 0)
	self.fill.Position = UDim2.new(alphaLow, 0, 0.5, 0)
	self.fill.Size = UDim2.new(math.max(alphaHigh - alphaLow, 0), 0, 0, 4)

	local decimals = math.max(0, self.decimals)
	self.valueLabel.Text = string.format(
		"%." .. decimals .. "f - %." .. decimals .. "f%s",
		self.low,
		self.high,
		self.suffix
	)
end

function Range:Sync(values)
	if type(values) == "table" then
		self.low = math.clamp(tonumber(values[1]) or self.low, self.min, self.max)
		self.high = math.clamp(tonumber(values[2]) or self.high, self.min, self.max)
		if self.low > self.high then
			self.low, self.high = self.high, self.low
		end
	end
	self:Render()
end

return Range
end

__modules["components.dropdown"] = function()
-- Basalt / components.dropdown
-- Single and multi select. The popup is parented to the window overlay, not
-- to the scrolling page, so it can never be clipped by the section or by the
-- scroll frame.

local Component = require("components.base")
local Create = require("core.instance")
local Input = require("services.input")
local Motion = require("services.motion")
local UserInputService = game:GetService("UserInputService")

local Dropdown = Component:extends("Dropdown")

local ITEM_HEIGHT = 28
local PADDING = 4
local MAX_HEIGHT = 176

function Dropdown:init(section, config)
	config = config or {}
	Component.init(self, section, config, 54)

	self.multi = config.Multi == true
	self.values = {}
	for _, value in ipairs(config.Values or {}) do
		table.insert(self.values, tostring(value))
	end

	if self.multi then
		self.selected = {}
		local default = config.Default
		if type(default) == "table" then
			for _, value in ipairs(default) do
				self.selected[tostring(value)] = true
			end
		end
	else
		self.selected = tostring(config.Default or (self.values[1] or "-"))
	end

	self.label.Position = UDim2.new(0, 0, 0, 0)
	self.label.Size = UDim2.new(1, 0, 0, 16)
	if self.hint then
		self.hint.Position = UDim2.new(0, 0, 0, 15)
		self.hint.Visible = false
	end

	self.field = Create.new("Frame", {
		Name = "Field",
		BackgroundColor3 = self.theme:Color("surfaceAlt"),
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 0, 22),
		Size = UDim2.new(1, 0, 0, 28),
		Parent = self.row,
	})
	local fieldCorner = Create.corner(6)
	fieldCorner.Parent = self.field

	self.fieldStroke = Create.stroke(self.theme:Color("border"), 1)
	self.fieldStroke.Parent = self.field

	self.valueLabel = Create.label({
		Text = "",
		Font = Enum.Font.Gotham,
		TextSize = 12,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Size = UDim2.new(1, -40, 1, 0),
		Position = UDim2.new(0, 10, 0, 0),
		Parent = self.field,
	})
	self.theme:Bind(self.valueLabel, "TextColor3", "text")

	self.chevron = Create.label({
		Text = ">",
		Font = Enum.Font.Gotham,
		TextSize = 12,
		Rotation = 90,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.new(0, 12, 0, 12),
		Parent = self.field,
	})
	self.theme:Bind(self.chevron, "TextColor3", "textDim")

	self.field.InputBegan:Connect(function(input)
		if self.disabled or not Input.isPrimary(input) then
			return
		end
		if self.popup then
			self:Close()
		else
			self:Open()
		end
	end)

	self:Hover(
		self.field,
		function()
			Motion.tween(self.fieldStroke, { Color = self.theme:Color("borderStrong") }, "micro")
		end,
		function()
			Motion.tween(self.fieldStroke, { Color = self.theme:Color("border") }, "micro")
		end
	)

	self:Render()
end

function Dropdown:Summary()
	if self.multi then
		local chosen = {}
		for _, value in ipairs(self.values) do
			if self.selected[value] then
				table.insert(chosen, value)
			end
		end
		if #chosen == 0 then
			return "None"
		end
		if #chosen <= 2 then
			return table.concat(chosen, ", ")
		end
		return tostring(#chosen) .. " selected"
	end

	return tostring(self.selected)
end

function Dropdown:Render()
	self.valueLabel.Text = self:Summary()

	if self.multi then
		self:Commit(self.selected)
	else
		self:Commit(self.selected)
	end
end

function Dropdown:SetValue(value)
	if self.multi then
		if type(value) == "table" then
			self.selected = {}
			for key, state in pairs(value) do
				if type(key) == "string" and state then
					self.selected[key] = true
				end
			end
		end
	else
		self.selected = tostring(value)
	end
	self.valueLabel.Text = self:Summary()
end

function Dropdown:Open()
	if self.popup or #self.values == 0 then
		return
	end

	local overlay = self.window:Overlay()
	local origin = self.field.AbsolutePosition - overlay.AbsolutePosition
	local height = math.min(#self.values * ITEM_HEIGHT + PADDING * 2, MAX_HEIGHT)

	self.popup = Create.new("ScrollingFrame", {
		Name = "DropdownPopup",
		BackgroundColor3 = self.theme:Color("surface"),
		BorderSizePixel = 0,
		Position = UDim2.new(0, origin.X, 0, origin.Y + self.field.AbsoluteSize.Y + 4),
		Size = UDim2.new(0, self.field.AbsoluteSize.X, 0, height),
		CanvasSize = UDim2.new(0, 0, 0, 0),
		ScrollBarThickness = 2,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ZIndex = 60,
		Parent = overlay,
	})
	local corner = Create.corner(6)
	corner.Parent = self.popup
	local stroke = Create.stroke(self.theme:Color("borderStrong"), 1)
	stroke.Parent = self.popup

	Create.new("UIListLayout", {
		Padding = UDim.new(0, 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = self.popup,
	})

	Motion.tween(self.chevron, { Rotation = -90 }, "micro")

	self.items = {}
	for index, value in ipairs(self.values) do
		local item = Create.new("TextButton", {
			Name = "Item",
			Text = "",
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, ITEM_HEIGHT),
			LayoutOrder = index,
			ZIndex = 61,
			Parent = self.popup,
		})

		local selected = self.multi and self.selected[value] or (not self.multi and self.selected == value)

		local highlight = Create.new("Frame", {
			Size = UDim2.new(1, -8, 0, ITEM_HEIGHT - 4),
			Position = UDim2.new(0, 4, 0, 2),
			BackgroundColor3 = self.theme:Color(selected and "accentSoft" or "surface"),
			BackgroundTransparency = selected and 0 or 1,
			BorderSizePixel = 0,
			ZIndex = 61,
			Parent = item,
		})
		local highlightCorner = Create.corner(4)
		highlightCorner.Parent = highlight

		local text = Create.label({
			Text = value,
			Font = Enum.Font.Gotham,
			TextSize = 12,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -24, 1, 0),
			Position = UDim2.new(0, 12, 0, 0),
			ZIndex = 62,
			Parent = item,
		})
		self.theme:Bind(text, "TextColor3", selected and "accent" or "text")

		item.MouseEnter:Connect(function()
			highlight.BackgroundTransparency = 0
			highlight.BackgroundColor3 = self.theme:Color(selected and "accentSoft" or "raised")
		end)
		item.MouseLeave:Connect(function()
			if not selected then
				highlight.BackgroundTransparency = 1
			end
		end)

		item.MouseButton1Click:Connect(function()
			self:_choose(value)
		end)

		table.insert(self.items, item)
	end

	self.closeConnection = UserInputService.InputBegan:Connect(function(input)
		if not Input.isPrimary(input) then
			return
		end
		if Input.contains(self.popup, input.Position) or Input.contains(self.field, input.Position) then
			return
		end
		self:Close()
	end)
end

function Dropdown:_choose(value)
	if self.multi then
		self.selected[value] = not self.selected[value] or nil
		self:Render()
		self:Close()
		self:Open() -- rebuild with the new selection state
	else
		self.selected = value
		self:Render()
		self:Close()
	end
end

function Dropdown:Close()
	if self.closeConnection then
		self.closeConnection:Disconnect()
		self.closeConnection = nil
	end
	if self.popup then
		self.popup:Destroy()
		self.popup = nil
	end
	self.items = nil
	if self.chevron then
		Motion.tween(self.chevron, { Rotation = 90 }, "micro")
	end
end

function Dropdown:Sync(value)
	if self.multi then
		self:SetValue(value)
	elseif value ~= nil then
		self.selected = tostring(value)
		self.valueLabel.Text = self:Summary()
	end
end

function Dropdown:SetDisabled(disabled)
	Component.SetDisabled(self, disabled)
	if disabled then
		self:Close()
	end
	self.field.BackgroundTransparency = disabled and 0.5 or 0
end

function Dropdown:Destroy()
	self:Close()
	Component.Destroy(self)
end

return Dropdown
end

__modules["components.input"] = function()
-- Basalt / components.input
-- Text entry with a real label above the field. Placeholder is a hint, never
-- a replacement for the label.

local Component = require("components.base")
local Create = require("core.instance")
local Motion = require("services.motion")

local TextInput = Component:extends("Input")

function TextInput:init(section, config)
	config = config or {}
	Component.init(self, section, config, 54)

	self.label.Position = UDim2.new(0, 0, 0, 0)
	self.label.Size = UDim2.new(1, 0, 0, 16)
	if self.hint then
		self.hint.Position = UDim2.new(0, 0, 0, 15)
		self.hint.Visible = false
	end

	self.field = Create.new("Frame", {
		BackgroundColor3 = self.theme:Color("surfaceAlt"),
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 0, 22),
		Size = UDim2.new(1, 0, 0, 28),
		Parent = self.row,
	})
	local corner = Create.corner(6)
	corner.Parent = self.field

	self.stroke = Create.stroke(self.theme:Color("border"), 1)
	self.stroke.Parent = self.field

	self.box = Create.new("TextBox", {
		Name = "TextBox",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClearTextOnFocus = false,
		Font = Enum.Font.Gotham,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		PlaceholderText = config.Placeholder or "",
		PlaceholderColor3 = self.theme:Color("textDim"),
		Text = tostring(self:Get() or config.Default or ""),
		Size = UDim2.new(1, -16, 1, 0),
		Position = UDim2.new(0, 8, 0, 0),
		Parent = self.field,
	})
	self.theme:Bind(self.box, "TextColor3", "text")
	self.theme:Bind(self.box, "PlaceholderColor3", "textDim")

	self.box.Focused:Connect(function()
		Motion.tween(self.stroke, { Color = self.theme:Color("accent") }, "micro")
	end)

	self.box.FocusLost:Connect(function()
		Motion.tween(self.stroke, { Color = self.theme:Color("border") }, "micro")
		self:Set(self.box.Text)
	end)

	self:Render(self:Get())
end

function TextInput:Render(value)
	if value ~= nil and self.box then
		self.box.Text = tostring(value)
	end
end

function TextInput:Set(value)
	value = tostring(value or "")
	if self.config.Numeric then
		value = value:gsub("[^%d%.%-]", "")
	end
	self:Commit(value)
end

function TextInput:SetDisabled(disabled)
	Component.SetDisabled(self, disabled)
	self.box.TextEditable = not disabled
	self.box.TextTransparency = disabled and 0.5 or 0
	self.field.BackgroundTransparency = disabled and 0.5 or 0
end

return TextInput
end

__modules["components.keybind"] = function()
-- Basalt / components.keybind
-- Captures a key or mouse button. Values are stored as Enum.KeyCode so the
-- rest of the system can use `.Name` without special cases, but config files
-- receive a plain string through services.config's codec.

local Component = require("components.base")
local Create = require("core.instance")
local Input = require("services.input")
local Motion = require("services.motion")

local Keybind = Component:extends("Keybind")

local function normalize(value)
	if typeof(value) == "EnumItem" then
		return value
	end
	if type(value) == "string" and Enum.KeyCode[value] then
		return Enum.KeyCode[value]
	end
	return Enum.KeyCode.Unknown
end

function Keybind:init(section, config)
	config = config or {}
	Component.init(self, section, config, 32)

	self.listening = false
	self.cancelCapture = nil

	self.chip = Create.textButton({
		Name = "Key",
		Text = "",
		Font = Enum.Font.Code,
		TextSize = 11,
		TextColor3 = self.theme:Color("text"),
		BackgroundColor3 = self.theme:Color("raised"),
		Size = UDim2.new(0, 108, 0, 26),
		Parent = self.row,
	})
	self:PlaceRight(self.chip, 108, 26)

	local corner = Create.corner(5)
	corner.Parent = self.chip

	self.stroke = Create.stroke(self.theme:Color("border"), 1)
	self.stroke.Parent = self.chip

	self.chip.MouseButton1Click:Connect(function()
		if self.disabled then
			return
		end
		if self.listening then
			self:Cancel()
		else
			self:Listen()
		end
	end)

	self:Hover(
		self.chip,
		function()
			if not self.listening then
				Motion.tween(self.stroke, { Color = self.theme:Color("borderStrong") }, "micro")
			end
		end,
		function()
			if not self.listening then
				Motion.tween(self.stroke, { Color = self.theme:Color("border") }, "micro")
			end
		end
	)

	self:Render(normalize(self:Get()))
end

function Keybind:Listen()
	self.listening = true
	self.chip.Text = "press a key"
	self.chip.TextColor3 = self.theme:Color("accent")
	self.stroke.Color = self.theme:Color("accent")

	self.cancelCapture = Input.captureKey(function(keyCode)
		self.listening = false
		self.cancelCapture = nil

		if keyCode == Enum.KeyCode.Escape then
			self:Render(normalize(self:Get()))
			return
		end

		self:Commit(keyCode)
		self:Render(keyCode)
	end)
end

function Keybind:Cancel()
	self.listening = false
	if self.cancelCapture then
		self.cancelCapture()
		self.cancelCapture = nil
	end
	self:Render(normalize(self:Get()))
end

function Keybind:Render(value)
	local keyCode = normalize(value)

	self.chip.Text = Input.keyName(keyCode)
	self.chip.TextColor3 = self.theme:Color("text")
	self.stroke.Color = self.theme:Color("border")
end

function Keybind:SetDisabled(disabled)
	Component.SetDisabled(self, disabled)
	if disabled then
		self:Cancel()
	end
	self.chip.TextTransparency = disabled and 0.5 or 0
end

function Keybind:Destroy()
	if self.cancelCapture then
		self.cancelCapture()
		self.cancelCapture = nil
	end
	Component.Destroy(self)
end

return Keybind
end

__modules["components.colorpicker"] = function()
-- Basalt / components.colorpicker
-- A restrained picker: twelve tuned swatches plus the exact hex value. No HSV
-- canvas by default -- a cheat menu needs an accent colour, not Photoshop.

local Component = require("components.base")
local Create = require("core.instance")
local Input = require("services.input")
local Motion = require("services.motion")
local UserInputService = game:GetService("UserInputService")

local Colorpicker = Component:extends("Colorpicker")

local SWATCHES = {
	{ 124, 140, 248 },
	{ 110, 190, 240 },
	{ 95, 191, 138 },
	{ 217, 186, 95 },
	{ 219, 138, 95 },
	{ 224, 104, 95 },
	{ 200, 132, 220 },
	{ 140, 148, 163 },
	{ 231, 234, 240 },
	{ 92, 99, 112 },
	{ 40, 44, 53 },
	{ 15, 17, 21 },
}

function Colorpicker:init(section, config)
	config = config or {}
	Component.init(self, section, config, 32)

	self.color = typeof(self:Get()) == "Color3" and self:Get() or (config.Default or Color3.fromRGB(124, 140, 248))

	self.swatch = Create.new("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -48, 0.5, 0),
		Size = UDim2.new(0, 20, 0, 20),
		BackgroundColor3 = self.color,
		BorderSizePixel = 0,
		Parent = self.row,
	})
	local corner = Create.corner(5)
	corner.Parent = self.swatch

	local stroke = Create.stroke(self.theme:Color("borderStrong"), 1)
	stroke.Parent = self.swatch

	self.hexLabel = Create.label({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.new(0, 46, 0, 14),
		Text = "",
		Font = Enum.Font.Code,
		TextSize = 10,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = self.row,
	})
	self.theme:Bind(self.hexLabel, "TextColor3", "textMuted")

	self.swatch.InputBegan:Connect(function(input)
		if self.disabled or not Input.isPrimary(input) then
			return
		end
		if self.popup then
			self:Close()
		else
			self:Open()
		end
	end)

	self:Hover(
		self.swatch,
		function()
			Motion.tween(stroke, { Color = self.theme:Color("textMuted") }, "micro")
		end,
		function()
			Motion.tween(stroke, { Color = self.theme:Color("borderStrong") }, "micro")
		end
	)

	self:Render(self.color)
end

function Colorpicker:Hex(color)
	return string.format("#%02X%02X%02X", math.floor(color.R * 255 + 0.5), math.floor(color.G * 255 + 0.5), math.floor(color.B * 255 + 0.5))
end

function Colorpicker:Render(color)
	if typeof(color) == "Color3" then
		self.color = color
	end
	self.swatch.BackgroundColor3 = self.color
	self.hexLabel.Text = self:Hex(self.color)
end

function Colorpicker:Open()
	if self.popup then
		return
	end

	local overlay = self.window:Overlay()
	local origin = self.swatch.AbsolutePosition - overlay.AbsolutePosition
	local columns = 4
	local cell = 30
	local height = math.ceil(#SWATCHES / columns) * cell + 16

	self.popup = Create.new("Frame", {
		Name = "ColorPopup",
		BackgroundColor3 = self.theme:Color("surface"),
		BorderSizePixel = 0,
		Position = UDim2.new(0, origin.X - (columns * cell + 16) + 22, 0, origin.Y + 30),
		Size = UDim2.new(0, columns * cell + 16, 0, height),
		ZIndex = 60,
		Parent = overlay,
	})
	local corner = Create.corner(8)
	corner.Parent = self.popup
	local stroke = Create.stroke(self.theme:Color("borderStrong"), 1)
	stroke.Parent = self.popup

	for index, rgb in ipairs(SWATCHES) do
		local column = (index - 1) % columns
		local row = math.floor((index - 1) / columns)

		local color = Color3.fromRGB(rgb[1], rgb[2], rgb[3])
		local button = Create.new("TextButton", {
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			Position = UDim2.new(0, 8 + column * cell, 0, 8 + row * cell),
			Size = UDim2.new(0, 20, 0, 20),
			ZIndex = 61,
			Parent = self.popup,
		})
		local buttonCorner = Create.corner(5)
		buttonCorner.Parent = button
		Create.stroke(self.theme:Color("border"), 1).Parent = button

		button.MouseButton1Click:Connect(function()
			self:Commit(color)
			self:Render(color)
			self:Close()
		end)
	end

	self.closeConnection = UserInputService.InputBegan:Connect(function(input)
		if not Input.isPrimary(input) then
			return
		end
		if Input.contains(self.popup, input.Position) or Input.contains(self.swatch, input.Position) then
			return
		end
		self:Close()
	end)
end

function Colorpicker:Close()
	if self.closeConnection then
		self.closeConnection:Disconnect()
		self.closeConnection = nil
	end
	if self.popup then
		self.popup:Destroy()
		self.popup = nil
	end
end

function Colorpicker:Sync(value)
	if typeof(value) == "Color3" then
		self:Render(value)
	elseif type(value) == "table" and value.__color then
		self:Render(Color3.fromRGB(value.__color[1], value.__color[2], value.__color[3]))
	end
end

function Colorpicker:Destroy()
	self:Close()
	Component.Destroy(self)
end

return Colorpicker
end

__modules["components.paragraph"] = function()
-- Basalt / components.paragraph
-- Wrapped body copy. Height follows the text; the layout engine handles the
-- rest of the section without a manual measurement pass.

local Component = require("components.base")

local Paragraph = Component:extends("Paragraph")

function Paragraph:init(section, config)
	config = config or {}
	config.Title = config.Text or config.Title or ""
	Component.init(self, section, config, 18)

	self.row.AutomaticSize = Enum.AutomaticSize.Y
	self.row.Size = UDim2.new(1, 0, 0, 0)

	self.label.Size = UDim2.new(1, 0, 0, 0)
	self.label.AutomaticSize = Enum.AutomaticSize.Y
	self.label.Position = UDim2.new(0, 0, 0, 0)
	self.label.TextSize = 12
	self.label.TextWrapped = true
	self.label.LineHeight = 1.35
	self.theme:Bind(self.label, "TextColor3", "textMuted")
end

function Paragraph:SetText(text)
	self.label.Text = text
end

return Paragraph
end

__modules["section"] = function()
-- Basalt / section
-- A titled group. Hierarchy comes from type and a single rule, not from a box
-- around every group: the card is a surface step, not a border.

local Create = require("core.instance")

local Section = {}
Section.__index = Section

function Section.new(tab, config)
	local self = setmetatable({}, Section)

	config = config or {}
	self.tab = tab
	self.window = tab.window
	self.theme = tab.theme
	self.title = config.Title or "Section"
	self.collapsed = false
	self.controls = {}
	self.auto = config.Column == nil

	local column = config.Column == "right" and tab.right or tab.left
	self.column = column

	self.frame = Create.new("Frame", {
		Name = "Section",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = self.theme:Color("surface"),
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Parent = column,
	})

	local corner = Create.corner(8)
	corner.Parent = self.frame

	Create.new("UIListLayout", {
		Padding = UDim.new(0, 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = self.frame,
	})

	-- Header: small, quiet, uppercase. It labels the group; it does not compete
	-- with the control labels below it.
	self.header = Create.new("Frame", {
		Name = "Header",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 32),
		LayoutOrder = 1,
		Parent = self.frame,
	})

	self.titleLabel = Create.label({
		Text = string.upper(self.title),
		Font = Enum.Font.GothamMedium,
		TextSize = 10,
		Size = UDim2.new(1, -84, 0, 14),
		Position = UDim2.new(0, 12, 0, 10),
		Parent = self.header,
	})
	self.theme:Bind(self.titleLabel, "TextColor3", "textMuted")

	self.badge = Create.label({
		Text = "",
		Font = Enum.Font.Gotham,
		TextSize = 10,
		TextXAlignment = Enum.TextXAlignment.Right,
		Size = UDim2.new(0, 64, 0, 14),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 10),
		TextTransparency = 1,
		Parent = self.header,
	})
	self.theme:Bind(self.badge, "TextColor3", "textDim")

	local rule = Create.new("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, 0),
		Size = UDim2.new(1, -24, 0, 1),
		BackgroundColor3 = self.theme:Color("border"),
		BorderSizePixel = 0,
		Parent = self.header,
	})
	self.theme:Bind(rule, "BackgroundColor3", "border")

	self.content = Create.stack({
		Name = "Content",
		Size = UDim2.new(1, 0, 0, 0),
		LayoutOrder = 2,
		Parent = self.frame,
	})

	Create.new("UIListLayout", {
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = self.content,
	})

	Create.padding(8, 8, 12, 8).Parent = self.content

	Create.textButton({
		Name = "Collapse",
		Text = "",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 32),
		Parent = self.header,
	}).MouseButton1Click:Connect(function()
		self:SetCollapsed(not self.collapsed)
	end)

	return self
end

function Section:Track(control)
	table.insert(self.controls, control)
	self.window:Track(control)
	return control
end

function Section:SetBadge(text)
	self.badge.Text = text or ""
	self.badge.TextTransparency = text and 0 or 1
end

function Section:SetCollapsed(collapsed, instant)
	self.collapsed = not not collapsed
	self.content.Visible = not self.collapsed
	self.window:RequestReflow(instant == true)
end

function Section:RefreshVisibility()
	local visible = false
	for _, control in ipairs(self.controls) do
		if control.row and control.row.Visible then
			visible = true
			break
		end
	end
	self.frame.Visible = visible
end

function Section:Toggle(config)
	return require("components.toggle").new(self, config)
end

function Section:Slider(config)
	return require("components.slider").new(self, config)
end

function Section:Range(config)
	return require("components.range").new(self, config)
end

function Section:Dropdown(config)
	return require("components.dropdown").new(self, config)
end

function Section:Input(config)
	return require("components.input").new(self, config)
end

function Section:Keybind(config)
	return require("components.keybind").new(self, config)
end

function Section:Colorpicker(config)
	return require("components.colorpicker").new(self, config)
end

function Section:Button(config)
	return require("components.button").new(self, config)
end

function Section:Label(config)
	return require("components.label").new(self, config)
end

function Section:Paragraph(config)
	return require("components.paragraph").new(self, config)
end

function Section:Divider(config)
	return require("components.divider").new(self, config)
end

function Section:Space(height)
	return Create.new("Frame", {
		Size = UDim2.new(1, 0, 0, tonumber(height) or 4),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = self.content,
	})
end

function Section:Destroy()
	for _, control in ipairs(self.controls) do
		if control.Destroy then
			control:Destroy()
		end
	end
	self.controls = {}
	if self.frame then
		self.frame:Destroy()
		self.frame = nil
	end
end

return Section
end

__modules["tab"] = function()
-- Basalt / tab
-- One scrolling page, two columns, optional automatic balance. Reflow is
-- debounced and driven by content size; nothing polls.

local Create = require("core.instance")
local Motion = require("services.motion")
local Section = require("section")

local Tab = {}
Tab.__index = Tab

local GAP = 14

function Tab.new(window, config)
	local self = setmetatable({}, Tab)

	config = config or {}
	self.window = window
	self.theme = window.theme
	self.title = config.Title or "Tab"
	self.sections = {}
	self.reflowToken = 0
	self.balanceToken = 0

	self.page = Create.new("ScrollingFrame", {
		Name = "Page",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 1, 0),
		CanvasSize = UDim2.new(0, 0, 0, 0),
		ScrollBarThickness = 2,
		ScrollBarImageColor3 = self.theme:Color("border"),
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Visible = false,
		Parent = window.content,
	})

	self.body = Create.new("Frame", {
		Name = "Body",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 0),
		Parent = self.page,
	})

	self.left = Create.new("Frame", {
		Name = "Left",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 0, 0),
		Size = UDim2.new(0.5, -7, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = self.body,
	})

	self.right = Create.new("Frame", {
		Name = "Right",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(0.5, 7, 0, 0),
		Size = UDim2.new(0.5, -7, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = self.body,
	})

	Create.new("UIListLayout", {
		Padding = UDim.new(0, GAP),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = self.left,
	})

	Create.new("UIListLayout", {
		Padding = UDim.new(0, GAP),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = self.right,
	})

	self.left:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		window:RequestReflow()
	end)
	self.right:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		window:RequestReflow()
	end)

	return self
end

function Tab:Section(config)
	local section = Section.new(self, config or {})
	table.insert(self.sections, section)
	section.frame.LayoutOrder = #self.sections
	self.window:RequestReflow()
	if section.auto then
		self:ScheduleBalance()
	end
	return section
end

-- Balance: explicit columns stay put; automatic sections fill the shorter
-- column once, after their real heights are known.
function Tab:ScheduleBalance()
	self.balanceToken = self.balanceToken + 1
	local token = self.balanceToken
	task.delay(0.1, function()
		if token == self.balanceToken then
			self:Balance()
		end
	end)
end

function Tab:Balance(attempt)
	attempt = attempt or 1
	local autos = {}
	for _, section in ipairs(self.sections) do
		if section.auto and section.frame then
			table.insert(autos, section)
		end
	end
	if #autos == 0 then
		return
	end

	local measured = 0
	for _, section in ipairs(autos) do
		measured = measured + section.frame.AbsoluteSize.Y
	end
	if measured == 0 and attempt < 4 then
		task.delay(0.15, function()
			self:Balance(attempt + 1)
		end)
		return
	end

	local leftHeight, rightHeight = 0, 0
	for _, section in ipairs(self.sections) do
		if not section.auto and section.frame then
			local height = section.frame.AbsoluteSize.Y + GAP
			if section.frame.Parent == self.right then
				rightHeight = rightHeight + height
			else
				leftHeight = leftHeight + height
			end
		end
	end

	for index, section in ipairs(autos) do
		local target = rightHeight < leftHeight and self.right or self.left
		if target == self.right then
			rightHeight = rightHeight + section.frame.AbsoluteSize.Y + GAP
		else
			leftHeight = leftHeight + section.frame.AbsoluteSize.Y + GAP
		end
		if section.frame.Parent ~= target then
			section.frame.Parent = target
		end
		section.frame.LayoutOrder = index
	end

	self.window:RequestReflow(true)
end

function Tab:Reflow()
	local height = math.max(self.left.AbsoluteSize.Y, self.right.AbsoluteSize.Y)
	self.body.Size = UDim2.new(1, 0, 0, height)
	self.page.CanvasSize = UDim2.new(0, 0, 0, height + 10)
end

function Tab:Show(visible)
	self.page.Visible = visible
	if visible then
		self.page.CanvasPosition = Vector2.new(0, 0)
		self.body.Position = UDim2.new(0, 0, 0, 6)
		Motion.tween(self.body, { Position = UDim2.new(0, 0, 0, 0) }, "panel")
		self.window:RequestReflow(true)
	end
end

function Tab:Destroy()
	for _, section in ipairs(self.sections) do
		section:Destroy()
	end
	self.sections = {}
	if self.page then
		self.page:Destroy()
		self.page = nil
	end
end

return Tab
end

__modules["window"] = function()
-- Basalt / window
-- Chrome only: frame, header, search, tab rail, page stack, overlay, footer.
-- Motion lives here too: drag trails, a short blur, and an opening slide.

local Create = require("core.instance")
local Guard = require("core.guard")
local Theme = require("services.theme")
local Motion = require("services.motion")
local Input = require("services.input")
local Config = require("services.config")
local Notify = require("services.notify")
local Version = require("version")
local Tab = require("tab")

local UserInputService = game:GetService("UserInputService")

local Window = {}
Window.__index = Window

local HEADER = 58
local RAIL = 40
local FOOTER = 22
local DEFAULT_SIZE = UDim2.fromOffset(800, 520)

local function drawnClose(parent, size, colour, theme)
	local button = Create.textButton({
		Name = "Close",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = theme and theme:Color("surfaceAlt") or colour,
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 26, 0, 26),
		AnchorPoint = Vector2.new(1, 0),
		Parent = parent,
	})
	local corner = Create.corner(6)
	corner.Parent = button

	for _, rotation in ipairs({ 45, -45 }) do
		Create.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, 0),
			Size = UDim2.new(0, size, 0, 1),
			BackgroundColor3 = colour,
			BorderSizePixel = 0,
			Rotation = rotation,
			Parent = button,
		})
	end

	return button
end

function Window.new(config)
	local self = setmetatable({}, Window)

	config = config or {}
	self.config = config
	self.title = config.Title or "Basalt"
	self.subtitle = config.Subtitle
	self.theme = Theme.new(config.Theme or "basalt-dark")
	self.tabs = {}
	self.controls = {}
	self.ghosts = {}
	self.activeTab = nil
	self.reflowToken = 0
	self.dragging = false
	self.closed = false

	self.screenGui = Guard.newScreenGui("Basalt", config.DisplayOrder or 200)

	self.main = Create.new("Frame", {
		Name = "Basalt",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 12),
		Size = config.Size or DEFAULT_SIZE,
		BackgroundColor3 = self.theme:Color("bg"),
		BorderSizePixel = 0,
		ClipsDescendants = false,
		ZIndex = 5,
		Parent = self.screenGui,
	})

	local corner = Create.corner(10)
	corner.Parent = self.main

	self.stroke = Create.stroke(self.theme:Color("border"), 1)
	self.stroke.Parent = self.main
	self.theme:Bind(self.stroke, "Color", "border")

	self:_buildHeader()
	self:_buildRail()
	self:_buildContent()
	self:_buildFooter()
	self:_buildOverlay()

	self.dragStop = Input.drag(self.main, self.header, function()
		self.dragging = true
		self:_beginGhost()
	end, function()
		self.dragging = false
		self:_endGhost()
	end)

	self.main:GetPropertyChangedSignal("Position"):Connect(function()
		if self.dragging then
			self:_moveGhost()
		end
	end)

	self.notifier = Notify.new(self.theme, self.screenGui)

	if config.ToggleKey ~= false then
		local toggleKey = config.ToggleKey or Enum.KeyCode.RightShift
		self.toggleConnection = UserInputService.InputBegan:Connect(function(input, processed)
			if processed then
				return
			end
			if input.KeyCode == toggleKey then
				self:Toggle()
			end
		end)
	end

	if config.Autosave then
		Config:EnableAutosave(config.Autosave == true and "default" or config.Autosave)
	end

	Motion.tween(self.main, { Position = UDim2.new(0.5, 0, 0.5, 0) }, "panel")

	return self
end

function Window:_buildHeader()
	self.header = Create.new("Frame", {
		Name = "Header",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, HEADER),
		Parent = self.main,
	})

	-- Mark: three vertical bars, basalt columns. No letterform.
	local mark = Create.new("Frame", {
		Name = "Mark",
		Size = UDim2.new(0, 20, 0, 18),
		Position = UDim2.new(0, 16, 0, 20),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = self.header,
	})

	local heights = { 12, 18, 8 }
	for index, height in ipairs(heights) do
		local bar = Create.new("Frame", {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, (index - 1) * 6, 1, 0),
			Size = UDim2.new(0, 3, 0, height),
			BackgroundColor3 = self.theme:Color("accent"),
			BorderSizePixel = 0,
			Parent = mark,
		})
		local barCorner = Create.corner(1)
		barCorner.Parent = bar
		self.theme:Bind(bar, "BackgroundColor3", "accent")
	end

	local title = Create.label({
		Text = self.title,
		Font = Enum.Font.GothamMedium,
		TextSize = 14,
		Size = UDim2.new(0, 220, 0, 18),
		Position = UDim2.new(0, 46, 0, 11),
		Parent = self.header,
	})
	self.theme:Bind(title, "TextColor3", "text")

	local subtitle = Create.label({
		Text = self.subtitle or ("v" .. Version.version),
		Font = Enum.Font.Gotham,
		TextSize = 10,
		Size = UDim2.new(0, 220, 0, 14),
		Position = UDim2.new(0, 46, 0, 29),
		Parent = self.header,
	})
	self.theme:Bind(subtitle, "TextColor3", "textDim")

	-- Search: quiet field, icon left, no border until focus.
	local searchBox = Create.new("Frame", {
		Name = "Search",
		BackgroundColor3 = self.theme:Color("surface"),
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -88, 0, 15),
		Size = UDim2.new(0, 190, 0, 28),
		Parent = self.header,
	})
	local searchCorner = Create.corner(6)
	searchCorner.Parent = searchBox
	local searchStroke = Create.stroke(self.theme:Color("border"), 1)
	searchStroke.Parent = searchBox
	self.theme:Bind(searchStroke, "Color", "border")

	local lens = Create.new("Frame", {
		Size = UDim2.new(0, 7, 0, 7),
		Position = UDim2.new(0, 10, 0, 10),
		BackgroundTransparency = 1,
		Parent = searchBox,
	})
	local lensStroke = Create.stroke(self.theme:Color("textDim"), 1)
	lensStroke.Parent = lens
	local lensCorner = Create.corner(4)
	lensCorner.Parent = lens

	Create.new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 16, 0, 18),
		Size = UDim2.new(0, 4, 0, 1),
		BackgroundColor3 = self.theme:Color("textDim"),
		BorderSizePixel = 0,
		Rotation = 45,
		Parent = searchBox,
	})

	self.search = Create.new("TextBox", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClearTextOnFocus = false,
		Font = Enum.Font.Gotham,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
		PlaceholderText = "Search",
		PlaceholderColor3 = self.theme:Color("textDim"),
		Text = "",
		Size = UDim2.new(1, -30, 1, 0),
		Position = UDim2.new(0, 24, 0, 0),
		Parent = searchBox,
	})
	self.theme:Bind(self.search, "TextColor3", "text")
	self.theme:Bind(self.search, "PlaceholderColor3", "textDim")

	self.search:GetPropertyChangedSignal("Text"):Connect(function()
		self:Filter(self.search.Text)
	end)

	self.closeButton = drawnClose(self.header, 10, self.theme:Color("textDim"), self.theme)
	self.closeButton.Position = UDim2.new(1, -14, 0, 16)
	self.closeButton.MouseEnter:Connect(function()
		Motion.tween(self.closeButton, { BackgroundTransparency = 0.85 }, "micro")
	end)
	self.closeButton.MouseLeave:Connect(function()
		Motion.tween(self.closeButton, { BackgroundTransparency = 1 }, "micro")
	end)
	self.closeButton.MouseButton1Click:Connect(function()
		self:SetVisible(false)
	end)

	local rule = Create.new("Frame", {
		Position = UDim2.new(0, 0, 0, HEADER - 1),
		Size = UDim2.new(1, 0, 0, 1),
		BorderSizePixel = 0,
		Parent = self.main,
	})
	self.theme:Bind(rule, "BackgroundColor3", "border")
end

function Window:_buildRail()
	self.rail = Create.new("Frame", {
		Name = "Tabs",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 14, 0, HEADER),
		Size = UDim2.new(1, -28, 0, RAIL),
		Parent = self.main,
	})

	Create.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 2),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Parent = self.rail,
	})
end

function Window:_buildContent()
	self.content = Create.new("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 14, 0, HEADER + RAIL + 6),
		Size = UDim2.new(1, -28, 1, -(HEADER + RAIL + FOOTER + 14)),
		ClipsDescendants = true,
		Parent = self.main,
	})
end

function Window:_buildFooter()
	self.footer = Create.new("Frame", {
		Name = "Footer",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 14, 1, -5),
		Size = UDim2.new(1, -28, 0, 14),
		Parent = self.main,
	})

	self.status = Create.label({
		Text = Version.name .. " " .. Version.version,
		Font = Enum.Font.Gotham,
		TextSize = 9,
		TextColor3 = self.theme:Color("textDim"),
		Size = UDim2.new(0, 240, 0, 12),
		Parent = self.footer,
	})
	self.theme:Bind(self.status, "TextColor3", "textDim")

	self.statusRight = Create.label({
		Text = "basalt-dark",
		Font = Enum.Font.Gotham,
		TextSize = 9,
		TextXAlignment = Enum.TextXAlignment.Right,
		Size = UDim2.new(0, 240, 0, 12),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Parent = self.footer,
	})
	self.theme:Bind(self.statusRight, "TextColor3", "textDim")
end

function Window:_buildOverlay()
	self.overlay = Create.new("Frame", {
		Name = "Overlay",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 1, 0),
		ZIndex = 40,
		Parent = self.main,
	})
end

function Window:Overlay()
	return self.overlay
end

function Window:Tab(config)
	config = config or {}
	local tab = Tab.new(self, config)

	local button = Create.textButton({
		Name = "TabButton",
		Text = config.Title or "Tab",
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
		TextColor3 = self.theme:Color("textMuted"),
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 96, 0, 40),
		Parent = self.rail,
	})

	local underline = Create.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.new(0, 0, 0, 2),
		BackgroundColor3 = self.theme:Color("accent"),
		BorderSizePixel = 0,
		Parent = button,
	})
	local underlineCorner = Create.corner(1)
	underlineCorner.Parent = underline
	self.theme:Bind(underline, "BackgroundColor3", "accent")

	tab.button = button
	tab.underline = underline

	button.MouseButton1Click:Connect(function()
		self:SelectTab(tab)
	end)

	table.insert(self.tabs, tab)
	self:SelectTab(tab)
	return tab
end

function Window:SelectTab(tab)
	if self.activeTab == tab then
		return
	end

	for _, item in ipairs(self.tabs) do
		local active = item == tab
		item:Show(active)
		item.button.TextColor3 = self.theme:Color(active and "text" or "textMuted")
		Motion.tween(item.underline, { Size = UDim2.new(0, active and 18 or 0, 0, 2) }, "micro")
	end

	self.activeTab = tab
	self:RequestReflow(true)
end

function Window:Track(control)
	table.insert(self.controls, control)
end

function Window:Filter(query)
	query = string.lower(query or "")

	for _, control in ipairs(self.controls) do
		if control.Filter then
			control:Filter(query)
		end
	end

	for _, tab in ipairs(self.tabs) do
		for _, section in ipairs(tab.sections) do
			section:RefreshVisibility()
		end
	end

	self:RequestReflow(true)
end

function Window:RequestReflow(immediate)
	self.reflowToken = self.reflowToken + 1
	local token = self.reflowToken

	if immediate then
		if self.activeTab then
			self.activeTab:Reflow()
		end
		return
	end

	task.delay(0.05, function()
		if token == self.reflowToken and self.activeTab and not self.closed then
			self.activeTab:Reflow()
		end
	end)
end

-- Motion blur: a lagging, fading copy of the window itself. No screen blur
-- and no tinted overlay, so colours never shift while dragging.

function Window:_beginGhost()
	if Motion.reduced or Motion.motionBlur == false or self.ghost then
		return
	end

	local ok, clone = pcall(function()
		return self.main:Clone()
	end)
	if not ok or not clone then
		return
	end

	local okGroup, group = pcall(function()
		return Create.new("CanvasGroup", {
			Name = "BasaltMotion",
			Size = self.main.Size,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = self.main.Position,
			BackgroundTransparency = 1,
			GroupTransparency = 0.62,
			ClipsDescendants = false,
			ZIndex = 1,
			Parent = self.screenGui,
		})
	end)
	if not okGroup or not group then
		return
	end

	clone.AnchorPoint = Vector2.new(0, 0)
	clone.Position = UDim2.new(0, 0, 0, 0)
	clone.ZIndex = 0
	clone.Parent = group

	self.ghost = group
	self.lastPosition = self.main.Position
end

function Window:_moveGhost()
	if not self.ghost then
		return
	end
	-- The ghost keeps the previous frame position: that lag is the blur.
	self.ghost.Position = self.lastPosition
	self.lastPosition = self.main.Position
end

function Window:_endGhost()
	local ghost = self.ghost
	self.ghost = nil
	if not ghost then
		return
	end

	Motion.tween(ghost, { GroupTransparency = 1 }, "micro")
	task.delay(0.2, function()
		if ghost.Parent then
			ghost:Destroy()
		end
	end)
end

function Window:Notify(config)
	if self.notifier then
		return self.notifier:Push(config)
	end
end

function Window:SetTheme(preset)
	if self.theme:Set(preset) then
		self.statusRight.Text = preset
	end
end

function Window:SetVisible(visible)
	self.main.Visible = visible
end

function Window:Toggle()
	self:SetVisible(not self.main.Visible)
end

function Window:Destroy()
	self.closed = true
	if self.toggleConnection then
		self.toggleConnection:Disconnect()
	end
	if self.dragStop then
		self.dragStop()
	end
	if self.ghost then
		self.ghost:Destroy()
		self.ghost = nil
	end
	Config:DisableAutosave()
	if self.screenGui then
		self.screenGui:Destroy()
		self.screenGui = nil
	end
end

return Window
end

__modules["init"] = function()
-- Basalt / init
-- Public surface. Everything a consumer touches is reachable from here; the
-- module graph underneath is an implementation detail.

local Version = require("version")
local Theme = require("services.theme")
local Flags = require("services.flags")
local Config = require("services.config")
local Motion = require("services.motion")
local Guard = require("core.guard")
local Window = require("window")

local Basalt = {
	Name = Version.name,
	_VERSION = Version.version,

	Theme = Theme,
	Flags = Flags,
	Config = Config,
	Motion = Motion,
	Guard = Guard,
}

Basalt.windows = {}

function Basalt:Window(config)
	local window = Window.new(config)
	table.insert(Basalt.windows, window)
	Basalt._lastWindow = window
	return window
end

function Basalt:Notify(config)
	if Basalt._lastWindow then
		return Basalt._lastWindow:Notify(config)
	end
	return nil
end

function Basalt:SetTheme(preset)
	for _, window in ipairs(Basalt.windows) do
		window:SetTheme(preset)
	end
end

function Basalt:Unload()
	for _, window in ipairs(Basalt.windows) do
		window:Destroy()
	end
	Basalt.windows = {}
	Basalt._lastWindow = nil
end

return Basalt
end

return require("init")
