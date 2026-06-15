-- Script Utama RPG Grinder - GUI VERSION (V7 - CLEAN & MULTI-SELECT)
-- Fitur: Multi-Select, Sequential Farming, Clean Design

local player = game.Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
local runService = game:GetService("RunService")
local tweenService = game:GetService("TweenService")
local virtualUser = game:GetService("VirtualUser")

-- ==========================================
-- SETUP GUI (CLEAN & MODERN)
-- ==========================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Parent = game:GetService("CoreGui")
ScreenGui.Name = "RPG_Grinder_Clean"

local MainFrame = Instance.new("Frame")
MainFrame.Parent = ScreenGui
MainFrame.Size = UDim2.new(0, 220, 0, 300)
MainFrame.Position = UDim2.new(0.1, 0, 0.2, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true

-- Rounded Corner untuk tampilan modern
local Corner = Instance.new("UICorner", MainFrame)
Corner.CornerRadius = UDim.new(0, 8)

local Title = Instance.new("TextLabel", MainFrame)
Title.Size = UDim2.new(1, 0, 0, 40)
Title.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
Title.Text = "RPG GRINDER V7"
Title.Font = Enum.Font.GothamBold
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 14

local ListContainer = Instance.new("Frame", MainFrame)
ListContainer.Size = UDim2.new(0.9, 0, 0.6, 0)
ListContainer.Position = UDim2.new(0.05, 0, 0.15, 0)
ListContainer.BackgroundTransparency = 1

local Layout = Instance.new("UIListLayout", ListContainer)
Layout.Padding = UDim.new(0, 5)

-- ==========================================
-- LOGIKA TOMBOL MOB
-- ==========================================
local targetSettings = {
    {name = "Illusiver", active = false},
    {name = "Pufflare", active = false},
    {name = "Phant", active = false},
    {name = "Orbitfin", active = false},
    {name = "Pico", active = false}
}

for _, mobData in ipairs(targetSettings) do
    local btn = Instance.new("TextButton", ListContainer)
    btn.Size = UDim2.new(1, 0, 0, 30)
    btn.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
    btn.Text = mobData.name
    btn.Font = Enum.Font.Gotham
    btn.TextColor3 = Color3.fromRGB(200, 200, 200)
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)
    
    btn.MouseButton1Click:Connect(function()
        mobData.active = not mobData.active
        btn.BackgroundColor3 = mobData.active and Color3.fromRGB(0, 150, 255) or Color3.fromRGB(50, 50, 55)
        btn.TextColor3 = mobData.active and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(200, 200, 200)
    end)
end

-- ==========================================
-- TOMBOL START/STOP
-- ==========================================
local ToggleBtn = Instance.new("TextButton", MainFrame)
ToggleBtn.Size = UDim2.new(0.9, 0, 0, 40)
ToggleBtn.Position = UDim2.new(0.05, 0, 0.82, 0)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
ToggleBtn.Text = "START FARM"
ToggleBtn.Font = Enum.Font.GothamBold
ToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
Instance.new("UICorner", ToggleBtn).CornerRadius = UDim.new(0, 5)

-- [Sertakan fungsi getMobFolder, isCorrectMob, getNearestSpecificMob, tweenToTarget, cleanupFlight dari script V6 sebelumnya di sini]

local autoFarmActive = false
ToggleBtn.MouseButton1Click:Connect(function()
    autoFarmActive = not autoFarmActive
    ToggleBtn.Text = autoFarmActive and "STOP FARM" or "START FARM"
    ToggleBtn.BackgroundColor3 = autoFarmActive and Color3.fromRGB(200, 50, 50) or Color3.fromRGB(0, 200, 100)
    if autoFarmActive then 
        -- Panggil fungsi startAutoFarmLoop kamu di sini
    else
        -- Panggil fungsi cleanupFlight kamu di sini
    end
end)

print("✅ GUI Clean V7 Loaded!")
