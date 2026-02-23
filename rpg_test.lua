-- Script Utama RPG Grinder - FLOATING MODE + GUI LENGKAP
-- FIX: Memperbaiki error "attempt to call a nil value"

local player = game.Players.LocalPlayer
local userInputService = game:GetService("UserInputService")
local runService = game:GetService("RunService")
local players = game:GetService("Players")
local tweenService = game:GetService("TweenService")

-- VARIABEL GLOBAL
local floatingActive = false
local currentTarget = nil
local floatDistance = 5
local character = nil
local humanoidRootPart = nil

-- VARIABEL ANTI-LAG
local searchCooldown = 0
local noMobCount = 0
local lastSearchTime = 0
local SEARCH_DELAY_NORMAL = 0.5
local SEARCH_DELAY_LOW = 2
local SEARCH_DELAY_IDLE = 5
local MAX_NO_MOB_COUNT = 5

-- VARIABEL GUI
local updateGUIFunc = nil  -- Akan diisi nanti

-- =============================================
-- FUNGSI-FUNGSI UTAMA (DIDEFINISIKAN DULU)
-- =============================================

-- FUNGSI: Update referensi karakter
local function updateCharacter()
    character = player.Character
    if character then
        humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
        if not humanoidRootPart then
            humanoidRootPart = character:WaitForChild("HumanoidRootPart")
        end
        print("✅ Karakter ditemukan:", character.Name)
        return true
    end
    return false
end

-- FUNGSI: Tunggu karakter respawn
local function waitForCharacter()
    print("⏳ Menunggu karakter respawn...")
    character = player.Character or player.CharacterAdded:Wait()
    humanoidRootPart = character:WaitForChild("HumanoidRootPart")
    print("✅ Karakter telah respawn!")
    return true
end

-- FUNGSI: Mendapatkan mob terdekat
local function getNearestMob(range)
    if not humanoidRootPart then return nil end
    
    local nearestMob = nil
    local shortestDistance = range or math.huge
    local playerPos = humanoidRootPart.Position
    
    local searchRange = (range or 50) * 1.5
    local region = Region3.new(
        playerPos - Vector3.new(searchRange, searchRange, searchRange),
        playerPos + Vector3.new(searchRange, searchRange, searchRange)
    )
    
    -- Protect from errors
    local parts = {}
    pcall(function()
        parts = workspace:FindPartsInRegion3(region, nil, 100)
    end)
    
    for _, part in ipairs(parts) do
        local obj = part.Parent
        if obj and obj:IsA("Model") and obj:FindFirstChild("Humanoid") and not players:GetPlayerFromCharacter(obj) then
            local mobRoot = obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChild("Torso")
            if mobRoot then
                local humanoid = obj:FindFirstChild("Humanoid")
                if humanoid and humanoid.Health > 0 then
                    local distance = (playerPos - mobRoot.Position).Magnitude
                    if distance < shortestDistance and distance <= (range or 50) then
                        shortestDistance = distance
                        nearestMob = {
                            model = obj,
                            rootPart = mobRoot,
                            humanoid = humanoid,
                            lastHealth = humanoid.Health
                        }
                    end
                end
            end
        end
    end
    
    return nearestMob
end

-- FUNGSI: Teleport ke BELAKANG mob
local function floatBehindMob(mob)
    if not mob or not mob.rootPart or not humanoidRootPart then return end
    
    local success, result = pcall(function()
        local mobPosition = mob.rootPart.Position
        local mobDirection = mob.rootPart.CFrame.LookVector
        local behindPosition = mobPosition - (mobDirection * floatDistance)
        behindPosition = behindPosition + Vector3.new(0, 2, 0)
        local lookAtMob = CFrame.lookAt(behindPosition, mobPosition)
        humanoidRootPart.CFrame = lookAtMob
    end)
    
    if not success then
        print("⚠️ Error saat teleport:", result)
    end
end

-- FUNGSI: Cek apakah mob masih hidup
local function isMobAlive(mob)
    if not mob then return false end
    if not mob.model or not mob.model.Parent then return false end
    if not mob.humanoid then return false end
    
    local success, health = pcall(function()
        return mob.humanoid.Health
    end)
    
    if not success or health <= 0 then return false end
    
    if not mob.rootPart or not mob.rootPart.Parent then return false end
    return true
end

-- FUNGSI: Cari target baru (DENGAN ANTI-LAG)
local function findNewTarget()
    if not humanoidRootPart then 
        return 
    end
    
    local currentTime = tick()
    if currentTime - lastSearchTime < searchCooldown then
        return
    end
    
    local mob = getNearestMob(getgenv().TeleportRange or 50)
    
    if mob then
        noMobCount = 0
        searchCooldown = SEARCH_DELAY_NORMAL
        currentTarget = mob
        floatBehindMob(currentTarget)
    else
        noMobCount = noMobCount + 1
        
        if noMobCount >= MAX_NO_MOB_COUNT then
            searchCooldown = SEARCH_DELAY_IDLE
        else
            searchCooldown = SEARCH_DELAY_LOW
        end
        
        currentTarget = nil
    end
    
    lastSearchTime = currentTime
end

-- FUNGSI: Reset posisi
local function resetPosition()
    if humanoidRootPart then
        local currentPos = humanoidRootPart.Position
        humanoidRootPart.CFrame = CFrame.new(currentPos)
    end
end

-- =============================================
-- MEMBUAT GUI (SETELAH FUNGSI-FUNGSI DIDEKLARASIKAN)
-- =============================================

local function createGUI()
    -- Hapus GUI lama jika ada
    pcall(function()
        for _, gui in pairs(player.PlayerGui:GetChildren()) do
            if gui.Name == "FloatingModeGUI" then
                gui:Destroy()
            end
        end
    end)
    
    -- ScreenGui utama
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "FloatingModeGUI"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = player.PlayerGui
    
    -- Frame utama (background)
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 300, 0, 400)
    mainFrame.Position = UDim2.new(0, 20, 0.5, -200)
    mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    mainFrame.BackgroundTransparency = 0.1
    mainFrame.BorderSizePixel = 0
    mainFrame.Active = true
    mainFrame.Draggable = true
    mainFrame.Parent = screenGui
    
    -- Judul GUI
    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 35)
    titleBar.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    titleBar.BorderSizePixel = 0
    titleBar.Parent = mainFrame
    
    local titleText = Instance.new("TextLabel")
    titleText.Size = UDim2.new(1, -40, 1, 0)
    titleText.Position = UDim2.new(0, 10, 0, 0)
    titleText.BackgroundTransparency = 1
    titleText.Text = "⚡ RPG GRINDER - FLOATING MODE"
    titleText.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleText.TextXAlignment = Enum.TextXAlignment.Left
    titleText.Font = Enum.Font.GothamBold
    titleText.TextSize = 14
    titleText.Parent = titleBar
    
    -- Tombol Close
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 30, 0, 30)
    closeBtn.Position = UDim2.new(1, -35, 0, 2.5)
    closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.TextSize = 18
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.Parent = titleBar
    
    closeBtn.MouseButton1Click:Connect(function()
        screenGui:Destroy()
    end)
    
    -- Konten GUI
    local contentFrame = Instance.new("ScrollingFrame")
    contentFrame.Size = UDim2.new(1, -20, 1, -50)
    contentFrame.Position = UDim2.new(0, 10, 0, 45)
    contentFrame.BackgroundTransparency = 1
    contentFrame.BorderSizePixel = 0
    contentFrame.ScrollBarThickness = 6
    contentFrame.CanvasSize = UDim2.new(0, 0, 0, 350)
    contentFrame.Parent = mainFrame
    
    local yPos = 5
    
    -- SECTION: STATUS
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(1, 0, 0, 25)
    statusLabel.Position = UDim2.new(0, 0, 0, yPos)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = "📊 STATUS"
    statusLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
    statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    statusLabel.Font = Enum.Font.GothamBold
    statusLabel.TextSize = 14
    statusLabel.Parent = contentFrame
    yPos = yPos + 30
    
    -- Status ON/OFF
    local statusFrame = Instance.new("Frame")
    statusFrame.Size = UDim2.new(1, 0, 0, 40)
    statusFrame.Position = UDim2.new(0, 0, 0, yPos)
    statusFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
    statusFrame.BorderSizePixel = 0
    statusFrame.Parent = contentFrame
    
    local statusText = Instance.new("TextLabel")
    statusText.Size = UDim2.new(0.5, -5, 1, 0)
    statusText.Position = UDim2.new(0, 10, 0, 0)
    statusText.BackgroundTransparency = 1
    statusText.Text = "Floating Mode:"
    statusText.TextColor3 = Color3.fromRGB(200, 200, 200)
    statusText.TextXAlignment = Enum.TextXAlignment.Left
    statusText.Font = Enum.Font.Gotham
    statusText.TextSize = 14
    statusText.Parent = statusFrame
    
    local statusValue = Instance.new("TextLabel")
    statusValue.Size = UDim2.new(0.5, -5, 1, 0)
    statusValue.Position = UDim2.new(0.5, 5, 0, 0)
    statusValue.BackgroundTransparency = 1
    statusValue.Text = "OFF"
    statusValue.TextColor3 = Color3.fromRGB(255, 100, 100)
    statusValue.TextXAlignment = Enum.TextXAlignment.Right
    statusValue.Font = Enum.Font.GothamBold
    statusValue.TextSize = 14
    statusValue.Parent = statusFrame
    
    -- Tombol Toggle ON/OFF
    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Size = UDim2.new(1, -20, 0, 35)
    toggleBtn.Position = UDim2.new(0, 10, 0, yPos + 45)
    toggleBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
    toggleBtn.Text = "🔘 AKTIFKAN FLOATING MODE"
    toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggleBtn.Font = Enum.Font.GothamBold
    toggleBtn.TextSize = 14
    toggleBtn.Parent = contentFrame
    yPos = yPos + 90
    
    -- SECTION: TARGET INFO
    local targetLabel = Instance.new("TextLabel")
    targetLabel.Size = UDim2.new(1, 0, 0, 25)
    targetLabel.Position = UDim2.new(0, 0, 0, yPos)
    targetLabel.BackgroundTransparency = 1
    targetLabel.Text = "🎯 TARGET INFO"
    targetLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
    targetLabel.TextXAlignment = Enum.TextXAlignment.Left
    targetLabel.Font = Enum.Font.GothamBold
    targetLabel.TextSize = 14
    targetLabel.Parent = contentFrame
    yPos = yPos + 30
    
    local targetFrame = Instance.new("Frame")
    targetFrame.Size = UDim2.new(1, 0, 0, 60)
    targetFrame.Position = UDim2.new(0, 0, 0, yPos)
    targetFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
    targetFrame.BorderSizePixel = 0
    targetFrame.Parent = contentFrame
    
    local targetNameLabel = Instance.new("TextLabel")
    targetNameLabel.Size = UDim2.new(1, -20, 0, 20)
    targetNameLabel.Position = UDim2.new(0, 10, 0, 5)
    targetNameLabel.BackgroundTransparency = 1
    targetNameLabel.Text = "Target: -"
    targetNameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    targetNameLabel.TextXAlignment = Enum.TextXAlignment.Left
    targetNameLabel.Font = Enum.Font.Gotham
    targetNameLabel.TextSize = 13
    targetNameLabel.Parent = targetFrame
    
    local targetHPLabel = Instance.new("TextLabel")
    targetHPLabel.Size = UDim2.new(1, -20, 0, 20)
    targetHPLabel.Position = UDim2.new(0, 10, 0, 25)
    targetHPLabel.BackgroundTransparency = 1
    targetHPLabel.Text = "HP: -"
    targetHPLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
    targetHPLabel.TextXAlignment = Enum.TextXAlignment.Left
    targetHPLabel.Font = Enum.Font.Gotham
    targetHPLabel.TextSize = 13
    targetHPLabel.Parent = targetFrame
    
    local targetDistLabel = Instance.new("TextLabel")
    targetDistLabel.Size = UDim2.new(1, -20, 0, 20)
    targetDistLabel.Position = UDim2.new(0, 10, 0, 45)
    targetDistLabel.BackgroundTransparency = 1
    targetDistLabel.Text = "Jarak: -"
    targetDistLabel.TextColor3 = Color3.fromRGB(150, 150, 255)
    targetDistLabel.TextXAlignment = Enum.TextXAlignment.Left
    targetDistLabel.Font = Enum.Font.Gotham
    targetDistLabel.TextSize = 13
    targetDistLabel.Parent = targetFrame
    yPos = yPos + 70
    
    -- Tombol Cari Target Manual
    local searchBtn = Instance.new("TextButton")
    searchBtn.Size = UDim2.new(0.5, -15, 0, 35)
    searchBtn.Position = UDim2.new(0, 0, 0, yPos)
    searchBtn.BackgroundColor3 = Color3.fromRGB(50, 100, 200)
    searchBtn.Text = "🔍 CARI TARGET"
    searchBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    searchBtn.Font = Enum.Font.GothamBold
    searchBtn.TextSize = 12
    searchBtn.Parent = contentFrame
    
    -- Tombol Reset/Turun
    local resetBtn = Instance.new("TextButton")
    resetBtn.Size = UDim2.new(0.5, -15, 0, 35)
    resetBtn.Position = UDim2.new(0.5, 5, 0, yPos)
    resetBtn.BackgroundColor3 = Color3.fromRGB(200, 100, 50)
    resetBtn.Text = "⬇️ TURUN"
    resetBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    resetBtn.Font = Enum.Font.GothamBold
    resetBtn.TextSize = 12
    resetBtn.Parent = contentFrame
    yPos = yPos + 45
    
    -- SECTION: PENGATURAN
    local settingLabel = Instance.new("TextLabel")
    settingLabel.Size = UDim2.new(1, 0, 0, 25)
    settingLabel.Position = UDim2.new(0, 0, 0, yPos)
    settingLabel.BackgroundTransparency = 1
    settingLabel.Text = "⚙️ PENGATURAN"
    settingLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
    settingLabel.TextXAlignment = Enum.TextXAlignment.Left
    settingLabel.Font = Enum.Font.GothamBold
    settingLabel.TextSize = 14
    settingLabel.Parent = contentFrame
    yPos = yPos + 30
    
    -- Slider Jarak
    local distanceFrame = Instance.new("Frame")
    distanceFrame.Size = UDim2.new(1, 0, 0, 50)
    distanceFrame.Position = UDim2.new(0, 0, 0, yPos)
    distanceFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
    distanceFrame.BorderSizePixel = 0
    distanceFrame.Parent = contentFrame
    
    local distanceText = Instance.new("TextLabel")
    distanceText.Size = UDim2.new(0.4, -5, 0, 25)
    distanceText.Position = UDim2.new(0, 10, 0, 5)
    distanceText.BackgroundTransparency = 1
    distanceText.Text = "Jarak Belakang:"
    distanceText.TextColor3 = Color3.fromRGB(200, 200, 200)
    distanceText.TextXAlignment = Enum.TextXAlignment.Left
    distanceText.Font = Enum.Font.Gotham
    distanceText.TextSize = 13
    distanceText.Parent = distanceFrame
    
    local distanceValue = Instance.new("TextLabel")
    distanceValue.Size = UDim2.new(0.2, 0, 0, 25)
    distanceValue.Position = UDim2.new(0.8, -20, 0, 5)
    distanceValue.BackgroundTransparency = 1
    distanceValue.Text = floatDistance .. "m"
    distanceValue.TextColor3 = Color3.fromRGB(255, 255, 255)
    distanceValue.TextXAlignment = Enum.TextXAlignment.Right
    distanceValue.Font = Enum.Font.GothamBold
    distanceValue.TextSize = 14
    distanceValue.Parent = distanceFrame
    
    local sliderBg = Instance.new("Frame")
    sliderBg.Size = UDim2.new(0.6, -10, 0, 10)
    sliderBg.Position = UDim2.new(0.4, 5, 0, 35)
    sliderBg.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
    sliderBg.BorderSizePixel = 0
    sliderBg.Parent = distanceFrame
    
    local sliderFill = Instance.new("Frame")
    sliderFill.Size = UDim2.new((floatDistance - 2) / 13, 0, 1, 0)
    sliderFill.BackgroundColor3 = Color3.fromRGB(100, 200, 255)
    sliderFill.BorderSizePixel = 0
    sliderFill.Parent = sliderBg
    
    local sliderButton = Instance.new("TextButton")
    sliderButton.Size = UDim2.new(0, 20, 0, 20)
    sliderButton.Position = UDim2.new((floatDistance - 2) / 13, -10, 0.5, -10)
    sliderButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    sliderButton.Text = ""
    sliderButton.BorderSizePixel = 0
    sliderButton.Parent = sliderBg
    yPos = yPos + 60
    
    -- SECTION: ANTI-LAG INFO
    local antiLagLabel = Instance.new("TextLabel")
    antiLagLabel.Size = UDim2.new(1, 0, 0, 25)
    antiLagLabel.Position = UDim2.new(0, 0, 0, yPos)
    antiLagLabel.BackgroundTransparency = 1
    antiLagLabel.Text = "⚡ ANTI-LAG STATUS"
    antiLagLabel.TextColor3 = Color3.fromRGB(150, 255, 150)
    antiLagLabel.TextXAlignment = Enum.TextXAlignment.Left
    antiLagLabel.Font = Enum.Font.GothamBold
    antiLagLabel.TextSize = 14
    antiLagLabel.Parent = contentFrame
    yPos = yPos + 30
    
    local antiLagFrame = Instance.new("Frame")
    antiLagFrame.Size = UDim2.new(1, 0, 0, 50)
    antiLagFrame.Position = UDim2.new(0, 0, 0, yPos)
    antiLagFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
    antiLagFrame.BorderSizePixel = 0
    antiLagFrame.Parent = contentFrame
    
    local noMobText = Instance.new("TextLabel")
    noMobText.Size = UDim2.new(1, -20, 0, 20)
    noMobText.Position = UDim2.new(0, 10, 0, 5)
    noMobText.BackgroundTransparency = 1
    noMobText.Text = "Pencarian Gagal: 0x"
    noMobText.TextColor3 = Color3.fromRGB(200, 200, 200)
    noMobText.TextXAlignment = Enum.TextXAlignment.Left
    noMobText.Font = Enum.Font.Gotham
    noMobText.TextSize = 13
    noMobText.Parent = antiLagFrame
    
    local cooldownText = Instance.new("TextLabel")
    cooldownText.Size = UDim2.new(1, -20, 0, 20)
    cooldownText.Position = UDim2.new(0, 10, 0, 25)
    cooldownText.BackgroundTransparency = 1
    cooldownText.Text = "Cooldown: 0.5 detik"
    cooldownText.TextColor3 = Color3.fromRGB(200, 200, 200)
    cooldownText.TextXAlignment = Enum.TextXAlignment.Left
    cooldownText.Font = Enum.Font.Gotham
    cooldownText.TextSize = 13
    cooldownText.Parent = antiLagFrame
    
    yPos = yPos + 60
    contentFrame.CanvasSize = UDim2.new(0, 0, 0, yPos + 10)
    
    -- =========================================
    -- FUNGSI UPDATE GUI (didefinisikan di sini)
    -- =========================================
    local function updateGUI()
        -- Update status
        if floatingActive then
            statusValue.Text = "ON"
            statusValue.TextColor3 = Color3.fromRGB(100, 255, 100)
            toggleBtn.Text = "🔴 MATIKAN FLOATING MODE"
            toggleBtn.BackgroundColor3 = Color3.fromRGB(200, 80, 80)
        else
            statusValue.Text = "OFF"
            statusValue.TextColor3 = Color3.fromRGB(255, 100, 100)
            toggleBtn.Text = "🟢 AKTIFKAN FLOATING MODE"
            toggleBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
        end
        
        -- Update target info (dengan pcall untuk safety)
        pcall(function()
            if floatingActive and currentTarget and isMobAlive(currentTarget) and humanoidRootPart then
                targetNameLabel.Text = "Target: " .. tostring(currentTarget.model.Name)
                targetHPLabel.Text = "HP: " .. math.floor(currentTarget.humanoid.Health)
                local dist = (humanoidRootPart.Position - currentTarget.rootPart.Position).Magnitude
                targetDistLabel.Text = "Jarak: " .. math.floor(dist) .. " studs"
            else
                targetNameLabel.Text = "Target: -"
                targetHPLabel.Text = "HP: -"
                targetDistLabel.Text = "Jarak: -"
            end
        end)
        
        -- Update jarak
        distanceValue.Text = floatDistance .. "m"
        local fillPercent = (floatDistance - 2) / 13
        sliderFill.Size = UDim2.new(fillPercent, 0, 1, 0)
        sliderButton.Position = UDim2.new(fillPercent, -10, 0.5, -10)
        
        -- Update anti-lag info
        noMobText.Text = "Pencarian Gagal: " .. noMobCount .. "x"
        cooldownText.Text = "Cooldown: " .. string.format("%.1f", searchCooldown) .. " detik"
    end
    
    -- =========================================
    -- EVENT HANDLER UNTUK GUI
    -- =========================================
    
    -- Tombol Toggle
    toggleBtn.MouseButton1Click:Connect(function()
        pcall(function()
            if not character or not humanoidRootPart then
                waitForCharacter()
            end
            
            floatingActive = not floatingActive
            
            if floatingActive then
                print("🚀 FLOATING MODE: AKTIF (via GUI)")
                noMobCount = 0
                searchCooldown = SEARCH_DELAY_NORMAL
                lastSearchTime = 0
                findNewTarget()
            else
                print("💤 FLOATING MODE: DIMATIKAN (via GUI)")
                resetPosition()
                currentTarget = nil
            end
            
            updateGUI()
        end)
    end)
    
    -- Tombol Cari Target
    searchBtn.MouseButton1Click:Connect(function()
        pcall(function()
            if not floatingActive then
                print("⚠️ Aktifkan floating mode dulu")
                return
            end
            
            print("🔍 Mencari target manual...")
            lastSearchTime = 0
            noMobCount = 0
            findNewTarget()
            updateGUI()
        end)
    end)
    
    -- Tombol Reset/Turun
    resetBtn.MouseButton1Click:Connect(function()
        pcall(function()
            if floatingActive then
                floatingActive = false
                resetPosition()
                currentTarget = nil
                print("⬇️ Turun ke tanah (via GUI)")
                updateGUI()
            end
        end)
    end)
    
    -- Slider drag functionality
    local dragging = false
    
    sliderButton.MouseButton1Down:Connect(function()
        dragging = true
    end)
    
    userInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    
    userInputService.InputChanged:Connect(function(input)
        pcall(function()
            if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                local mousePos = userInputService:GetMouseLocation()
                local sliderPos = sliderBg.AbsolutePosition
                local sliderSize = sliderBg.AbsoluteSize.X
                
                if sliderSize > 0 then
                    local relativeX = math.clamp(mousePos.X - sliderPos.X, 0, sliderSize)
                    local percent = relativeX / sliderSize
                    
                    floatDistance = math.floor(2 + (percent * 13))
                    floatDistance = math.clamp(floatDistance, 2, 15)
                    
                    if floatingActive and currentTarget then
                        floatBehindMob(currentTarget)
                    end
                    
                    updateGUI()
                end
            end
        end)
    end)
    
    return updateGUI
end

-- =============================================
-- DETEKSI RESPAWN KARAKTER
-- =============================================
player.CharacterAdded:Connect(function(newCharacter)
    pcall(function()
        print("🔄 Karakter respawn terdeteksi!")
        character = newCharacter
        humanoidRootPart = character:WaitForChild("HumanoidRootPart")
        
        noMobCount = 0
        searchCooldown = SEARCH_DELAY_NORMAL
        
        if floatingActive then
            print("🚀 Floating mode masih aktif, mencari target...")
            wait(1)
            findNewTarget()
        end
        
        if updateGUIFunc then
            updateGUIFunc()
        end
    end)
end)

-- KEYBIND SYSTEM (OPSIONAL)
userInputService.InputBegan:Connect(function(input, gameProcessed)
    pcall(function()
        if gameProcessed then return end
        
        if input.KeyCode == Enum.KeyCode.F and not floatingActive then
            if not character or not humanoidRootPart then
                waitForCharacter()
            end
            
            floatingActive = true
            print("🚀 FLOATING MODE: AKTIF (via keyboard)")
            noMobCount = 0
            searchCooldown = SEARCH_DELAY_NORMAL
            lastSearchTime = 0
            findNewTarget()
            
            if updateGUIFunc then
                updateGUIFunc()
            end
        end
    end)
end)

-- LOOP UTAMA
runService.Heartbeat:Connect(function()
    pcall(function()
        if not character or not humanoidRootPart then
            if player.Character then
                updateCharacter()
            end
            return
        end
        
        if not floatingActive then return end
        
        if not currentTarget then
            findNewTarget()
            return
        end
        
        if not isMobAlive(currentTarget) then
            currentTarget = nil
            noMobCount = 0
            searchCooldown = SEARCH_DELAY_NORMAL
            return
        end
        
        floatBehindMob(currentTarget)
        
        if updateGUIFunc then
            updateGUIFunc()
        end
        
        wait(0.1)
    end)
end)

-- Inisialisasi awal
updateCharacter()

-- Buat GUI (SETELAH semua fungsi didefinisikan)
updateGUIFunc = createGUI()

print("=================================")
print("✅ RPG Grinder - FLOATING MODE")
print("    + GUI LENGKAP (FIX ERROR)")
print("=================================")
print("🎯 Semua fitur bisa diakses via GUI")
print("🖱️ Klik dan drag untuk atur jarak")
print("📊 Status real-time ditampilkan")
print("=================================")
