-- Basalt / test suite
-- Every public feature in one window: 8 tabs, every component, every state,
-- and the service APIs (flags, config, theme, motion, guard).
-- Run it, click everything, and report the first error you see.

local LIBRARY = "https://raw.githubusercontent.com/yusufprogamer100-ai/basalt/main/dist/basalt-v3.luau"

local loaded, Basalt = pcall(function()
	return loadstring(game:HttpGet(LIBRARY))()
end)

if not loaded then
	warn("[Basalt test] library failed to load: " .. tostring(Basalt))
	return
end

print(("[Basalt test] %s %s loaded"):format(Basalt.Name, Basalt._VERSION))

local function crash(label, err)
	warn("[Basalt test] " .. label .. ": " .. tostring(err))
	Basalt:Notify({ Title = label, Content = tostring(err), Type = "error", Duration = 10 })
end

local window = Basalt:Window({
	Title = "Basalt",
	Subtitle = "test suite " .. Basalt._VERSION,
	Size = UDim2.fromOffset(860, 560),
	Theme = "basalt-dark",
	ToggleKey = Enum.KeyCode.RightShift,
})

-- ======================================================== 1. CORE
local core = window:Tab({ Title = "Core" })

local toggles = core:Section({ Title = "Toggles", Column = "left" })
toggles:Toggle({ Key = "t_master", Title = "Master", Description = "Two-line row, on by default", Default = true })
toggles:Toggle({ Key = "t_plain", Title = "Plain row", Default = false })
local tOff = toggles:Toggle({ Key = "t_disabled", Title = "Disabled", Default = true })
tOff:SetDisabled(true)
toggles:Toggle({ Key = "t_sync", Title = "Sync target", Default = false })
toggles:Button({ Title = "Flip 'Sync target' from code", Callback = function()
	Basalt.Flags:Set("t_sync", not Basalt.Flags:Get("t_sync"))
end })

local sliders = core:Section({ Title = "Sliders", Column = "left" })
local intSlider = sliders:Slider({ Key = "s_int", Title = "Integer", Min = 0, Max = 100, Default = 42 })
sliders:Slider({ Key = "s_float", Title = "Float (2 decimals)", Min = 0, Max = 1, Rounding = 2, Default = 0.35 })
sliders:Slider({ Key = "s_suffix", Title = "Suffix", Min = 0, Max = 240, Default = 120, Suffix = " ms" })
sliders:Slider({ Key = "s_negative", Title = "Negative range", Min = -100, Max = 100, Default = -25 })
local sOff = sliders:Slider({ Key = "s_disabled", Title = "Disabled", Min = 0, Max = 10, Default = 5 })
sOff:SetDisabled(true)
sliders:Button({ Title = "Set integer to 88", Callback = function() intSlider:Set(88) end })

local ranges = core:Section({ Title = "Range", Column = "right" })
ranges:Range({ Key = "r_fov", Title = "FOV", Min = 0, Max = 180, Default = { 40, 120 }, Suffix = "°" })
ranges:Range({ Key = "r_delay", Title = "Delay window", Min = 0, Max = 2, Rounding = 2, Default = { 0.1, 0.6 }, Suffix = "s" })

local dropdowns = core:Section({ Title = "Dropdowns", Column = "right" })
dropdowns:Dropdown({ Key = "d_single", Title = "Single", Values = { "Head", "Torso", "Nearest", "Random" }, Default = "Head" })
dropdowns:Dropdown({ Key = "d_multi", Title = "Multi", Values = { "ESP", "Tracers", "Boxes", "Names", "Health" }, Default = { "ESP", "Names" }, Multi = true })
dropdowns:Dropdown({ Key = "d_long", Title = "Long values", Values = { "This is a very long option that should truncate instead of breaking the row", "Short", "Medium value here" }, Default = "Short" })
local dOff = dropdowns:Dropdown({ Key = "d_disabled", Title = "Disabled", Values = { "A", "B" }, Default = "A" })
dOff:SetDisabled(true)

-- ======================================================== 2. INPUT
local inputTab = window:Tab({ Title = "Input" })

local keys = inputTab:Section({ Title = "Keybinds", Column = "left" })
keys:Keybind({ Key = "k_primary", Title = "Primary", Default = Enum.KeyCode.Mouse4 })
keys:Keybind({ Key = "k_panic", Title = "Panic", Default = Enum.KeyCode.End })
keys:Keybind({ Key = "k_letter", Title = "Letter key", Default = Enum.KeyCode.G })
local kOff = keys:Keybind({ Key = "k_disabled", Title = "Disabled", Default = Enum.KeyCode.F })
kOff:SetDisabled(true)

local fields = inputTab:Section({ Title = "Inputs", Column = "left" })
fields:Input({ Key = "i_name", Title = "Text", Placeholder = "type here", Default = "basalt" })
fields:Input({ Key = "i_numeric", Title = "Numeric only", Placeholder = "0-100", Numeric = true, Default = "50" })
fields:Input({ Key = "i_empty", Title = "Empty by default", Placeholder = "this placeholder is intentionally long to test truncation" })

local colors = inputTab:Section({ Title = "Colorpickers", Column = "right" })
colors:Colorpicker({ Key = "c_accent", Title = "Accent", Default = Color3.fromRGB(124, 140, 248) })
colors:Colorpicker({ Key = "c_danger", Title = "Danger", Default = Color3.fromRGB(224, 104, 95) })
colors:Colorpicker({ Key = "c_dark", Title = "Near black", Default = Color3.fromRGB(15, 17, 21) })

local buttons = inputTab:Section({ Title = "Buttons", Column = "right" })
buttons:Button({ Title = "Primary", Variant = "primary", Callback = function()
	Basalt:Notify({ Title = "Primary", Content = "primary pressed", Type = "success" })
end })
buttons:Button({ Title = "Secondary", Callback = function()
	Basalt:Notify({ Title = "Secondary", Content = "secondary pressed" })
end })
buttons:Button({ Title = "Quiet", Variant = "quiet", Callback = function()
	Basalt:Notify({ Title = "Quiet", Content = "quiet pressed" })
end })
buttons:Button({ Title = "Danger", Variant = "danger", Callback = function()
	Basalt:Notify({ Title = "Danger", Content = "danger pressed", Type = "warning" })
end })
local bOff = buttons:Button({ Title = "Disabled", Callback = function() end })
bOff:SetDisabled(true)

-- ======================================================== 3. TEXT & LAYOUT
local textTab = window:Tab({ Title = "Text" })

local labels = textTab:Section({ Title = "Labels", Column = "left" })
labels:Label({ Text = "Default label, 13px, primary text colour." })
labels:Label({ Text = "Muted label, secondary text colour.", Muted = true })
local dynamic = labels:Label({ Text = "Dynamic label — press the button below." })
labels:Button({ Title = "Change label text", Callback = function()
	dynamic:SetText("Changed at " .. tostring(os.clock and math.floor(os.clock() * 100) or 0))
end })
labels:Label({ Text = "Rich text: <b>bold</b> and <i>italic</i> inside one label." })

local paragraphs = textTab:Section({ Title = "Paragraphs", Column = "left" })
paragraphs:Paragraph({ Text = "Short paragraph. It should wrap inside the column and grow the section instead of clipping." })
paragraphs:Paragraph({ Text = "Long paragraph: this body is intentionally verbose so that line height, wrapping and automatic section height all get exercised at once. Nothing here is manually measured — the layout engine follows the text block, and the column reflow is debounced, so resizing or collapsing a neighbouring section must not produce gaps or overlaps." })
local dynamicParagraph = paragraphs:Paragraph({ Text = "Dynamic paragraph — press the button below." })
paragraphs:Button({ Title = "Change paragraph", Callback = function()
	dynamicParagraph:SetText("Paragraph replaced. New content can be shorter or longer; the section height must follow either way.")
end })

local structure = textTab:Section({ Title = "Structure", Column = "right" })
structure:Label({ Text = "Divider below this line:" })
structure:Divider()
structure:Space(8)
structure:Label({ Text = "8px space above, then a divider:" })
structure:Divider()
structure:Space(24)
structure:Label({ Text = "24px space, then a badge section." })

local badged = textTab:Section({ Title = "Badge & collapse", Column = "right" })
badged:SetBadge("3 on")
badged:Toggle({ Key = "l_inner", Title = "Inner toggle", Default = true })
badged:Button({ Title = "Collapse this section", Callback = function()
	badged:SetCollapsed(true)
end })
badged:Button({ Title = "Expand again", Callback = function()
	badged:SetCollapsed(false)
end })
badged:Button({ Title = "Set badge from code", Callback = function()
	badged:SetBadge(tostring(math.random(1, 9)) .. " on")
end })

-- ======================================================== 4. THEME
local themeTab = window:Tab({ Title = "Theme" })

local presets = themeTab:Section({ Title = "Presets", Column = "left" })
for _, name in ipairs({ "basalt-dark", "basalt-dusk", "basalt-light", "basalt-contrast" }) do
	presets:Button({
		Title = name,
		Variant = name == "basalt-dark" and "primary" or "secondary",
		Callback = function()
			Basalt:SetTheme(name)
			Basalt:Notify({ Title = "Theme", Content = name, Type = "info" })
		end,
	})
end
presets:Divider()
presets:Toggle({
	Key = "motion_reduced",
	Title = "Reduced motion",
	Description = "Collapses every tween to instant",
	Default = false,
	Callback = function(value)
		Basalt.Motion.reduced = value == true
	end,
})

local tokens = themeTab:Section({ Title = "Tokens", Column = "right" })
for _, token in ipairs(Basalt.Theme.tokenOrder) do
	local colour = window.theme:Color(token)
	tokens:Colorpicker({
		Key = "token_" .. token,
		Title = token,
		Default = colour,
	})
end

-- ======================================================== 5. FEEDBACK
local feedback = window:Tab({ Title = "Feedback" })

local toasts = feedback:Section({ Title = "Notifications", Column = "left" })
for _, kind in ipairs({ "info", "success", "warning", "error" }) do
	toasts:Button({ Title = kind, Callback = function()
		Basalt:Notify({ Title = kind, Content = "a " .. kind .. " notification", Type = kind })
	end })
end
toasts:Button({ Title = "Long body", Callback = function()
	Basalt:Notify({
		Title = "Long notification",
		Content = "This toast carries a much longer body so wrapping, automatic height and the progress bar can all be checked at once.",
		Type = "info",
		Duration = 8,
	})
end })
toasts:Button({ Title = "Sticky (no timer)", Callback = function()
	Basalt:Notify({ Title = "Sticky", Content = "close it by hand", Duration = 0 })
end })
toasts:Button({ Title = "Burst of 6", Callback = function()
	for index = 1, 6 do
		Basalt:Notify({ Title = "Burst " .. index, Content = "the cap is four visible", Type = "info", Duration = 6 })
	end
end })

local search = feedback:Section({ Title = "Search", Column = "right" })
search:Paragraph({ Text = "The header search filters every control by title and description. Sections with no match hide themselves." })
search:Button({ Title = "Filter 'bulk'", Callback = function() window:Filter("bulk") end })
search:Button({ Title = "Filter 'slider'", Callback = function() window:Filter("slider") end })
search:Button({ Title = "Clear filter", Variant = "primary", Callback = function() window:Filter("") end })
search:Label({ Text = "Note: the box shows the same query you typed." })

-- ======================================================== 6. FLAGS & CONFIG
local configTab = window:Tab({ Title = "Config" })

local profile = configTab:Section({ Title = "Profile", Column = "left" })
local profileName = profile:Input({ Key = "cfg_name", Title = "Profile name", Default = "test" })
profile:Label({ Text = "Path: " .. Basalt.Config:Path("test") })
profile:Button({ Title = "Save", Variant = "primary", Callback = function()
	local ok, message = Basalt.Config:Save(profileName:Get())
	Basalt:Notify({ Title = ok and "Saved" or "Save failed", Content = tostring(message), Type = ok and "success" or "error" })
end })
profile:Button({ Title = "Load", Callback = function()
	local ok, message = Basalt.Config:Load(profileName:Get())
	Basalt:Notify({ Title = ok and "Loaded" or "Load failed", Content = tostring(message), Type = ok and "info" or "error" })
end })
profile:Button({ Title = "Delete", Variant = "danger", Callback = function()
	local ok = Basalt.Config:Delete(profileName:Get())
	Basalt:Notify({ Title = ok and "Deleted" or "Delete failed", Content = profileName:Get(), Type = ok and "warning" or "error" })
end })
profile:Button({ Title = "List profiles", Callback = function()
	local list = Basalt.Config:List()
	Basalt:Notify({ Title = "Profiles", Content = #list .. ": " .. table.concat(list, ", "), Type = "info", Duration = 8 })
end })

local flags = configTab:Section({ Title = "Flags API", Column = "right" })
flags:Button({ Title = "Snapshot size", Callback = function()
	local count = 0
	for _ in pairs(Basalt.Flags:Snapshot()) do
		count = count + 1
	end
	Basalt:Notify({ Title = "Flags", Content = count .. " keys", Type = "info" })
end })
flags:Button({ Title = "Keys → console", Callback = function()
	print("[Basalt test] keys:", table.concat(Basalt.Flags:Keys(), ", "))
	Basalt:Notify({ Title = "Keys", Content = "printed to console", Type = "info" })
end })
flags:Button({ Title = "Has 't_master'?", Callback = function()
	local has = Basalt.Flags:Has("t_master")
	Basalt:Notify({ Title = "Flags:Has", Content = tostring(has), Type = has and "success" or "warning" })
end })
flags:Button({ Title = "Set 't_master' = true", Callback = function()
	Basalt.Flags:Set("t_master", true)
end })
flags:Button({ Title = "Reset all flags", Variant = "danger", Callback = function()
	Basalt.Flags:Reset()
	Basalt:Notify({ Title = "Flags", Content = "reset to defaults", Type = "warning" })
end })
flags:Button({ Title = "Export to clipboard", Callback = function()
	local encoded = Basalt.Config:Export()
	if not encoded then
		Basalt:Notify({ Title = "Export failed", Content = "encode error", Type = "error" })
		return
	end
	local copied = Basalt.Guard.copy(encoded)
	Basalt:Notify({
		Title = copied and "Copied" or "Clipboard unavailable",
		Content = copied and (#encoded .. " bytes") or "executor has no clipboard",
		Type = copied and "success" or "warning",
	})
end })
flags:Button({ Title = "Import test json", Callback = function()
	local ok, applied = Basalt.Config:Import('{"t_master":true,"s_int":77,"d_single":"Torso"}')
	Basalt:Notify({ Title = ok and "Imported" or "Import failed", Content = tostring(applied), Type = ok and "info" or "error" })
end })

-- ======================================================== 7. STRESS
local stress = window:Tab({ Title = "Stress" })

local bulk = stress:Section({ Title = "30 toggles", Column = "left" })
for index = 1, 30 do
	bulk:Toggle({ Key = "stress_toggle_" .. index, Title = "Toggle " .. index, Default = index % 4 == 0 })
end

local heavy = stress:Section({ Title = "Heavy", Column = "right" })
for index = 1, 8 do
	heavy:Slider({ Key = "stress_slider_" .. index, Title = "Slider " .. index, Min = 0, Max = 100, Default = index * 10 })
end
local many = {}
for index = 1, 100 do
	table.insert(many, "Option " .. index)
end
heavy:Dropdown({ Key = "stress_dropdown", Title = "100 options", Values = many, Default = "Option 1" })
heavy:Paragraph({ Text = "This section exists to make the reflow and the scrolling frame work: 30 toggles on the left, 8 sliders and a 100-entry dropdown on the right. Nothing should jitter while scrolling." })

-- ======================================================== 8. DIAGNOSTICS
local diagnostics = window:Tab({ Title = "Diagnostics" })

local build = diagnostics:Section({ Title = "Build", Column = "left" })
build:Label({ Text = "Version: " .. Basalt._VERSION })
build:Label({ Text = "Modules: 27 · single-file build" })
build:Label({ Text = "Theme: " .. window.theme.name })
build:Label({ Text = "Storage: " .. (Basalt.Guard.hasStorage() and "available" or "unavailable") })
build:Label({ Text = "Clipboard: " .. (Basalt.Guard.hasClipboard() and "available" or "unavailable") })
build:Divider()
build:Paragraph({ Text = "Errors are caught, printed to the console and shown as an error toast. If a control misbehaves, note the tab, the control and what you clicked." })

local actions = diagnostics:Section({ Title = "Actions", Column = "right" })
actions:Button({ Title = "Go to Core", Callback = function() window:SelectTab(core) end })
actions:Button({ Title = "Go to Stress", Callback = function() window:SelectTab(stress) end })
actions:Button({ Title = "Hide window for 1s", Callback = function()
	window:SetVisible(false)
	task.delay(1, function()
		window:SetVisible(true)
	end)
end })
actions:Button({ Title = "Notify current theme", Callback = function()
	Basalt:Notify({ Title = "Theme", Content = window.theme.name, Type = "info" })
end })
actions:Button({ Title = "Unload (destroy UI)", Variant = "danger", Callback = function()
	Basalt:Unload()
	print("[Basalt test] unloaded. Re-run the script for a clean load.")
end })

window:Notify({
	Title = "Test suite ready",
	Content = "8 tabs · every component · RightShift toggles",
	Type = "success",
	Duration = 6,
})
