-- Basalt / demo
-- Paste into an executor after building, or replace the URL with a local
-- file path while developing.

local Basalt = loadstring(game:HttpGet("https://raw.githubusercontent.com/you/basalt/main/dist/basalt.luau"))()

local window = Basalt:Window({
	Title = "Basalt",
	Subtitle = "demo build",
	Size = UDim2.fromOffset(780, 520),
	Theme = "basalt-dark",
	ToggleKey = Enum.KeyCode.RightShift,
	Autosave = "demo",
})

local combat = window:Tab({ Title = "Combat" })
local visuals = window:Tab({ Title = "Visuals" })
local settings = window:Tab({ Title = "Settings" })

local aim = combat:Section({ Title = "Aim", Column = "left" })
aim:Toggle({
	Key = "aim_enabled",
	Title = "Enabled",
	Description = "Resolve targets while the key is held",
	Default = false,
})
aim:Slider({
	Key = "aim_smoothing",
	Title = "Smoothing",
	Min = 0,
	Max = 1,
	Rounding = 2,
	Default = 0.35,
})
aim:Range({
	Key = "aim_fov",
	Title = "FOV range",
	Min = 0,
	Max = 180,
	Default = { 40, 120 },
	Suffix = "°",
})
aim:Dropdown({
	Key = "aim_part",
	Title = "Target part",
	Values = { "Head", "Torso", "Nearest" },
	Default = "Head",
})

local input = combat:Section({ Title = "Input", Column = "right" })
input:Keybind({
	Key = "aim_key",
	Title = "Aim key",
	Default = Enum.KeyCode.Mouse4,
})
input:Keybind({
	Key = "panic_key",
	Title = "Panic",
	Default = Enum.KeyCode.End,
})
input:Input({
	Key = "profile_name",
	Title = "Profile name",
	Placeholder = "main",
	Default = "main",
})

local hud = visuals:Section({ Title = "HUD", Column = "left" })
hud:Toggle({ Key = "hud_enabled", Title = "Enabled", Default = true })
hud:Slider({ Key = "hud_scale", Title = "Scale", Min = 0.5, Max = 2, Rounding = 2, Default = 1 })
hud:Colorpicker({ Key = "hud_accent", Title = "Accent", Default = Color3.fromRGB(124, 140, 248) })

local theme = settings:Section({ Title = "Interface", Column = "left" })
theme:Dropdown({
	Key = "theme",
	Title = "Theme",
	Values = { "basalt-dark", "basalt-dusk", "basalt-light", "basalt-contrast" },
	Default = "basalt-dark",
})
theme:Button({
	Title = "Save config",
	Variant = "primary",
	Callback = function()
		local ok, message = Basalt.Config:Save("demo")
		Basalt:Notify({
			Title = ok and "Saved" or "Save failed",
			Content = ok and "demo profile written" or tostring(message),
			Type = ok and "success" or "error",
		})
	end,
})
theme:Button({
	Title = "Reload config",
	Variant = "secondary",
	Callback = function()
		local ok, message = Basalt.Config:Load("demo")
		Basalt:Notify({
			Title = ok and "Loaded" or "Load failed",
			Content = ok and (tostring(message) .. " values applied") or tostring(message),
			Type = ok and "info" or "error",
		})
	end,
})
theme:Divider()
theme:Paragraph({
	Text = "RightShift toggles the window. Search filters every control by name.",
})

-- Keep theme selection in sync with the library.
Basalt.Flags:OnChanged("theme", function(value)
	Basalt:SetTheme(value)
end)

window:Notify({
	Title = "Basalt",
	Content = "Demo loaded. RightShift toggles the window.",
	Type = "info",
	Duration = 5,
})
