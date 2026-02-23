-- Script Utama RPG Grinder - FLOATING MODE + AUTO ATTACK
-- Dengan radius auto attack yang bisa diatur

local player = game.Players.LocalPlayer
local userInputService = game:GetService("UserInputService")
local runService = game:GetService("RunService")
local players = game:GetService("Players")
local tweenService = game:GetService("TweenService")
local replicatedStorage = game:GetService("ReplicatedStorage")

-- VARIABEL GLOBAL
local floatingActive = false
local autoAttackActive = false  -- Fitur auto attack
local currentTarget = nil
local floatDistance = 5
local searchRadius = 50  -- Radius pencarian mob
local attackRadius = 15   -- Radius serangan (default 15, bisa diatur)
local targetMobFilters = {}
local character = nil
local humanoidRootPart = nil

-- VARIABEL UNTUK AUTO ATTACK
local attackCooldown = 0
local lastAttackTime = 0
local attackSpeed = 0.3  -- Kecepatan serangan (detik)

-- VARIABEL ANTI-LAG
local searchCooldown = 0
local noMobCount = 0
local lastSearchTime = 0
local SEARCH_DELAY_NORMAL = 0.5
local SEARCH_DELAY_LOW = 2
local SEARCH_DELAY_IDLE = 5
local MAX_NO_MOB_COUNT = 5

-- VARIABEL GUI
local updateGUIFunc = nil

-- =============================================
-- FUNGSI-FUNGSI UTAMA
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

-- FUNGSI: Parse string filter menjadi table
local function parseFilters(filterString)
    local filters = {}
    if filterString == "" then return filters end
    
    for word in string.gmatch(filterString, "([^,]+)") do
        local trimmed = word:match("^%s*(.-)%s*$")
        if trimmed and trimmed ~= "" then
            table.insert(filters, string.lower(trimmed))
        end
    end
    return filters
end

-- FUNGSI: Cek apakah mob sesuai filter
local function isMobNameMatch(mobName)
    if #targetMobFilters == 0 then return true end
    
    local lowerName = string.lower(mobName)
    for _, filter in ipairs(targetMobFilters) do
        if string.find(lowerName, filter) then
            return true
        end
    end
    return false
end

-- FUNGSI: Mendapatkan mob terdekat
local function getNearestMob()
    if not humanoidRootPart then return nil end
    
    local nearestMob = nil
    local shortestDistance = math.huge
    local playerPos = humanoidRootPart.Position
    
    local region = Region3.new(
        playerPos - Vector3.new(searchRadius, searchRadius, searchRadius),
        playerPos + Vector3.new(searchRadius, searchRadius, searchRadius)
    )
    
    local parts = {}
    pcall(function()
        parts = workspace:FindPartsInRegion3(region, nil, 100)
    end)
    
    for _, part in ipairs(parts) do
        local obj = part.Parent
        if obj and obj:IsA("Model") and obj:FindFirstChild("Humanoid") and not players:GetPlayerFromCharacter(obj) then
            
            if not isMobNameMatch(obj.Name) then
                continue
            end
            
            local mobRoot = obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChild("Torso")
            if mobRoot then
                local humanoid = obj:FindFirstChild("Humanoid")
                if humanoid and humanoid.Health > 0 then
                    local distance = (playerPos - mobRoot.Position).Magnitude
                    if distance < shortestDistance then
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

-- FUNGSI: Mendapatkan semua mob dalam radius (untuk auto attack)
local function getMobsInRange(range)
    if not humanoidRootPart then return {} end
    
    local mobsInRange = {}
    local playerPos = humanoidRootPart.Position
    
    local region = Region3.new(
        playerPos - Vector3.new(range, range, range),
        playerPos + Vector3.new(range, range, range)
    )
    
    local parts = {}
    pcall(function()
        parts = workspace:FindPartsInRegion3(region, nil, 100)
    end)
    
    for _, part in ipairs(parts) do
        local obj = part.Parent
        if obj and obj:IsA("Model") and obj:FindFirstChild("Humanoid") and not players:GetPlayerFromCharacter(obj) then
            
            if not isMobNameMatch(obj.Name) then
                continue
            end
            
            local mobRoot = obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChild("Torso")
            if mobRoot then
                local humanoid = obj:FindFirstChild("Humanoid")
                if humanoid and humanoid.Health > 0 then
                    local distance = (playerPos - mobRoot.Position).Magnitude
                    if distance <= range then
                        table.insert(mobsInRange, {
                            model = obj,
                            rootPart = mobRoot,
                            humanoid = humanoid
                        })
                    end
                end
            end
        end
    end
    
    return mobsInRange
end

-- FUNGSI: Teleport ke BELAKANG mob
local function floatBehindMob(mob)
    if not mob or not mob.rootPart or not humanoidRootPart then return end
    
    pcall(function()
        local mobPosition = mob.rootPart.Position
        local mobDirection = mob.rootPart.CFrame.LookVector
        local behindPosition = mobPosition - (mobDirection * floatDistance)
        behindPosition = behindPosition + Vector3.new(0, 2, 0)
        local lookAtMob = CFrame.lookAt(behindPosition, mobPosition)
        humanoidRootPart.CFrame = lookAtMob
    end)
end

-- FUNGSI: Auto Attack - Menyerang mob dalam radius
local function autoAttack()
    if not autoAttackActive or not floatingActive then return end
    if not humanoidRootPart then return end
    
    local currentTime = tick()
    if currentTime - lastAttackTime < attackCooldown then
        return  -- Masih cooldown
    end
    
    -- Dapatkan semua mob dalam radius serangan
    local mobs = getMobsInRange(attackRadius)
    
    for _, mob in ipairs(mobs) do
        if mob and mob.humanoid and mob.humanoid.Health > 0 then
            -- METODE 1: Langsung kurangi health
            mob.humanoid.Health = mob.humanoid.Health - 25  -- Damage 25
            
            -- METODE 2: Gunakan :TakeDamage() jika tersedia
            -- pcall(function()
            --     mob.humanoid:TakeDamage(30)
            -- end)
            
            -- METODE 3: Cari remote event untuk attack (untuk game tertentu)
            -- pcall(function()
            --     for _, remote in ipairs(replicatedStorage:GetChildren()) do
            --         if remote:IsA("RemoteEvent") and remote.Name:lower():find("attack") then
            --             remote:FireServer(mob.model)
            --             break
            --         end
            --     end
            -- end)
            
            print("⚔️ Auto Attack:", mob.model.Name, "HP:", math.floor(mob.humanoid.Health))
        end
    end
    
    lastAttackTime = currentTime
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

-- FUNGSI: Cari target baru
local function findNewTarget()
    if not humanoidRootPart then return end
    
    local currentTime = tick()
    if currentTime - lastSearchTime < searchCooldown then
        return
    end
    
    local mob = getNearestMob()
    
    if mob then
        noMobCount = 0
        searchCooldown = SEARCH_DELAY_NORMAL
        currentTarget = mob
        floatBehindMob(currentTarget)
        
        local filterInfo = ""
        if #targetMobFilters > 0 then
            filterInfo = " (filter: " .. table.concat(targetMobFilters, ", ") .. ")"
        else
            filterInfo = " (semua mob)"
        end
        print("✅ Target baru:", currentTarget.model.Name, "| HP:", math.floor(currentTarget.humanoid.Health), filterInfo)
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
-- MEMBUAT GUI LENGKAP DENGAN AUTO ATTACK
-- =============================================

local function createGUI()
    -- Hapus GUI lama
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
    
    -- Frame utama
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 400, 0, 700)  -- Lebih besar untuk fitur baru
    mainFrame.Position = UDim2.new(0, 20, 0.5, -350)
    mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    mainFrame.BackgroundTransparency = 0.1
    mainFrame.BorderSizePixel = 0
    mainFrame.Active = true
    mainFrame.Draggable = true
    mainFrame.Parent = screenGui
    
    -- Judul
    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 35)
    titleBar.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    titleBar.BorderSizePixel = 0
    titleBar.Parent = mainFrame
    
    local titleText = Instance.new("TextLabel")
    titleText.Size = UDim2.new(1, -40, 1, 0)
    titleText.Position = UDim2.new(0, 10, 0, 0)
    titleText.BackgroundTransparency = 1
    titleText.Text = "⚡ RPG GRINDER - AUTO ATTACK"
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
    
    -- Konten GUI (scrollable)
    local contentFrame = Instance.new("ScrollingFrame")
    contentFrame.Size = UDim2.new(1, -20, 1, -50)
    contentFrame.Position = UDim2.new(0, 10, 0, 45)
    contentFrame.BackgroundTransparency = 1
    contentFrame.BorderSizePixel = 0
    contentFrame.ScrollBarThickness = 6
    contentFrame.CanvasSize = UDim2.new(0, 0, 0, 900)
    contentFrame.Parent = mainFrame
    
    local yPos = 5
    
    -- =========================================
    -- SECTION: STATUS
    -- =========================================
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
    
    -- Status Floating Mode
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
    yPos = yPos + 45
    
    -- Status Auto Attack
    local autoAttackFrame = Instance.new("Frame")
    autoAttackFrame.Size = UDim2.new(1, 0, 0, 40)
    autoAttackFrame.Position = UDim2.new(0, 0, 0, yPos)
    autoAttackFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
    autoAttackFrame.BorderSizePixel = 0
    autoAttackFrame.Parent = contentFrame
    
    local autoAttackText = Instance.new("TextLabel")
    autoAttackText.Size = UDim2.new(0.5, -5, 1, 0)
    autoAttackText.Position = UDim2.new(0, 10, 0, 0)
    autoAttackText.BackgroundTransparency = 1
    autoAttackText.Text = "Auto Attack:"
    autoAttackText.TextColor3 = Color3.fromRGB(200, 200, 200)
    autoAttackText.TextXAlignment = Enum.TextXAlignment.Left
    autoAttackText.Font = Enum.Font.Gotham
    autoAttackText.TextSize = 14
    autoAttackText.Parent = autoAttackFrame
    
    local autoAttackValue = Instance.new("TextLabel")
    autoAttackValue.Size = UDim2.new(0.5, -5, 1, 0)
    autoAttackValue.Position = UDim2.new(0.5, 5, 0, 0)
    autoAttackValue.BackgroundTransparency = 1
    autoAttackValue.Text = "OFF"
    autoAttackValue.TextColor3 = Color3.fromRGB(255, 100, 100)
    autoAttackValue.TextXAlignment = Enum.TextXAlignment.Right
    autoAttackValue.Font = Enum.Font.GothamBold
    autoAttackValue.TextSize = 14
    autoAttackValue.Parent = autoAttackFrame
    yPos = yPos + 45
    
    -- Tombol Toggle Floating
    local toggleFloatBtn = Instance.new("TextButton")
    toggleFloatBtn.Size = UDim2.new(1, -20, 0, 35)
    toggleFloatBtn.Position = UDim2.new(0, 10, 0, yPos)
    toggleFloatBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
    toggleFloatBtn.Text = "🔘 AKTIFKAN FLOATING MODE"
    toggleFloatBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggleFloatBtn.Font = Enum.Font.GothamBold
    toggleFloatBtn.TextSize = 14
    toggleFloatBtn.Parent = contentFrame
    yPos = yPos + 40
    
    -- Tombol Toggle Auto Attack
    local toggleAttackBtn = Instance.new("TextButton")
    toggleAttackBtn.Size = UDim2.new(1, -20, 0, 35)
    toggleAttackBtn.Position = UDim2.new(0, 10, 0, yPos)
    toggleAttackBtn.BackgroundColor3 = Color3.fromRGB(200, 100, 100)
    toggleAttackBtn.Text = "⚔️ AKTIFKAN AUTO ATTACK"
    toggleAttackBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggleAttackBtn.Font = Enum.Font.GothamBold
    toggleAttackBtn.TextSize = 14
    toggleAttackBtn.Parent = contentFrame
    yPos = yPos + 45
    
    -- =========================================
    -- SECTION: MULTI-FILTER
    -- =========================================
    local filterLabel = Instance.new("TextLabel")
    filterLabel.Size = UDim2.new(1, 0, 0, 25)
    filterLabel.Position = UDim2.new(0, 0, 0, yPos)
    filterLabel.BackgroundTransparency = 1
    filterLabel.Text = "🎯 MULTI-FILTER (Pisahkan dengan koma)"
    filterLabel.TextColor3 = Color3.fromRGB(255, 150, 100)
    filterLabel.TextXAlignment = Enum.TextXAlignment.Left
    filterLabel.Font = Enum.Font.GothamBold
    filterLabel.TextSize = 14
    filterLabel.Parent = contentFrame
    yPos = yPos + 30
    
    local filterFrame = Instance.new("Frame")
    filterFrame.Size = UDim2.new(1, 0, 0, 100)
    filterFrame.Position = UDim2.new(0, 0, 0, yPos)
    filterFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
    filterFrame.BorderSizePixel = 0
    filterFrame.Parent = contentFrame
    
    local filterDesc = Instance.new("TextLabel")
    filterDesc.Size = UDim2.new(1, -20, 0, 20)
    filterDesc.Position = UDim2.new(0, 10, 0, 5)
    filterDesc.BackgroundTransparency = 1
    filterDesc.Text = "Nama mob (pisahkan dengan koma):"
    filterDesc.TextColor3 = Color3.fromRGB(200, 200, 200)
    filterDesc.TextXAlignment = Enum.TextXAlignment.Left
    filterDesc.Font = Enum.Font.Gotham
    filterDesc.TextSize = 12
    filterDesc.Parent = filterFrame
    
    local nameInput = Instance.new("TextBox")
    nameInput.Size = UDim2.new(1, -30, 0, 30)
    nameInput.Position = UDim2.new(0, 15, 0, 30)
    nameInput.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
    nameInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameInput.PlaceholderText = "Contoh: Slime, Goblin, Boss, Dragon"
    nameInput.PlaceholderColor3 = Color3.fromRGB(150, 150, 150)
    nameInput.Text = ""
    nameInput.Font = Enum.Font.Gotham
    nameInput.TextSize = 14
    nameInput.ClearTextOnFocus = false
    nameInput.Parent = filterFrame
    
    local applyFilterBtn = Instance.new("TextButton")
    applyFilterBtn.Size = UDim2.new(0.5, -15, 0, 25)
    applyFilterBtn.Position = UDim2.new(0, 15, 0, 65)
    applyFilterBtn.BackgroundColor3 = Color3.fromRGB(100, 150, 255)
    applyFilterBtn.Text = "TERAPKAN FILTER"
    applyFilterBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    applyFilterBtn.Font = Enum.Font.GothamBold
    applyFilterBtn.TextSize = 12
    applyFilterBtn.Parent = filterFrame
    
    local resetFilterBtn = Instance.new("TextButton")
    resetFilterBtn.Size = UDim2.new(0.5, -15, 0, 25)
    resetFilterBtn.Position = UDim2.new(0.5, 5, 0, 65)
    resetFilterBtn.BackgroundColor3 = Color3.fromRGB(150, 150, 150)
    resetFilterBtn.Text = "RESET FILTER"
    resetFilterBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    resetFilterBtn.Font = Enum.Font.GothamBold
    resetFilterBtn.TextSize = 12
    resetFilterBtn.Parent = filterFrame
    yPos = yPos + 110
    
    -- =========================================
    -- SECTION: TARGET INFO
    -- =========================================
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
    targetFrame.Size = UDim2.new(1, 0, 0, 100)
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
    targetNameLabel.Font = Enum.Font.GothamBold
    targetNameLabel.TextSize = 14
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
    
    local activeFilterLabel = Instance.new("TextLabel")
    activeFilterLabel.Size = UDim2.new(1, -20, 0, 30)
    activeFilterLabel.Position = UDim2.new(0, 10, 0, 70)
    activeFilterLabel.BackgroundTransparency = 1
    activeFilterLabel.Text = "Filter aktif: Semua mob"
    activeFilterLabel.TextColor3 = Color3.fromRGB(200, 200, 100)
    activeFilterLabel.TextXAlignment = Enum.TextXAlignment.Left
    activeFilterLabel.TextWrapped = true
    activeFilterLabel.Font = Enum.Font.Gotham
    activeFilterLabel.TextSize = 12
    activeFilterLabel.Parent = targetFrame
    yPos = yPos + 110
    
    -- Tombol Aksi
    local searchBtn = Instance.new("TextButton")
    searchBtn.Size = UDim2.new(0.5, -15, 0, 35)
    searchBtn.Position = UDim2.new(0, 0, 0, yPos)
    searchBtn.BackgroundColor3 = Color3.fromRGB(50, 100, 200)
    searchBtn.Text = "🔍 CARI TARGET"
    searchBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    searchBtn.Font = Enum.Font.GothamBold
    searchBtn.TextSize = 12
    searchBtn.Parent = contentFrame
    
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
    
    -- =========================================
    -- SECTION: PENGATURAN RADIUS
    -- =========================================
    local radiusLabel = Instance.new("TextLabel")
    radiusLabel.Size = UDim2.new(1, 0, 0, 25)
    radiusLabel.Position = UDim2.new(0, 0, 0, yPos)
    radiusLabel.BackgroundTransparency = 1
    radiusLabel.Text = "📡 PENGATURAN RADIUS"
    radiusLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
    radiusLabel.TextXAlignment = Enum.TextXAlignment.Left
    radiusLabel.Font = Enum.Font.GothamBold
    radiusLabel.TextSize = 14
    radiusLabel.Parent = contentFrame
    yPos = yPos + 30
    
    -- Slider Radius Pencarian Mob (20-150)
    local searchRadiusFrame = Instance.new("Frame")
    searchRadiusFrame.Size = UDim2.new(1, 0, 0, 50)
    searchRadiusFrame.Position = UDim2.new(0, 0, 0, yPos)
    searchRadiusFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
    searchRadiusFrame.BorderSizePixel = 0
    searchRadiusFrame.Parent = contentFrame
    
    local searchRadiusText = Instance.new("TextLabel")
    searchRadiusText.Size = UDim2.new(0.5, -5, 0, 25)
    searchRadiusText.Position = UDim2.new(0, 10, 0, 5)
    searchRadiusText.BackgroundTransparency = 1
    searchRadiusText.Text = "Radius Pencarian:"
    searchRadiusText.TextColor3 = Color3.fromRGB(200, 200, 200)
    searchRadiusText.TextXAlignment = Enum.TextXAlignment.Left
    searchRadiusText.Font = Enum.Font.Gotham
    searchRadiusText.TextSize = 13
    searchRadiusText.Parent = searchRadiusFrame
    
    local searchRadiusValue = Instance.new("TextLabel")
    searchRadiusValue.Size = UDim2.new(0.2, 0, 0, 25)
    searchRadiusValue.Position = UDim2.new(0.8, -20, 0, 5)
    searchRadiusValue.BackgroundTransparency = 1
    searchRadiusValue.Text = searchRadius .. "m"
    searchRadiusValue.TextColor3 = Color3.fromRGB(255, 255, 255)
    searchRadiusValue.TextXAlignment = Enum.TextXAlignment.Right
    searchRadiusValue.Font = Enum.Font.GothamBold
    searchRadiusValue.TextSize = 14
    searchRadiusValue.Parent = searchRadiusFrame
    
    local searchSliderBg = Instance.new("Frame")
    searchSliderBg.Size = UDim2.new(0.6, -10, 0, 10)
    searchSliderBg.Position = UDim2.new(0.4, 5, 0, 35)
    searchSliderBg.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
    searchSliderBg.BorderSizePixel = 0
    searchSliderBg.Parent = searchRadiusFrame
    
    local searchSliderFill = Instance.new("Frame")
    searchSliderFill.Size = UDim2.new((searchRadius - 20) / 130, 0, 1, 0)  -- Range 20-150
    searchSliderFill.BackgroundColor3 = Color3.fromRGB(100, 200, 255)
    searchSliderFill.BorderSizePixel = 0
    searchSliderFill.Parent = searchSliderBg
    
    local searchSliderButton = Instance.new("TextButton")
    searchSliderButton.Size = UDim2.new(0, 20, 0, 20)
    searchSliderButton.Position = UDim2.new((searchRadius - 20) / 130, -10, 0.5, -10)
    searchSliderButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    searchSliderButton.Text = ""
    searchSliderButton.BorderSizePixel = 0
    searchSliderButton.Parent = searchSliderBg
    yPos = yPos + 60
    
    -- Slider Radius Auto Attack (5-50)
    local attackRadiusFrame = Instance.new("Frame")
    attackRadiusFrame.Size = UDim2.new(1, 0, 0, 50)
    attackRadiusFrame.Position = UDim2.new(0, 0, 0, yPos)
    attackRadiusFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
    attackRadiusFrame.BorderSizePixel = 0
    attackRadiusFrame.Parent = contentFrame
    
    local attackRadiusText = Instance.new("TextLabel")
    attackRadiusText.Size = UDim2.new(0.5, -5, 0, 25)
    attackRadiusText.Position = UDim2.new(0, 10, 0, 5)
    attackRadiusText.BackgroundTransparency = 1
    attackRadiusText.Text = "Radius Auto Attack:"
    attackRadiusText.TextColor3 = Color3.fromRGB(200, 200, 200)
    attackRadiusText.TextXAlignment = Enum.TextXAlignment.Left
    attackRadiusText.Font = Enum.Font.Gotham
    attackRadiusText.TextSize = 13
    attackRadiusText.Parent = attackRadiusFrame
    
    local attackRadiusValue = Instance.new("TextLabel")
    attackRadiusValue.Size = UDim2.new(0.2, 0, 0, 25)
    attackRadiusValue.Position = UDim2.new(0.8, -20, 0, 5)
    attackRadiusValue.BackgroundTransparency = 1
    attackRadiusValue.Text = attackRadius .. "m"
    attackRadiusValue.TextColor3 = Color3.fromRGB(255, 255, 255)
    attackRadiusValue.TextXAlignment = Enum.TextXAlignment.Right
    attackRadiusValue.Font = Enum.Font.GothamBold
    attackRadiusValue.TextSize = 14
    attackRadiusValue.Parent = attackRadiusFrame
    
    local attackSliderBg = Instance.new("Frame")
    attackSliderBg.Size = UDim2.new(0.6, -10, 0, 10)
    attackSliderBg.Position = UDim2.new(0.4, 5, 0, 35)
    attackSliderBg.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
    attackSliderBg.BorderSizePixel = 0
    attackSliderBg.Parent = attackRadiusFrame
    
    local attackSliderFill = Instance.new("Frame")
    attackSliderFill.Size = UDim2.new((attackRadius - 5) / 45, 0, 1, 0)  -- Range 5-50
    attackSliderFill.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
    attackSliderFill.BorderSizePixel = 0
    attackSliderFill.Parent = attackSliderBg
    
    local attackSliderButton = Instance.new("TextButton")
    attackSliderButton.Size = UDim2.new(0, 20, 0, 20)
    attackSliderButton.Position = UDim2.new((attackRadius - 5) / 45, -10, 0.5, -10)
    attackSliderButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    attackSliderButton.Text = ""
    attackSliderButton.BorderSizePixel = 0
    attackSliderButton.Parent = attackSliderBg
    yPos = yPos + 60
    
    -- Slider Jarak Belakang (2-15)
    local distanceFrame = Instance.new("Frame")
    distanceFrame.Size = UDim2.new(1, 0, 0, 50)
    distanceFrame.Position = UDim2.new(0, 0, 0, yPos)
    distanceFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
    distanceFrame.BorderSizePixel = 0
    distanceFrame.Parent = contentFrame
    
    local distanceText = Instance.new("TextLabel")
    distanceText.Size = UDim2.new(0.5, -5, 0, 25)
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
    
    local distanceSliderBg = Instance.new("Frame")
    distanceSliderBg.Size = UDim2.new(0.6, -10, 0, 10)
    distanceSliderBg.Position = UDim2.new(0.4, 5, 0, 35)
    distanceSliderBg.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
    distanceSliderBg.BorderSizePixel = 0
    distanceSliderBg.Parent = distanceFrame
    
    local distanceSliderFill = Instance.new("Frame")
    distanceSliderFill.Size = UDim2.new((floatDistance - 2) / 13, 0, 1, 0)
    distanceSliderFill.BackgroundColor3 = Color3.fromRGB(100, 200, 255)
    distanceSliderFill.BorderSizePixel = 0
    distanceSliderFill.Parent = distanceSliderBg
    
    local distanceSliderButton = Instance.new("TextButton")
    distanceSliderButton.Size = UDim2.new(0, 20, 0, 20)
    distanceSliderButton.Position = UDim2.new((floatDistance - 2) / 13, -10, 0.5, -10)
    distanceSliderButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    distanceSliderButton.Text = ""
    distanceSliderButton.BorderSizePixel = 0
    distanceSliderButton.Parent = distanceSliderBg
    yPos = yPos + 60
    
    -- =========================================
    -- SECTION: ANTI-LAG INFO
    -- =========================================
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
    -- FUNGSI UPDATE GUI
    -- =========================================
    local function updateGUI()
        -- Update status floating
        if floatingActive then
            statusValue.Text = "ON"
            statusValue.TextColor3 = Color3.fromRGB(100, 255, 100)
            toggleFloatBtn.Text = "🔴 MATIKAN FLOATING MODE"
            toggleFloatBtn.BackgroundColor3 = Color3.fromRGB(200, 80, 80)
        else
            statusValue.Text = "OFF"
            statusValue.TextColor3 = Color3.fromRGB(255, 100, 100)
            toggleFloatBtn.Text = "🟢 AKTIFKAN FLOATING MODE"
            toggleFloatBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
        end
        
        -- Update status auto attack
        if autoAttackActive then
            autoAttackValue.Text = "ON"
            autoAttackValue.TextColor3 = Color3.fromRGB(100, 255, 100)
            toggleAttackBtn.Text = "⚔️ MATIKAN AUTO ATTACK"
            toggleAttackBtn.BackgroundColor3 = Color3.fromRGB(200, 80, 80)
        else
            autoAttackValue.Text = "OFF"
            autoAttackValue.TextColor3 = Color3.fromRGB(255, 100, 100)
            toggleAttackBtn.Text = "⚔️ AKTIFKAN AUTO ATTACK"
            toggleAttackBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 200)
        end
        
        -- Update target info
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
        
        -- Update filter info
        if #targetMobFilters == 0 then
            activeFilterLabel.Text = "Filter aktif: Semua mob"
        else
            activeFilterLabel.Text = "Filter aktif: " .. table.concat(targetMobFilters, ", ")
        end
        
        -- Update radius values
        searchRadiusValue.Text = searchRadius .. "m"
        attackRadiusValue.Text = attackRadius .. "m"
        distanceValue.Text = floatDistance .. "m"
        
        -- Update slider positions
        local searchPercent = (searchRadius - 20) / 130
        searchSliderFill.Size = UDim2.new(searchPercent, 0, 1, 0)
        searchSliderButton.Position = UDim2.new(searchPercent, -10, 0.5, -10)
        
        local attackPercent = (attackRadius - 5) / 45
        attackSliderFill.Size = UDim2.new(attackPercent, 0, 1, 0)
        attackSliderButton.Position = UDim2.new(attackPercent, -10, 0.5, -10)
        
        local distPercent = (floatDistance - 2) / 13
        distanceSliderFill.Size = UDim2.new(distPercent, 0, 1, 0)
        distanceSliderButton.Position = UDim2.new(distPercent, -10, 0.5, -10)
        
        -- Update anti-lag info
        noMobText.Text = "Pencarian Gagal: " .. noMobCount .. "x"
        cooldownText.Text = "Cooldown: " .. string.format("%.1f", searchCooldown) .. " detik"
    end
    
    -- =========================================
    -- EVENT HANDLER
    -- =========================================
    
    -- Tombol Toggle Floating
    toggleFloatBtn.MouseButton1Click:Connect(function()
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
    
    -- Tombol Toggle Auto Attack
    toggleAttackBtn.MouseButton1Click:Connect(function()
        pcall(function()
            autoAttackActive = not autoAttackActive
            print("⚔️ AUTO ATTACK:", autoAttackActive and "AKTIF" or "DIMATIKAN")
            updateGUI()
        end)
    end)
    
    -- Tombol Apply Filter
    applyFilterBtn.MouseButton1Click:Connect(function()
        pcall(function()
            local filterString = nameInput.Text
            targetMobFilters = parseFilters(filterString)
            
            if #targetMobFilters == 0 then
                print("🎯 Filter: Semua mob")
            else
                print("🎯 Multi-Filter: " .. table.concat(targetMobFilters, ", "))
            end
            
            if floatingActive then
                currentTarget = nil
                noMobCount = 0
                lastSearchTime = 0
                findNewTarget()
            end
            
            updateGUI()
        end)
    end)
    
    -- Tombol Reset Filter
    resetFilterBtn.MouseButton1Click:Connect(function()
        pcall(function()
            nameInput.Text = ""
            targetMobFilters = {}
            print("🎯 Filter direset: Semua mob")
            
            if floatingActive then
                currentTarget = nil
                noMobCount = 0
                lastSearchTime = 0
                findNewTarget()
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
    local searchDragging = false
    local attackDragging = false
    local distanceDragging = false
    
    searchSliderButton.MouseButton1Down:Connect(function()
        searchDragging = true
    end)
    
    attackSliderButton.MouseButton1Down:Connect(function()
        attackDragging = true
    end)
    
    distanceSliderButton.MouseButton1Down:Connect(function()
        distanceDragging = true
    end)
    
    userInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            searchDragging = false
            attackDragging = false
            distanceDragging = false
        end
    end)
    
    userInputService.InputChanged:Connect(function(input)
        pcall(function()
            if searchDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                local mousePos = userInputService:GetMouseLocation()
                local sliderPos = searchSliderBg.AbsolutePosition
                local sliderSize = searchSliderBg.AbsoluteSize.X
                
                if sliderSize > 0 then
                    local relativeX = math.clamp(mousePos.X - sliderPos.X, 0, sliderSize)
                    local percent = relativeX / sliderSize
                    
                    searchRadius = math.floor(20 + (percent * 130))
                    searchRadius = math.clamp(searchRadius, 20, 150)
                    
                    print("📡 Radius pencarian:", searchRadius)
                    
                    if floatingActive then
                        currentTarget = nil
                        lastSearchTime = 0
                        findNewTarget()
                    end
                    
                    updateGUI()
                end
            end
            
            if attackDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                local mousePos = userInputService:GetMouseLocation()
                local sliderPos = attackSliderBg.AbsolutePosition
                local sliderSize = attackSliderBg.AbsoluteSize.X
                
                if sliderSize > 0 then
                    local relativeX = math.clamp(mousePos.X - sliderPos.X, 0, sliderSize)
                    local percent = relativeX / sliderSize
                    
                    attackRadius = math.floor(5 + (percent * 45))
                    attackRadius = math.clamp(attackRadius, 5, 50)
                    
                    print("⚔️ Radius auto attack:", attackRadius)
                    updateGUI()
                end
            end
            
            if distanceDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                local mousePos = userInputService:GetMouseLocation()
                local sliderPos = distanceSliderBg.AbsolutePosition
                local sliderSize = distanceSliderBg.AbsoluteSize.X
                
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

-- LOOP UTAMA (Floating + Auto Attack)
runService.Heartbeat:Connect(function()
    pcall(function()
        if not character or not humanoidRootPart then
            if player.Character then
                updateCharacter()
            end
            return
        end
        
        -- Auto Attack (jalan terus kalau aktif)
        if autoAttackActive and floatingActive then
            autoAttack()
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

-- Buat GUI
updateGUIFunc = createGUI()

print("=================================")
print("✅ RPG Grinder - FLOATING MODE")
print("    + AUTO ATTACK")
print("=================================")
print("🎯 FITUR BARU:")
print("   • Auto Attack dengan radius 5-50")
print("   • Radius pencarian 20-150")
print("   • Multi-filter dengan koma")
print("=================================")
print("🖱️ Cara Penggunaan:")
print("1. Atur radius dengan slider")
print("2. Aktifkan Floating Mode")
print("3. Aktifkan Auto Attack")
print("4. Saksikan mob mati otomatis!")
print("=================================")
