-- Script Utama RPG Grinder - FLOATING MODE + AUTO CLICK
-- Auto attack dengan simulasi klik mouse (bukan kill aura)

local player = game.Players.LocalPlayer
local userInputService = game:GetService("UserInputService")
local runService = game:GetService("RunService")
local players = game:GetService("Players")
local virtualInputManager = game:GetService("VirtualInputManager")
local tweenService = game:GetService("TweenService")

-- VARIABEL GLOBAL
local floatingActive = false
local autoClickActive = false  -- Ganti nama dari autoAttack
local currentTarget = nil
local floatDistance = 5
local searchRadius = 50
local attackRadius = 15  -- Radius untuk mendeteksi apakah target bisa diklik
local targetMobFilters = {}
local character = nil
local humanoidRootPart = nil

-- VARIABEL UNTUK AUTO CLICK
local clickCooldown = 0
local lastClickTime = 0
local clickSpeed = 0.2  -- Kecepatan klik (detik)
local isClicking = false

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

-- FUNGSI: Cek apakah target dalam jangkauan serangan
local function isTargetInRange()
    if not currentTarget or not currentTarget.rootPart or not humanoidRootPart then 
        return false 
    end
    
    local distance = (humanoidRootPart.Position - currentTarget.rootPart.Position).Magnitude
    return distance <= attackRadius
end

-- FUNGSI: Auto Click - Mensimulasikan klik mouse
local function autoClick()
    if not autoClickActive or not floatingActive then return end
    if not currentTarget then return end
    
    -- Cek cooldown
    local currentTime = tick()
    if currentTime - lastClickTime < clickCooldown then
        return
    end
    
    -- Cek apakah target dalam jangkauan
    if not isTargetInRange() then
        return
    end
    
    -- Simulasi klik kiri mouse
    pcall(function()
        -- Metode 1: VirtualInputManager (paling mirip klik asli)
        virtualInputManager:SendMouseButtonEvent(
            userInputService:GetMouseLocation().X,  -- Posisi X mouse
            userInputService:GetMouseLocation().Y,  -- Posisi Y mouse
            0,  -- Tombol kiri (0 = kiri, 1 = kanan, 2 = tengah)
            true,  -- Down
            game,  -- Objek
            0  -- ID
        )
        
        -- Tunggu sebentar
        wait(0.05)
        
        -- Lepas klik
        virtualInputManager:SendMouseButtonEvent(
            userInputService:GetMouseLocation().X,
            userInputService:GetMouseLocation().Y,
            0,
            false,  -- Up
            game,
            0
        )
        
        print("🖱️ Auto Click ke:", currentTarget.model.Name)
    end)
    
    -- Metode 2: Alternative jika VirtualInputManager tidak bekerja
    -- Ini hanya fallback, menggunakan mekanisme damage langsung
    -- pcall(function()
    --     if currentTarget and currentTarget.humanoid then
    --         currentTarget.humanoid.Health = currentTarget.humanoid.Health - 10
    --     end
    -- end)
    
    lastClickTime = currentTime
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
-- MEMBUAT GUI LENGKAP DENGAN AUTO CLICK
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
    mainFrame.Size = UDim2.new(0, 400, 0, 720)
    mainFrame.Position = UDim2.new(0, 20, 0.5, -360)
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
    titleText.Text = "⚡ RPG GRINDER - AUTO CLICK"
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
    contentFrame.CanvasSize = UDim2.new(0, 0, 0, 920)
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
    
    -- Status Auto Click
    local autoClickStatusFrame = Instance.new("Frame")
    autoClickStatusFrame.Size = UDim2.new(1, 0, 0, 40)
    autoClickStatusFrame.Position = UDim2.new(0, 0, 0, yPos)
    autoClickStatusFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
    autoClickStatusFrame.BorderSizePixel = 0
    autoClickStatusFrame.Parent = contentFrame
    
    local autoClickText = Instance.new("TextLabel")
    autoClickText.Size = UDim2.new(0.5, -5, 1, 0)
    autoClickText.Position = UDim2.new(0, 10, 0, 0)
    autoClickText.BackgroundTransparency = 1
    autoClickText.Text = "Auto Click:"
    autoClickText.TextColor3 = Color3.fromRGB(200, 200, 200)
    autoClickText.TextXAlignment = Enum.TextXAlignment.Left
    autoClickText.Font = Enum.Font.Gotham
    autoClickText.TextSize = 14
    autoClickText.Parent = autoClickStatusFrame
    
    local autoClickValue = Instance.new("TextLabel")
    autoClickValue.Size = UDim2.new(0.5, -5, 1, 0)
    autoClickValue.Position = UDim2.new(0.5, 5, 0, 0)
    autoClickValue.BackgroundTransparency = 1
    autoClickValue.Text = "OFF"
    autoClickValue.TextColor3 = Color3.fromRGB(255, 100, 100)
    autoClickValue.TextXAlignment = Enum.TextXAlignment.Right
    autoClickValue.Font = Enum.Font.GothamBold
    autoClickValue.TextSize = 14
    autoClickValue.Parent = autoClickStatusFrame
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
    
    -- Tombol Toggle Auto Click
    local toggleClickBtn = Instance.new("TextButton")
    toggleClickBtn.Size = UDim2.new(1, -20, 0, 35)
    toggleClickBtn.Position = UDim2.new(0, 10, 0, yPos)
    toggleClickBtn.BackgroundColor3 = Color3.fromRGB(200, 100, 100)
    toggleClickBtn.Text = "🖱️ AKTIFKAN AUTO CLICK"
    toggleClickBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggleClickBtn.Font = Enum.Font.GothamBold
    toggleClickBtn.TextSize = 14
    toggleClickBtn.Parent = contentFrame
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
    -- SECTION: PENGATURAN RADIUS DAN KECEPATAN
    -- =========================================
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
    
    -- Slider Radius Pencarian
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
    searchSliderFill.Size = UDim2.new((searchRadius - 20) / 130, 0, 1, 0)
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
    
    -- Slider Radius Auto Click
    local clickRadiusFrame = Instance.new("Frame")
    clickRadiusFrame.Size = UDim2.new(1, 0, 0, 50)
    clickRadiusFrame.Position = UDim2.new(0, 0, 0, yPos)
    clickRadiusFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
    clickRadiusFrame.BorderSizePixel = 0
    clickRadiusFrame.Parent = contentFrame
    
    local clickRadiusText = Instance.new("TextLabel")
    clickRadiusText.Size = UDim2.new(0.5, -5, 0, 25)
    clickRadiusText.Position = UDim2.new(0, 10, 0, 5)
    clickRadiusText.BackgroundTransparency = 1
    clickRadiusText.Text = "Radius Auto Click:"
    clickRadiusText.TextColor3 = Color3.fromRGB(200, 200, 200)
    clickRadiusText.TextXAlignment = Enum.TextXAlignment.Left
    clickRadiusText.Font = Enum.Font.Gotham
    clickRadiusText.TextSize = 13
    clickRadiusText.Parent = clickRadiusFrame
    
    local clickRadiusValue = Instance.new("TextLabel")
    clickRadiusValue.Size = UDim2.new(0.2, 0, 0, 25)
    clickRadiusValue.Position = UDim2.new(0.8, -20, 0, 5)
    clickRadiusValue.BackgroundTransparency = 1
    clickRadiusValue.Text = attackRadius .. "m"
    clickRadiusValue.TextColor3 = Color3.fromRGB(255, 255, 255)
    clickRadiusValue.TextXAlignment = Enum.TextXAlignment.Right
    clickRadiusValue.Font = Enum.Font.GothamBold
    clickRadiusValue.TextSize = 14
    clickRadiusValue.Parent = clickRadiusFrame
    
    local clickSliderBg = Instance.new("Frame")
    clickSliderBg.Size = UDim2.new(0.6, -10, 0, 10)
    clickSliderBg.Position = UDim2.new(0.4, 5, 0, 35)
    clickSliderBg.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
    clickSliderBg.BorderSizePixel = 0
    clickSliderBg.Parent = clickRadiusFrame
    
    local clickSliderFill = Instance.new("Frame")
    clickSliderFill.Size = UDim2.new((attackRadius - 5) / 45, 0, 1, 0)
    clickSliderFill.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
    clickSliderFill.BorderSizePixel = 0
    clickSliderFill.Parent = clickSliderBg
    
    local clickSliderButton = Instance.new("TextButton")
    clickSliderButton.Size = UDim2.new(0, 20, 0, 20)
    clickSliderButton.Position = UDim2.new((attackRadius - 5) / 45, -10, 0.5, -10)
    clickSliderButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    clickSliderButton.Text = ""
    clickSliderButton.BorderSizePixel = 0
    clickSliderButton.Parent = clickSliderBg
    yPos = yPos + 60
    
    -- Slider Kecepatan Click
    local speedFrame = Instance.new("Frame")
    speedFrame.Size = UDim2.new(1, 0, 0, 50)
    speedFrame.Position = UDim2.new(0, 0, 0, yPos)
    speedFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
    speedFrame.BorderSizePixel = 0
    speedFrame.Parent = contentFrame
    
    local speedText = Instance.new("TextLabel")
    speedText.Size = UDim2.new(0.5, -5, 0, 25)
    speedText.Position = UDim2.new(0, 10, 0, 5)
    speedText.BackgroundTransparency = 1
    speedText.Text = "Kecepatan Click:"
    speedText.TextColor3 = Color3.fromRGB(200, 200, 200)
    speedText.TextXAlignment = Enum.TextXAlignment.Left
    speedText.Font = Enum.Font.Gotham
    speedText.TextSize = 13
    speedText.Parent = speedFrame
    
    local speedValue = Instance.new("TextLabel")
    speedValue.Size = UDim2.new(0.2, 0, 0, 25)
    speedValue.Position = UDim2.new(0.8, -20, 0, 5)
    speedValue.BackgroundTransparency = 1
    speedValue.Text = string.format("%.1f", clickSpeed) .. "s"
    speedValue.TextColor3 = Color3.fromRGB(255, 255, 255)
    speedValue.TextXAlignment = Enum.TextXAlignment.Right
    speedValue.Font = Enum.Font.GothamBold
    speedValue.TextSize = 14
    speedValue.Parent = speedFrame
    
    local speedSliderBg = Instance.new("Frame")
    speedSliderBg.Size = UDim2.new(0.6, -10, 0, 10)
    speedSliderBg.Position = UDim2.new(0.4, 5, 0, 35)
    speedSliderBg.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
    speedSliderBg.BorderSizePixel = 0
    speedSliderBg.Parent = speedFrame
    
    -- Speed range: 0.05 - 1.0 detik
    local speedPercent = (1 - (clickSpeed - 0.05) / 0.95)  -- Invert so left = fast, right = slow
    local speedSliderFill = Instance.new("Frame")
    speedSliderFill.Size = UDim2.new(speedPercent, 0, 1, 0)
    speedSliderFill.BackgroundColor3 = Color3.fromRGB(100, 255, 100)
    speedSliderFill.BorderSizePixel = 0
    speedSliderFill.Parent = speedSliderBg
    
    local speedSliderButton = Instance.new("TextButton")
    speedSliderButton.Size = UDim2.new(0, 20, 0, 20)
    speedSliderButton.Position = UDim2.new(speedPercent, -10, 0.5, -10)
    speedSliderButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    speedSliderButton.Text = ""
    speedSliderButton.BorderSizePixel = 0
    speedSliderButton.Parent = speedSliderBg
    yPos = yPos + 60
    
    -- Slider Jarak Belakang
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
        
        -- Update status auto click
        if autoClickActive then
            autoClickValue.Text = "ON"
            autoClickValue.TextColor3 = Color3.fromRGB(100, 255, 100)
            toggleClickBtn.Text = "🖱️ MATIKAN AUTO CLICK"
            toggleClickBtn.BackgroundColor3 = Color3.fromRGB(200, 80, 80)
        else
            autoClickValue.Text = "OFF"
            autoClickValue.TextColor3 = Color3.fromRGB(255, 100, 100)
            toggleClickBtn.Text = "🖱️ AKTIFKAN AUTO CLICK"
            toggleClickBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 200)
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
        
        -- Update values
        searchRadiusValue.Text = searchRadius .. "m"
        clickRadiusValue.Text = attackRadius .. "m"
        speedValue.Text = string.format("%.1f", clickSpeed) .. "s"
        distanceValue.Text = floatDistance .. "m"
        
        -- Update slider positions
        local searchPercent = (searchRadius - 20) / 130
        searchSliderFill.Size = UDim2.new(searchPercent, 0, 1, 0)
        searchSliderButton.Position = UDim2.new(searchPercent, -10, 0.5, -10)
        
        local clickPercent = (attackRadius - 5) / 45
        clickSliderFill.Size = UDim2.new(clickPercent, 0, 1, 0)
        clickSliderButton.Position = UDim2.new(clickPercent, -10, 0.5, -10)
        
        local speedPercent = 1 - ((clickSpeed - 0.05) / 0.95)
        speedSliderFill.Size = UDim2.new(speedPercent, 0, 1, 0)
        speedSliderButton.Position = UDim2.new(speedPercent, -10, 0.5, -10)
        
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
    
    -- Tombol Toggle Auto Click
    toggleClickBtn.MouseButton1Click:Connect(function()
        pcall(function()
            autoClickActive = not autoClickActive
            print("🖱️ AUTO CLICK:", autoClickActive and "AKTIF" or "DIMATIKAN")
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
    local clickRadiusDragging = false
    local speedDragging = false
    local distanceDragging = false
    
    searchSliderButton.MouseButton1Down:Connect(function()
        searchDragging = true
    end)
    
    clickSliderButton.MouseButton1Down:Connect(function()
        clickRadiusDragging = true
    end)
    
    speedSliderButton.MouseButton1Down:Connect(function()
        speedDragging = true
    end)
    
    distanceSliderButton.MouseButton1Down:Connect(function()
        distanceDragging = true
    end)
    
    userInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            searchDragging = false
            clickRadiusDragging = false
            speedDragging = false
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
                    
                    if floatingActive then
                        currentTarget = nil
                        lastSearchTime = 0
                        findNewTarget()
                    end
                    
                    updateGUI()
                end
            end
            
            if clickRadiusDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                local mousePos = userInputService:GetMouseLocation()
                local sliderPos = clickSliderBg.AbsolutePosition
                local sliderSize = clickSliderBg.AbsoluteSize.X
                
                if sliderSize > 0 then
                    local relativeX = math.clamp(mousePos.X - sliderPos.X, 0, sliderSize)
                    local percent = relativeX / sliderSize
                    
                    attackRadius = math.floor(5 + (percent * 45))
                    attackRadius = math.clamp(attackRadius, 5, 50)
                    
                    updateGUI()
                end
            end
            
            if speedDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                local mousePos = userInputService:GetMouseLocation()
                local sliderPos = speedSliderBg.AbsolutePosition
                local sliderSize = speedSliderBg.AbsoluteSize.X
                
                if sliderSize > 0 then
                    local relativeX = math.clamp(mousePos.X - sliderPos.X, 0, sliderSize)
                    local percent = relativeX / sliderSize
                    
                    -- Invert: left = fast, right = slow
                    clickSpeed = 0.05 + ((1 - percent) * 0.95)
                    clickSpeed = math.clamp(clickSpeed, 0.05, 1.0)
                    clickCooldown = clickSpeed
                    
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

-- LOOP UTAMA (Floating + Auto Click)
runService.Heartbeat:Connect(function()
    pcall(function()
        if not character or not humanoidRootPart then
            if player.Character then
                updateCharacter()
            end
            return
        end
        
        -- Auto Click (jalan terus kalau aktif)
        if autoClickActive and floatingActive then
            autoClick()
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
print("✅ RPG Grinder - AUTO CLICK MODE")
print("=================================")
print("🎯 FITUR AUTO CLICK:")
print("   • Simulasi klik mouse asli")
print("   • Radius click bisa diatur (5-50)")
print("   • Kecepatan click bisa diatur")
print("=================================")
print("🖱️ Cara Penggunaan:")
print("1. Atur radius click (5-50)")
print("2. Atur kecepatan click")
print("3. Aktifkan Floating Mode")
print("4. Aktifkan Auto Click")
print("5. Script akan klik otomatis!")
print("=================================")
