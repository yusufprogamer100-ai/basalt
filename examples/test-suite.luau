-- Basalt / test suite
-- Every public feature in one window. Run it, click everything, and report
-- the first error you see. Nothing here touches the game.

local LIBRARY = "https://raw.githubusercontent.com/yusufprogamer100-ai/basalt/main/dist/basalt.luau?v=3"

local loaded, Basalt = pcall(function()
	return loadstring(game:HttpGet(LIBRARY))()
end)

if not loaded then
	warn("[Basalt test] library failed to load: " .. tostring(Basalt))
	return
end

print(("[Basalt test] %s %s loaded"):format(Basalt.Name, Basalt._VERSION))

local function guard(label, callback)
	local ok, err = pcall(callback)
	if not ok then
		warn("[Basalt test] " .. label .. ": " .. tostring(err))
		Basalt:Notify({ Title = label, Content = tostring(err), Type = "error", Duration = 10 })
	end
	return ok
end

local window = Basalt:Window({
	Title = "Basalt",
	Subtitle = "test suite " .. Basalt._VERSION,
	Size = UDim2.fromOffset(820, 540),
	Theme = "basalt-dark",
	ToggleKey = Enum.KeyCode.RightShift,
})

-- ============================================================ 1. CORE
local core = window:Tab({ Title = "Core" })

local toggles = core:Section({ Title = "Toggles", Column = "left" })
toggles:Toggle({
	Key = "core_master",
	Title = "Master",
	Description = "On by default, two-line row",
	Default = true,
})
toggles:Toggle({ Key = "core_plain", Title = "Plain row", Default = false })
local disabledToggle = toggles:Toggle({ Key = "core_disabled", Title = "Disabled", Default = true })
disabledToggle:SetDisabled(true)

local sliders = core:Section({ Title = "Sliders", Column = "left" })
sliders:Slider({ Key = "core_int", Title = "Integer", Min = 0, Max = 100, Default = 42 })
sliders:Slider({ Key = "core_float", Title = "Float", Min = 0, Max = 1, Rounding = 2, Default = 0.35 })
sliders:Slider({ Key = "core_suffix", Title = "With suffix", Min = 0, Max = 240, Default = 120, Suffix = " ms" })
local disabledSlider = sliders:Slider({ Key = "core_slider_off", Title = "Disabled", Min = 0, Max = 10, Default = 5 })
disabledSlider:SetDisabled(true)

local ranges = core:Section({ Title = "Range", Column = "right" })
ranges:Range({ Key = "core_range", Title = "FOV", Min = 0, Max = 180, Default = { 40, 120 }, Suffix = "°" })

local dropdowns = core:Section({ Title = "Dropdowns", Column = "right" })
dropdowns:Dropdown({
	Key = "core_dropdown",
	Title = "Single",
	Values = { "Head", "Torso", "Nearest", "Random" },
	Default = "Head",
})
dropdowns:Dropdown({
	Key = "core_multi",
	Title = "Multi",
	Values = { "ESP", "Tracers", "Boxes", "Names" },
	Default = { "ESP", "Names" },
	Multi = true,
})
local disabledDropdown = dropdowns:Dropdown({
	Key = "core_dropdown_off",
	Title = "Disabled",
	Values = { "A", "B" },
	Default = "A",
})
disabledDropdown:SetDisabled(true)

-- ============================================================ 2. INPUT
local inputTab = window:Tab({ Title = "Input" })

local keys = inputTab:Section({ Title = "Keybinds", Column = "left" })
keys:Keybind({ Key = "input_key", Title = "Primary", Default = Enum.KeyCode.Mouse4 })
keys:Keybind({ Key = "input_panic", Title = "Panic", Default = Enum.KeyCode.End })
local keyOff = keys:Keybind({ Key = "input_key_off", Title = "Disabled", Default = Enum.KeyCode.F })
keyOff:SetDisabled(true)

local textFields = inputTab:Section({ Title = "Text", Column = "left" })
textFields:Input({ Key = "input_name", Title = "Name", Placeholder = "type here", Default = "basalt" })
textFields:Input({ Key = "input_number", Title = "Numeric", Placeholder = "0-100", Numeric = true, Default = "50" })
textFields:Input({ Key = "input_long", Title = "Long placeholder", Placeholder = "this placeholder is intentionally long to test truncation" })

local colors = inputTab:Section({ Title = "Color", Column = "right" })
colors:Colorpicker({ Key = "input_accent", Title = "Accent", Default = Color3.fromRGB(124, 140, 248) })
colors:Colorpicker({ Key = "input_alert", Title = "Alert", Default = Color3.fromRGB(224, 104, 95) })

local buttons = inputTab:Section({ Title = "Buttons", Column = "right" })
buttons:Button({ Title = "Primary", Variant = "primary", Callback = function()
	Basalt:Notify({ Title = "Primary", Content = "primary button pressed", Type = "success" })
end })
buttons:Button({ Title = "Secondary", Callback = function()
	Basalt:Notify({ Title = "Secondary", Content = "secondary button pressed" })
end })
buttons:Button({ Title = "Quiet", Variant = "quiet", Callback = function()
	Basalt:Notify({ Title = "Quiet", Content = "quiet button pressed" })
end })
buttons:Button({ Title = "Danger", Variant = "danger", Callback = function()
	Basalt:Notify({ Title = "Danger", Content = "danger button pressed", Type = "warning" })
end })
local disabledButton = buttons:Button({ Title = "Disabled", Callback = function() end })
disabledButton:SetDisabled(true)

-- ============================================================ 3. LAYOUT
local layout = window:Tab({ Title = "Layout" })

local left = layout:Section({ Title = "Left column", Column = "left" })
left:SetBadge("3 on")
left:Label({ Text = "Label — plain text, one line" })
left:Label({ Text = "Muted label", Muted = true })
left:Paragraph({ Text = "Paragraph: wrapped body copy. It should wrap inside the column without overflowing and without a manual height. Resize the window or collapse a section to watch the reflow." })
left:Divider()
left:Space(12)
left:Label({ Text = "Space above is 12px" })

local collapsed = layout:Section({ Title = "Collapsed section", Column = "left" })
collapsed:Toggle({ Key = "layout_collapsed_toggle", Title = "Hidden until expanded" })
collapsed:SetCollapsed(true)

local right = layout:Section({ Title = "Right column", Column = "right" })
for index = 1, 14 do
	right:Toggle({
		Key = "layout_bulk_" .. index,
		Title = "Bulk toggle " .. index,
		Default = index % 3 == 0,
	})
end

local search = layout:Section({ Title = "Search test", Column = "right" })
search:Paragraph({ Text = "Type 'bulk' or 'slider' in the header search box. Rows filter live; sections with no match hide themselves." })
search:Slider({ Key = "layout_search_slider", Title = "Findable slider", Min = 0, Max = 10, Default = 3 })

-- ============================================================ 4. THEME
local theme = window:Tab({ Title = "Theme" })

local presets = theme:Section({ Title = "Presets", Column = "left" })
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

local notifications = theme:Section({ Title = "Notifications", Column = "right" })
notifications:Button({ Title = "Info", Callback = function()
	Basalt:Notify({ Title = "Info", Content = "informational toast", Type = "info" })
end })
notifications:Button({ Title = "Success", Callback = function()
	Basalt:Notify({ Title = "Success", Content = "operation completed", Type = "success" })
end })
notifications:Button({ Title = "Warning", Callback = function()
	Basalt:Notify({ Title = "Warning", Content = "something needs attention", Type = "warning" })
end })
notifications:Button({ Title = "Error", Callback = function()
	Basalt:Notify({ Title = "Error", Content = "something failed", Type = "error" })
end })
notifications:Button({ Title = "Long text", Callback = function()
	Basalt:Notify({
		Title = "Long notification",
		Content = "This toast has a much longer body so wrapping, height and the progress bar can all be checked at once.",
		Type = "info",
		Duration = 8,
	})
end })
notifications:Button({ Title = "Sticky", Callback = function()
	Basalt:Notify({ Title = "Sticky", Content = "no duration, must be closed by hand", Duration = 0 })
end })
notifications:Button({ Title = "Burst 6", Callback = function()
	for index = 1, 6 do
		Basalt:Notify({ Title = "Burst " .. index, Content = "cap is four visible", Type = "info", Duration = 6 })
	end
end })

-- ============================================================ 5. CONFIG
local configTab = window:Tab({ Title = "Config" })

local profileSection = configTab:Section({ Title = "Profile", Column = "left" })
local profileName = profileSection:Input({ Key = "cfg_profile", Title = "Profile name", Default = "test" })

profileSection:Button({ Title = "Save", Variant = "primary", Callback = function()
	local ok, message = Basalt.Config:Save(profileName:Get())
	Basalt:Notify({
		Title = ok and "Saved" or "Save failed",
		Content = ok and tostring(message) or tostring(message),
		Type = ok and "success" or "error",
	})
end })
profileSection:Button({ Title = "Load", Callback = function()
	local ok, message = Basalt.Config:Load(profileName:Get())
	Basalt:Notify({
		Title = ok and "Loaded" or "Load failed",
		Content = ok and (tostring(message) .. " values applied") or tostring(message),
		Type = ok and "info" or "error",
	})
end })
profileSection:Button({ Title = "Delete", Variant = "danger", Callback = function()
	local ok = Basalt.Config:Delete(profileName:Get())
	Basalt:Notify({ Title = ok and "Deleted" or "Delete failed", Content = profileName:Get(), Type = ok and "warning" or "error" })
end })
profileSection:Button({ Title = "List profiles", Callback = function()
	local list = Basalt.Config:List()
	Basalt:Notify({ Title = "Profiles", Content = #list .. ": " .. table.concat(list, ", "), Type = "info", Duration = 8 })
end })

local dataSection = configTab:Section({ Title = "Data", Column = "right" })
dataSection:Button({ Title = "Export to clipboard", Callback = function()
	local encoded = Basalt.Config:Export()
	if not encoded then
		Basalt:Notify({ Title = "Export failed", Content = "json encode error", Type = "error" })
		return
	end
	local copied = Basalt.Guard.copy(encoded)
	Basalt:Notify({
		Title = copied and "Copied" or "Clipboard unavailable",
		Content = copied and (#encoded .. " bytes of json") or "executor has no clipboard",
		Type = copied and "success" or "warning",
	})
end })
dataSection:Button({ Title = "Import test json", Callback = function()
	local ok, applied = Basalt.Config:Import('{"core_master":true,"core_int":77,"core_dropdown":"Torso"}')
	Basalt:Notify({
		Title = ok and "Imported" or "Import failed",
		Content = ok and (tostring(applied) .. " values applied") or tostring(applied),
		Type = ok and "info" or "error",
	})
end })
dataSection:Button({ Title = "Dump flags", Callback = function()
	local values = Basalt.Flags:Snapshot()
	local count = 0
	for _ in pairs(values) do
		count = count + 1
	end
	print("[Basalt test] flag count:", count)
	Basalt:Notify({ Title = "Flags", Content = count .. " registered keys (see console)", Type = "info" })
end })

-- ============================================================ 6. DIAGNOSTICS
local diagnostics = window:Tab({ Title = "Diagnostics" })

local info = diagnostics:Section({ Title = "Build", Column = "left" })
info:Label({ Text = "Version: " .. Basalt._VERSION })
info:Label({ Text = "Modules: 27 · single file build" })
info:Label({ Text = "Storage: " .. (Basalt.Guard.hasStorage() and "available" or "unavailable") })
info:Label({ Text = "Clipboard: " .. (Basalt.Guard.hasClipboard() and "available" or "unavailable") })
info:Divider()
info:Paragraph({ Text = "If something throws, the error is caught, printed to the console and shown as an error toast. Screenshot the toast or copy the console line." })

local actions = diagnostics:Section({ Title = "Actions", Column = "right" })
actions:Button({ Title = "Re-notify version", Callback = function()
	Basalt:Notify({ Title = "Basalt", Content = Basalt._VERSION, Type = "info" })
end })
actions:Button({ Title = "Toggle window", Callback = function()
	window:SetVisible(false)
	task.delay(1, function()
		window:SetVisible(true)
	end)
end })
actions:Button({ Title = "Unload (destroys UI)", Variant = "danger", Callback = function()
	Basalt:Unload()
	print("[Basalt test] unloaded. Re-run the script to test a clean load.")
end })

window:Notify({
	Title = "Test suite ready",
	Content = "6 tabs · every component · RightShift toggles the window",
	Type = "success",
	Duration = 6,
})
