-- Script Utama RPG Grinder - GUI VERSION (V4 - TWEENING & AUTO KILL)
-- Fitur: Bypass UUID, GUI Draggable, Smooth Tweening, Auto Attack / Instakill

local player = game.Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
local humanoid = character:WaitForChild("Humanoid")
local runService = game:GetService("RunService")
local tweenService = game:GetService("TweenService")
local virtualUser = game:GetService("VirtualUser") -- Untuk Auto Click

-- ==========================================
-- SETUP GUI
-- ==========================================
local ScreenGui = Instance.new("ScreenGui")
local MainFrame = Instance.new("Frame")
local TitleLabel = Instance.new("TextLabel")
local TargetButton = Instance.new("TextButton")
local ToggleButton = Instance.new("TextButton")

ScreenGui.Parent = runService:IsStudio() and player:WaitForChild("PlayerGui") or game:GetService("CoreGui")
ScreenGui.Name = "RPG_AutoFarm_GUI_V4"

MainFrame.Parent = ScreenGui
MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
MainFrame.Position = UDim2.new(0.5, -100, 0.5, -75)
MainFrame.Size = UDim2.new(0, 200, 0, 150)
MainFrame.BorderSizePixel = 2
MainFrame.BorderColor3 = Color3.fromRGB(138, 43, 226) -- Warna ungu untuk V4
MainFrame.Active = true
MainFrame.Draggable = true

TitleLabel.Parent = MainFrame
TitleLabel.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
TitleLabel.Size = UDim2.new(1, 0, 0, 30)
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.Text = "AUTO FARM (V4 TWEEN)"
TitleLabel.TextColor3 = Color3.fromRGB(138, 43, 226)
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
-- VARIABEL & PENGATURAN FARMING
-- ==========================================
local autoFarmActive = false
local mobList = {"Illusiver", "Pufflare", "Phant", "Orbitfin", "Pico"}
local currentMobIndex = 1
local selectedMob = mobList[currentMobIndex]

-- Pengaturan Tween (Kecepatan Terbang)
local TWEEN_SPEED = 150 -- Studs per detik (Ubah angka ini jika masih sering di-kick, turunkan ke 100 atau 50)
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

local function getNearestSpecificMob()
    local nearestMobPart = nil
    local targetModel = nil
    local shortestDist = math.huge
    
    if not humanoidRootPart then return nil, nil end
    local playerPos = humanoidRootPart.Position
    local mobFolder = getMobFolder()
    
    if not mobFolder then return nil, nil end

    for _, object in ipairs(mobFolder:GetChildren()) do
        local rootPart = object:FindFirstChild("HumanoidRootPart")
        if rootPart and isCorrectMob(object, selectedMob) then
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
-- FUNGSI TWEENING & ATTACK
-- ==========================================
local function tweenToTarget(targetCFrame)
    if not humanoidRootPart then return end
    
    -- Hitung jarak untuk menentukan waktu tempuh (Bypass Anti-Cheat)
    local distance = (humanoidRootPart.Position - targetCFrame.Position).Magnitude
    local timeToTravel = distance / TWEEN_SPEED
    
    local tweenInfo = TweenInfo.new(timeToTravel, Enum.EasingStyle.Linear)
    
    -- Batalkan tween sebelumnya jika ada
    if currentTween then currentTween:Cancel() end
    
    -- Buat dan mainkan tween baru
    currentTween = tweenService:Create(humanoidRootPart, tweenInfo, {CFrame = targetCFrame})
    currentTween:Play()
    
    -- Nonaktifkan gravitasi sementara agar terbang lurus dan tidak jatuh
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
-- LOOP AUTO FARM UTAMA
-- ==========================================
local function startAutoFarmLoop()
    spawn(function()
        while autoFarmActive do
            character = player.Character or player.CharacterAdded:Wait()
            humanoidRootPart = character:WaitForChild("HumanoidRootPart", 5)

            if humanoidRootPart then
                local targetPart, targetModel = getNearestSpecificMob()
                
                if targetPart and targetModel then
                    -- Jarak antara pemain dan mob
                    local distance = (humanoidRootPart.Position - targetPart.Position).Magnitude
                    
                    if distance > 10 then
                        -- Jika jauh, terbang ke mob (Berada sedikit di belakang/atas mob)
                        local targetPos = targetPart.CFrame * CFrame.new(0, 0, 3) 
                        tweenToTarget(targetPos)
                    else
                        -- Jika sudah dekat (Nempel dengan mob)
                        cleanupFlight() -- Matikan mode terbang
                        humanoidRootPart.CFrame = targetPart.CFrame * CFrame.new(0, 0, 3)
                        
                        -- 1. ATTEMPT INSTANT KILL (Client-Side Force)
                        local mobHum = targetModel:FindFirstChildOfClass("Humanoid")
                        if mobHum then mobHum.Health = 0 end
                        
                        -- 2. AUTO CLICKER SPAM (Server-Side Validation)
                        -- Menggunakan virtualUser untuk klik layar secara terus menerus
                        virtualUser:CaptureController()
                        virtualUser:ClickButton1(Vector2.new(0,0))
                    end
                else
                    cleanupFlight()
                end
            end
            
            -- Jeda loop super cepat agar auto-click responsif
            runService.Heartbeat:Wait() 
        end
        -- Bersihkan efek terbang saat dimatikan
        cleanupFlight()
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
        print("🚀 AUTO FARM V4 MULAI | Target:", selectedMob)
        startAutoFarmLoop()
    else
        ToggleButton.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
        ToggleButton.Text = "START FARM: OFF"
        print("💤 AUTO FARM BERHENTI")
        cleanupFlight()
    end
end)

-- Memastikan kamera mengikuti karakter agar klik akurat
player.Idled:Connect(function()
    virtualUser:ClickButton2(Vector2.new()) -- Anti AFK Disconnect
end)

print("✅ GUI Auto Farm V4 (Tween & Kill) Loaded!")
