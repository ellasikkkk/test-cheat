-- Script Utama RPG Grinder - GUI VERSION (V2 - FIX TELEPORT)
-- Fitur: GUI Draggable, Pilih Target Mob, Toggle ON/OFF, Advanced Scanning

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

ScreenGui.Parent = runService:IsStudio() and player:WaitForChild("PlayerGui") or game:GetService("CoreGui")
ScreenGui.Name = "RPG_AutoFarm_GUI"

MainFrame.Parent = ScreenGui
MainFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
MainFrame.Position = UDim2.new(0.5, -100, 0.5, -75)
MainFrame.Size = UDim2.new(0, 200, 0, 150)
MainFrame.BorderSizePixel = 2
MainFrame.BorderColor3 = Color3.fromRGB(0, 255, 255)
MainFrame.Active = true
MainFrame.Draggable = true

TitleLabel.Parent = MainFrame
TitleLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
TitleLabel.Size = UDim2.new(1, 0, 0, 30)
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.Text = "AUTO FARM GUI V2"
TitleLabel.TextColor3 = Color3.fromRGB(0, 255, 255)
TitleLabel.TextSize = 14

TargetButton.Parent = MainFrame
TargetButton.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
TargetButton.Position = UDim2.new(0.1, 0, 0.35, 0)
TargetButton.Size = UDim2.new(0.8, 0, 0, 30)
TargetButton.Font = Enum.Font.Gotham
TargetButton.TextColor3 = Color3.fromRGB(255, 255, 255)
TargetButton.TextSize = 14

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

TargetButton.Text = "Target: " .. selectedMob

TargetButton.MouseButton1Click:Connect(function()
    currentMobIndex = currentMobIndex + 1
    if currentMobIndex > #mobList then
        currentMobIndex = 1
    end
    selectedMob = mobList[currentMobIndex]
    TargetButton.Text = "Target: " .. selectedMob
end)

-- FUNGSI PENCARIAN YANG SUDAH DIPERBAIKI (ADVANCED SCAN)
local function getNearestSpecificMob()
    local nearestMob = nil
    local shortestDist = math.huge
    local playerPos = humanoidRootPart.Position

    -- Menggunakan GetDescendants agar mengecek semua folder di workspace
    for _, object in ipairs(workspace:GetDescendants()) do
        -- Cek apakah dia Model dan namanya "mengandung" nama target (antisipasi ada label level)
        if object:IsA("Model") and string.find(object.Name, selectedMob) and not players:GetPlayerFromCharacter(object) then
            -- Cari humanoid dengan Class (lebih aman)
            local humanoid = object:FindFirstChildOfClass("Humanoid") 
            -- Prioritaskan PrimaryPart, lalu RootPart, lalu Torso
            local rootPart = object.PrimaryPart or object:FindFirstChild("HumanoidRootPart") or object:FindFirstChild("Torso") or object:FindFirstChild("UpperTorso")

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
                    -- Matikan momentum jatuh agar tidak glitch saat teleport
                    humanoidRootPart.Velocity = Vector3.new(0, 0, 0)
                    
                    -- Teleport ke titik mob (ditambah offset Y=5 agar di atas kepalanya sedikit)
                    humanoidRootPart.CFrame = targetPart.CFrame * CFrame.new(0, 5, 0)
                else
                    -- Jika mob tidak ditemukan di map, kasih peringatan di console
                    warn("Menunggu mob " .. selectedMob .. " respawn...")
                end
            end
            
            wait(0.2) -- Jeda teleport
        end
    end)
end

-- ==========================================
-- TOGGLE KONTROL
-- ==========================================
ToggleButton.MouseButton1Click:Connect(function()
    autoTeleportActive = not autoTeleportActive
    
    if autoTeleportActive then
        ToggleButton.BackgroundColor3 = Color3.fromRGB(40, 180, 40)
        ToggleButton.Text = "START FARM: ON"
        startAutoTeleport()
    else
        ToggleButton.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
        ToggleButton.Text = "START FARM: OFF"
    end
end)

print("✅ GUI Auto Farm V2 (Fix Teleport) Loaded!")
