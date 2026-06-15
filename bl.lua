-- Script Utama RPG Grinder - GUI VERSION (V6 - MULTI-SELECT SEQUENTIAL)
-- Fitur: Pilih Banyak Mob, Farming Berurutan, GUI Checkbox, Bypass UUID, Tweening

local player = game.Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
local runService = game:GetService("RunService")
local tweenService = game:GetService("TweenService")
local virtualUser = game:GetService("VirtualUser")

-- ==========================================
-- SETUP GUI BARU (MULTI-SELECT)
-- ==========================================
local ScreenGui = Instance.new("ScreenGui")
local MainFrame = Instance.new("Frame")
local TitleLabel = Instance.new("TextLabel")
local MobListFrame = Instance.new("Frame")
local UIListLayout = Instance.new("UIListLayout")
local ToggleButton = Instance.new("TextButton")

ScreenGui.Parent = runService:IsStudio() and player:WaitForChild("PlayerGui") or game:GetService("CoreGui")
ScreenGui.Name = "RPG_AutoFarm_GUI_V6"

MainFrame.Parent = ScreenGui
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 25, 30)
MainFrame.Position = UDim2.new(0.5, -100, 0.5, -125)
MainFrame.Size = UDim2.new(0, 200, 0, 280) -- Diperpanjang untuk daftar mob
MainFrame.BorderSizePixel = 2
MainFrame.BorderColor3 = Color3.fromRGB(0, 200, 255)
MainFrame.Active = true
MainFrame.Draggable = true

TitleLabel.Parent = MainFrame
TitleLabel.BackgroundColor3 = Color3.fromRGB(15, 20, 25)
TitleLabel.Size = UDim2.new(1, 0, 0, 30)
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.Text = "AUTO FARM (V6 MULTI)"
TitleLabel.TextColor3 = Color3.fromRGB(0, 200, 255)
TitleLabel.TextSize = 13

-- Tempat untuk tombol-tombol pilihan mob
MobListFrame.Parent = MainFrame
MobListFrame.BackgroundTransparency = 1
MobListFrame.Position = UDim2.new(0.05, 0, 0.15, 0)
MobListFrame.Size = UDim2.new(0.9, 0, 0, 180)

UIListLayout.Parent = MobListFrame
UIListLayout.Padding = UDim.new(0, 5)
UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder

ToggleButton.Parent = MainFrame
ToggleButton.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
ToggleButton.Position = UDim2.new(0.05, 0, 0.85, 0)
ToggleButton.Size = UDim2.new(0.9, 0, 0, 35)
ToggleButton.Font = Enum.Font.GothamBold
ToggleButton.Text = "START FARM: OFF"
ToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleButton.TextSize = 14

-- ==========================================
-- VARIABEL & PENGATURAN FARMING
-- ==========================================
local autoFarmActive = false
local TWEEN_SPEED = 150 
local currentTween = nil

-- Status ON/OFF untuk setiap mob
local targetSettings = {
    {name = "Illusiver", active = false},
    {name = "Pufflare", active = false},
    {name = "Phant", active = false},
    {name = "Orbitfin", active = false},
    {name = "Pico", active = false}
}

-- Membuat tombol untuk setiap mob secara otomatis
for i, mobData in ipairs(targetSettings) do
    local btn = Instance.new("TextButton")
    btn.Parent = MobListFrame
    btn.Size = UDim2.new(1, 0, 0, 30)
    btn.BackgroundColor3 = Color3.fromRGB(45, 55, 65)
    btn.Font = Enum.Font.Gotham
    btn.Text = "❌ " .. mobData.name
    btn.TextColor3 = Color3.fromRGB(200, 200, 200)
    btn.TextSize = 13
    
    -- Fungsi jika mob ini diklik
    btn.MouseButton1Click:Connect(function()
        mobData.active = not mobData.active
        if mobData.active then
            btn.BackgroundColor3 = Color3.fromRGB(40, 120, 80)
            btn.Text = "✅ " .. mobData.name
            btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        else
            btn.BackgroundColor3 = Color3.fromRGB(45, 55, 65)
            btn.Text = "❌ " .. mobData.name
            btn.TextColor3 = Color3.fromRGB(200, 200, 200)
        end
    end)
end

-- Fungsi untuk mendapatkan daftar mob yang sedang dicentang (aktif)
local function getActiveMobsList()
    local list = {}
    for _, mob in ipairs(targetSettings) do
        if mob.active then
            table.insert(list, mob.name)
        end
    end
    return list
end

-- ==========================================
-- LOGIKA PENCARIAN & BYPASS
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
-- LOOP AUTO FARM UTAMA (MULTI-SEQUENTIAL)
-- ==========================================
local function startAutoFarmLoop()
    spawn(function()
        local seqIndex = 1 

        while autoFarmActive do
            character = player.Character or player.CharacterAdded:Wait()
            humanoidRootPart = character:WaitForChild("HumanoidRootPart", 5)
            local myHumanoid = character:WaitForChild("Humanoid", 5)

            -- Dapatkan daftar mob yang dipilih pengguna secara real-time
            local activeMobs = getActiveMobsList()

            if humanoidRootPart and myHumanoid and #activeMobs > 0 then
                
                -- Pastikan index tidak melebihi jumlah mob yang dipilih
                if seqIndex > #activeMobs then seqIndex = 1 end
                
                local currentSearchName = activeMobs[seqIndex]
                local targetPart, targetModel = getNearestSpecificMob(currentSearchName)
                
                if targetPart and targetModel then
                    -- Update Title dengan mob yang sedang diserang
                    TitleLabel.Text = "HUNT: " .. string.upper(currentSearchName)

                    local distance = (humanoidRootPart.Position - targetPart.Position).Magnitude
                    
                    if distance > 8 then
                        local targetPos = targetPart.CFrame * CFrame.new(0, 0, 3) 
                        tweenToTarget(targetPos)
                    else
                        cleanupFlight() 
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
                            tool:Activate()
                        else
                            virtualUser:CaptureController()
                            virtualUser:ClickButton1(Vector2.new(0,0))
                        end
                    end
                else
                    cleanupFlight()
                    TitleLabel.Text = "TARGET HABIS, NEXT!"

                    -- Jika monster yang dicari tidak ada (mati/habis), pindah ke monster selanjutnya di daftar pilihan
                    seqIndex = seqIndex + 1
                    if seqIndex > #activeMobs then
                        seqIndex = 1 -- Putar ulang ke awal daftar pilihan
                    end
                end
            elseif #activeMobs == 0 then
                TitleLabel.Text = "PILIH MOB DULU!"
                cleanupFlight()
            end
            
            runService.Heartbeat:Wait() 
        end
        cleanupFlight()
        TitleLabel.Text = "AUTO FARM (V6 MULTI)"
    end)
end

-- ==========================================
-- TOGGLE KONTROL
-- ==========================================
ToggleButton.MouseButton1Click:Connect(function()
    autoFarmActive = not autoFarmActive
    
    if autoFarmActive then
        local activeMobs = getActiveMobsList()
        if #activeMobs == 0 then
            -- Tolak start jika tidak ada mob yang dipilih
            autoFarmActive = false
            TitleLabel.Text = "⚠️ Piliih Min. 1 Mob!"
            wait(2)
            TitleLabel.Text = "AUTO FARM (V6 MULTI)"
            return
        end

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

print("✅ GUI Auto Farm V6 (Multi-Select) Loaded!")
