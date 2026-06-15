-- Script Utama RPG Grinder - GUI VERSION
-- Fitur: GUI Draggable, Pilih Target Mob, Toggle ON/OFF

local player = game.Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
local userInputService = game:GetService("UserInputService")
local players = game:GetService("Players")
local runService = game:GetService("RunService")

-- ==========================================
-- SETUP GUI
-- ==========================================
local ScreenGui = Instance.new("ScreenGui")
local MainFrame = Instance.new("Frame")
local TitleLabel = Instance.new("TextLabel")
local TargetButton = Instance.new("TextButton")
local ToggleButton = Instance.new("TextButton")

-- Tentukan parent (CoreGui untuk executor, PlayerGui untuk Roblox Studio)
ScreenGui.Parent = runService:IsStudio() and player:WaitForChild("PlayerGui") or game:GetService("CoreGui")
ScreenGui.Name = "RPG_AutoFarm_GUI"

-- Desain MainFrame
MainFrame.Parent = ScreenGui
MainFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
MainFrame.Position = UDim2.new(0.5, -100, 0.5, -75)
MainFrame.Size = UDim2.new(0, 200, 0, 150)
MainFrame.BorderSizePixel = 2
MainFrame.BorderColor3 = Color3.fromRGB(0, 255, 255)
MainFrame.Active = true
MainFrame.Draggable = true -- Membuat GUI bisa digeser

-- Desain Title
TitleLabel.Parent = MainFrame
TitleLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
TitleLabel.Size = UDim2.new(1, 0, 0, 30)
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.Text = "AUTO FARM GUI"
TitleLabel.TextColor3 = Color3.fromRGB(0, 255, 255)
TitleLabel.TextSize = 14

-- Desain Target Button
TargetButton.Parent = MainFrame
TargetButton.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
TargetButton.Position = UDim2.new(0.1, 0, 0.35, 0)
TargetButton.Size = UDim2.new(0.8, 0, 0, 30)
TargetButton.Font = Enum.Font.Gotham
TargetButton.TextColor3 = Color3.fromRGB(255, 255, 255)
TargetButton.TextSize = 14

-- Desain Toggle Button
ToggleButton.Parent = MainFrame
ToggleButton.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
ToggleButton.Position = UDim2.new(0.1, 0, 0.65, 0)
ToggleButton.Size = UDim2.new(0.8, 0, 0, 35)
ToggleButton.Font = Enum.Font.GothamBold
ToggleButton.Text = "START FARM: OFF"
ToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleButton.TextSize = 14

-- ==========================================
-- VARIABEL & LOGIKA KONTROL
-- ==========================================
local autoTeleportActive = false
local mobList = {"Illusiver", "Pufflare", "Phant", "Orbitfin", "Pico"}
local currentMobIndex = 1
local selectedMob = mobList[currentMobIndex]

-- Inisialisasi teks target awal
TargetButton.Text = "Target: " .. selectedMob

-- Fungsi ganti target mob saat tombol ditekan
TargetButton.MouseButton1Click:Connect(function()
    currentMobIndex = currentMobIndex + 1
    if currentMobIndex > #mobList then
        currentMobIndex = 1
    end
    selectedMob = mobList[currentMobIndex]
    TargetButton.Text = "Target: " .. selectedMob
end)

-- Fungsi cari mob spesifik (hanya mob yang dipilih di GUI)
local function getNearestSpecificMob()
    local nearestMob = nil
    local shortestDist = math.huge
    local playerPos = humanoidRootPart.Position

    for _, object in ipairs(workspace:GetChildren()) do
        -- Hanya cari mob dengan nama yang sedang dipilih di GUI
        if object:IsA("Model") and object.Name == selectedMob and not players:GetPlayerFromCharacter(object) then
            local humanoid = object:FindFirstChild("Humanoid")
            local rootPart = object:FindFirstChild("HumanoidRootPart") or object:FindFirstChild("Torso")

            if humanoid and rootPart and humanoid.Health > 0 then
                local dist = (playerPos - rootPart.Position).Magnitude
                if dist < shortestDist then
                    shortestDist = dist
                    nearestMob = rootPart
                end
            end
        end
    end
    return nearestMob
end

-- ==========================================
-- LOOP AUTO TELEPORT
-- ==========================================
local function startAutoTeleport()
    spawn(function()
        while autoTeleportActive do
            character = player.Character or player.CharacterAdded:Wait()
            humanoidRootPart = character:WaitForChild("HumanoidRootPart", 5)

            if humanoidRootPart then
                local targetPart = getNearestSpecificMob()
                
                if targetPart then
                    -- Teleport sedikit di atas mob
                    humanoidRootPart.CFrame = targetPart.CFrame * CFrame.new(0, 4, 0)
                end
            end
            
            -- Jeda agar tidak lag / kick
            wait(getgenv().TeleportDelay or 0.2) 
        end
    end)
end

-- Fungsi toggle ON/OFF dari GUI
ToggleButton.MouseButton1Click:Connect(function()
    autoTeleportActive = not autoTeleportActive
    
    if autoTeleportActive then
        ToggleButton.BackgroundColor3 = Color3.fromRGB(40, 180, 40)
        ToggleButton.Text = "START FARM: ON"
        print("🚀 AUTO TELEPORT: ON | Target:", selectedMob)
        startAutoTeleport()
    else
        ToggleButton.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
        ToggleButton.Text = "START FARM: OFF"
        print("💤 AUTO TELEPORT: OFF")
    end
end)

print("✅ GUI Auto Farm Berhasil Dimuat!")
