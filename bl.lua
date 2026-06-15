-- Script Utama RPG Grinder - GUI VERSION (V3 - BYPASS UUID NAME)
-- Fitur: Baca TextLabel di dalam MobHealthBar, GUI Draggable, Path Spesifik

local player = game.Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
local userInputService = game:GetService("UserInputService")
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
ScreenGui.Name = "RPG_AutoFarm_GUI_V3"

MainFrame.Parent = ScreenGui
MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
MainFrame.Position = UDim2.new(0.5, -100, 0.5, -75)
MainFrame.Size = UDim2.new(0, 200, 0, 150)
MainFrame.BorderSizePixel = 2
MainFrame.BorderColor3 = Color3.fromRGB(255, 170, 0)
MainFrame.Active = true
MainFrame.Draggable = true

TitleLabel.Parent = MainFrame
TitleLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
TitleLabel.Size = UDim2.new(1, 0, 0, 30)
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.Text = "AUTO FARM (BYPASS V3)"
TitleLabel.TextColor3 = Color3.fromRGB(255, 170, 0)
TitleLabel.TextSize = 13

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
    if currentMobIndex > #mobList then currentMobIndex = 1 end
    selectedMob = mobList[currentMobIndex]
    TargetButton.Text = "Target: " .. selectedMob
end)

-- PATH FOLDER MOB (Berdasarkan screenshot Dark Dex kamu)
local function getMobFolder()
    local live = workspace:FindFirstChild("Live")
    if live then
        local mobs = live:FindFirstChild("Mobs")
        if mobs then
            return mobs:FindFirstChild("Client")
        end
    end
    return nil
end

-- Fungsi Cek Nama Mob dari dalam GUI/TextLabel
local function isCorrectMob(model, targetName)
    local targetLower = string.lower(targetName)
    
    -- Cek semua bagian dalam model mob tersebut
    for _, item in ipairs(model:GetDescendants()) do
        -- Cari tulisan di MobHealthBar
        if item:IsA("TextLabel") or item:IsA("TextButton") then
            if item.Text and string.find(string.lower(item.Text), targetLower) then
                return true
            end
        end
    end
    return false
end

-- FUNGSI PENCARIAN TERTARGET KE FOLDER CLIENT
local function getNearestSpecificMob()
    local nearestMob = nil
    local shortestDist = math.huge
    
    if not humanoidRootPart then return nil end
    local playerPos = humanoidRootPart.Position
    
    local mobFolder = getMobFolder()
    if not mobFolder then
        warn("Folder Mobs.Client tidak ditemukan!")
        return nil
    end

    -- Hanya scan isi folder "Client" (Sangat Ringan & Bebas Lag!)
    for _, object in ipairs(mobFolder:GetChildren()) do
        -- Cek apakah objek ini punya HumanoidRootPart dan namanya sesuai dengan GUI-nya
        local rootPart = object:FindFirstChild("HumanoidRootPart")
        
        if rootPart and isCorrectMob(object, selectedMob) then
            local dist = (playerPos - rootPart.Position).Magnitude
            if dist < shortestDist then
                shortestDist = dist
                nearestMob = rootPart
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
                    -- Hentikan momentum agar tidak glitch
                    humanoidRootPart.Velocity = Vector3.new(0, 0, 0)
                    -- Teleport ke atas mob (offset Y=5)
                    humanoidRootPart.CFrame = targetPart.CFrame * CFrame.new(0, 5, 0)
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

print("✅ GUI Auto Farm V3 (Bypass UUID) Berhasil Dimuat!")
