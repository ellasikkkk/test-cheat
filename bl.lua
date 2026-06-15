-- Script Utama RPG Grinder - GUI VERSION (V5 - SEQUENTIAL & AUTO EQUIP FIX)
-- Fitur: Farming Berurutan, Bypass UUID, Tweening, Auto Equip Tool

local player = game.Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
local runService = game:GetService("RunService")
local tweenService = game:GetService("TweenService")
local virtualUser = game:GetService("VirtualUser")

-- ==========================================
-- SETUP GUI
-- ==========================================
local ScreenGui = Instance.new("ScreenGui")
local MainFrame = Instance.new("Frame")
local TitleLabel = Instance.new("TextLabel")
local TargetButton = Instance.new("TextButton")
local ToggleButton = Instance.new("TextButton")

ScreenGui.Parent = runService:IsStudio() and player:WaitForChild("PlayerGui") or game:GetService("CoreGui")
ScreenGui.Name = "RPG_AutoFarm_GUI_V5"

MainFrame.Parent = ScreenGui
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 25, 30)
MainFrame.Position = UDim2.new(0.5, -100, 0.5, -75)
MainFrame.Size = UDim2.new(0, 200, 0, 150)
MainFrame.BorderSizePixel = 2
MainFrame.BorderColor3 = Color3.fromRGB(0, 255, 127) -- Hijau Neon untuk V5
MainFrame.Active = true
MainFrame.Draggable = true

TitleLabel.Parent = MainFrame
TitleLabel.BackgroundColor3 = Color3.fromRGB(15, 20, 25)
TitleLabel.Size = UDim2.new(1, 0, 0, 30)
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.Text = "AUTO FARM (V5 SEQ)"
TitleLabel.TextColor3 = Color3.fromRGB(0, 255, 127)
TitleLabel.TextSize = 13

TargetButton.Parent = MainFrame
TargetButton.BackgroundColor3 = Color3.fromRGB(45, 55, 65)
TargetButton.Position = UDim2.new(0.05, 0, 0.35, 0)
TargetButton.Size = UDim2.new(0.9, 0, 0, 30)
TargetButton.Font = Enum.Font.Gotham
TargetButton.TextColor3 = Color3.fromRGB(255, 255, 255)
TargetButton.TextSize = 13

ToggleButton.Parent = MainFrame
ToggleButton.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
ToggleButton.Position = UDim2.new(0.05, 0, 0.65, 0)
ToggleButton.Size = UDim2.new(0.9, 0, 0, 35)
ToggleButton.Font = Enum.Font.GothamBold
ToggleButton.Text = "START FARM: OFF"
ToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleButton.TextSize = 14

-- ==========================================
-- VARIABEL & PENGATURAN FARMING
-- ==========================================
local autoFarmActive = false

-- Menambahkan opsi "Mode: Semua (Berurutan)" ke dalam daftar
local mobList = {"Illusiver", "Pufflare", "Phant", "Orbitfin", "Pico", "Semua (Berurutan)"}
local sequentialRotation = {"Illusiver", "Pufflare", "Phant", "Orbitfin", "Pico"}
local currentMobIndex = 1
local selectedMob = mobList[currentMobIndex]

local TWEEN_SPEED = 150 
local currentTween = nil

TargetButton.Text = "Target: " .. selectedMob

TargetButton.MouseButton1Click:Connect(function()
    currentMobIndex = currentMobIndex + 1
    if currentMobIndex > #mobList then currentMobIndex = 1 end
    selectedMob = mobList[currentMobIndex]
    TargetButton.Text = "Target: " .. selectedMob
end)

-- ==========================================
-- LOGIKA PENCARIAN & BYPASS (V3)
-- ==========================================
local function getMobFolder()
    local live = workspace:FindFirstChild("Live")
    if live then
        local mobs = live:FindFirstChild("Mobs")
        if mobs then return mobs:FindFirstChild("Client") end
    end
    return nil
end

local function isCorrectMob(model, targetName)
    local targetLower = string.lower(targetName)
    for _, item in ipairs(model:GetDescendants()) do
        if item:IsA("TextLabel") or item:IsA("TextButton") then
            if item.Text and string.find(string.lower(item.Text), targetLower) then
                return true
            end
        end
    end
    return false
end

-- Fungsi ini sekarang menerima parameter nama mob yang ingin dicari
local function getNearestSpecificMob(targetName)
    local nearestMobPart = nil
    local targetModel = nil
    local shortestDist = math.huge
    
    if not humanoidRootPart then return nil, nil end
    local playerPos = humanoidRootPart.Position
    local mobFolder = getMobFolder()
    
    if not mobFolder then return nil, nil end

    for _, object in ipairs(mobFolder:GetChildren()) do
        local rootPart = object:FindFirstChild("HumanoidRootPart")
        if rootPart and isCorrectMob(object, targetName) then
            local dist = (playerPos - rootPart.Position).Magnitude
            if dist < shortestDist then
                shortestDist = dist
                nearestMobPart = rootPart
                targetModel = object
            end
        end
    end
    return nearestMobPart, targetModel
end

-- ==========================================
-- FUNGSI TWEENING
-- ==========================================
local function tweenToTarget(targetCFrame)
    if not humanoidRootPart then return end
    
    local distance = (humanoidRootPart.Position - targetCFrame.Position).Magnitude
    local timeToTravel = distance / TWEEN_SPEED
    local tweenInfo = TweenInfo.new(timeToTravel, Enum.EasingStyle.Linear)
    
    if currentTween then currentTween:Cancel() end
    
    currentTween = tweenService:Create(humanoidRootPart, tweenInfo, {CFrame = targetCFrame})
    currentTween:Play()
    
    local bg = humanoidRootPart:FindFirstChild("AntiGravity")
    if not bg then
        bg = Instance.new("BodyGyro", humanoidRootPart)
        bg.Name = "AntiGravity"
        bg.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
        bg.P = 9e4
    end
    
    local bv = humanoidRootPart:FindFirstChild("AntiFall")
    if not bv then
        bv = Instance.new("BodyVelocity", humanoidRootPart)
        bv.Name = "AntiFall"
        bv.MaxForce = Vector3.new(0, 9e9, 0)
        bv.Velocity = Vector3.new(0, 0, 0)
    end
    return timeToTravel
end

local function cleanupFlight()
    if currentTween then currentTween:Cancel() end
    if humanoidRootPart then
        local bg = humanoidRootPart:FindFirstChild("AntiGravity")
        local bv = humanoidRootPart:FindFirstChild("AntiFall")
        if bg then bg:Destroy() end
        if bv then bv:Destroy() end
    end
end

-- ==========================================
-- LOOP AUTO FARM UTAMA (SEQUENTIAL & AUTO ATTACK)
-- ==========================================
local function startAutoFarmLoop()
    spawn(function()
        local seqIndex = 1 -- Penanda giliran mob mana yang sedang diburu

        while autoFarmActive do
            character = player.Character or player.CharacterAdded:Wait()
            humanoidRootPart = character:WaitForChild("HumanoidRootPart", 5)
            local myHumanoid = character:WaitForChild("Humanoid", 5)

            if humanoidRootPart and myHumanoid then
                
                -- Menentukan target yang harus dicari saat ini
                local currentSearchName = selectedMob
                if selectedMob == "Semua (Berurutan)" then
                    currentSearchName = sequentialRotation[seqIndex]
                end

                local targetPart, targetModel = getNearestSpecificMob(currentSearchName)
                
                if targetPart and targetModel then
                    -- Update Teks GUI agar kamu tahu siapa yang sedang diburu
                    TitleLabel.Text = "HUNTING: " .. string.upper(currentSearchName)

                    local distance = (humanoidRootPart.Position - targetPart.Position).Magnitude
                    
                    if distance > 8 then
                        -- Terbang mendekat
                        local targetPos = targetPart.CFrame * CFrame.new(0, 0, 3) 
                        tweenToTarget(targetPos)
                    else
                        -- Sudah dekat, berhenti terbang
                        cleanupFlight() 
                        
                        -- Tatap monster tersebut
                        humanoidRootPart.CFrame = CFrame.lookAt(humanoidRootPart.Position, targetPart.Position)
                        
                        -- AUTO EQUIP SENJATA & ATTACK
                        local tool = character:FindFirstChildOfClass("Tool")
                        if not tool then
                            local backpackTool = player.Backpack:FindFirstChildOfClass("Tool")
                            if backpackTool then
                                myHumanoid:EquipTool(backpackTool)
                                tool = backpackTool
                            end
                        end
                        
                        if tool then
                            tool:Activate() -- Ayunkan pedang/senjata
                        else
                            virtualUser:CaptureController()
                            virtualUser:ClickButton1(Vector2.new(0,0))
                        end
                    end
                else
                    cleanupFlight()
                    TitleLabel.Text = "MENCARI TARGET..."

                    -- Jika monster sudah mati (tidak ketemu) dan mode Berurutan aktif,
                    -- Pindah ke opsi monster selanjutnya
                    if selectedMob == "Semua (Berurutan)" then
                        seqIndex = seqIndex + 1
                        if seqIndex > #sequentialRotation then
                            seqIndex = 1 -- Kembali ke awal jika sudah sampai Pico
                        end
                    end
                end
            end
            
            runService.Heartbeat:Wait() 
        end
        cleanupFlight()
        TitleLabel.Text = "AUTO FARM (V5 SEQ)"
    end)
end

-- ==========================================
-- TOGGLE KONTROL
-- ==========================================
ToggleButton.MouseButton1Click:Connect(function()
    autoFarmActive = not autoFarmActive
    
    if autoFarmActive then
        ToggleButton.BackgroundColor3 = Color3.fromRGB(40, 180, 40)
        ToggleButton.Text = "START FARM: ON"
        startAutoFarmLoop()
    else
        ToggleButton.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
        ToggleButton.Text = "START FARM: OFF"
        cleanupFlight()
    end
end)

player.Idled:Connect(function()
    virtualUser:ClickButton2(Vector2.new()) 
end)

print("✅ GUI Auto Farm V5 (Sequential & Auto-Equip) Loaded!")
