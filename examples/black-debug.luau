-- Basalt / black-debug
-- Isolates the black screen: clears any leaked BlurEffect, then renders a raw
-- red box plus a minimal Basalt window.

local removed = 0
local okLighting, lighting = pcall(function()
	return game:GetService("Lighting")
end)
if okLighting and lighting then
	for _, child in ipairs(lighting:GetChildren()) do
		if child:IsA("BlurEffect") then
			child:Destroy()
			removed = removed + 1
		end
	end
end
print("[debug] removed " .. removed .. " BlurEffect(s)")

local loaded, Basalt = pcall(function()
	return loadstring(game:HttpGet("https://raw.githubusercontent.com/yusufprogamer100-ai/basalt/main/dist/basalt-v8.luau"))()
end)
if not loaded then
	warn("[debug] library failed: " .. tostring(Basalt))
	return
end
print("[debug] library " .. Basalt._VERSION)

local window = Basalt:Window({ Title = "DBG", Size = UDim2.fromOffset(420, 320) })
local tab = window:Tab({ Title = "T" })
local section = tab:Section({ Title = "Section" })
section:Toggle({ Key = "dbg_t", Title = "toggle", Default = true })
section:Label({ Text = "hello world" })
section:Slider({ Key = "dbg_s", Title = "slider", Min = 0, Max = 100, Default = 50 })
print("[debug] Basalt window built")

-- Raw red box: if this is invisible too, the problem is not Basalt.
local parent = game:GetService("CoreGui") or game:GetService("Players").LocalPlayer.PlayerGui
local gui = Instance.new("ScreenGui")
gui.Name = "DBGRaw"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = parent

local box = Instance.new("Frame")
box.Size = UDim2.fromOffset(320, 70)
box.Position = UDim2.new(0, 20, 0, 20)
box.BackgroundColor3 = Color3.fromRGB(220, 40, 40)
box.Parent = gui

local label = Instance.new("TextLabel")
label.Size = UDim2.new(1, 0, 1, 0)
label.BackgroundTransparency = 1
label.Text = "RED BOX visible = rendering works"
label.TextColor3 = Color3.fromRGB(255, 255, 255)
label.TextSize = 16
label.Parent = box

print("[debug] raw red box placed")
