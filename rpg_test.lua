-- Script Utama RPG Grinder - KILL AURA MODE
-- Langsung mengurangi health mob dalam radius (tanpa klik)

local player = game.Players.LocalPlayer
local userInputService = game:GetService("UserInputService")
local runService = game:GetService("RunService")
local players = game:GetService("Players")
local tweenService = game:GetService("TweenService")

-- VARIABEL GLOBAL
local killAuraActive = false  -- Ubah dari autoClickActive
local floatingActive = false
local currentTarget = nil
local floatDistance = 5
local searchRadius = 50
local killRadius = 15  -- Radius untuk kill aura
local damageAmount = 30  -- Jumlah damage per tick
local targetMobFilters = {}
local character = nil
local humanoidRootPart = nil

-- VARIABEL UNTUK KILL AURA
local killCooldown = 0
local lastKillTime = 0
local killSpeed = 0.2  -- Kecepatan kill (detik)

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
-- FUNGSI DETEKSI NPC
-- =============================================

local NPC_NAMES = {
    ["Merchant"] = true, ["Villager"] = true, ["Guard"] = true,
    ["Shopkeeper"] = true, ["Blacksmith"] = true, ["Trader"] = true,
    ["Quest Giver"] = true, ["Bartender"] = true, ["Innkeeper"] = true,
    ["Priest"] = true, ["Wizard"] = true, ["Trainer"] = true,
    ["Banker"] = true, ["Mayor"] = true, ["King"] = true,
    ["Queen"] = true, ["Prince"] = true, ["Princess"] = true,
    ["Guide"] = true, ["Elder"] = true, ["Shaman"] = true,
    ["Healer"] = true, ["Smith"] = true, ["Farmer"] = true,
    ["Fisherman"] = true, ["Miner"] = true, ["Hunter"] = true,
    ["Chef"] = true, ["Baker"] = true, ["Alchemist"] = true,
    ["Enchanter"] = true, ["Armorer"] = true, ["Weaponsmith"] = true,
    ["Jeweler"] = true, ["Tailor"] = true, ["Leatherworker"] = true,
    ["Carpenter"] = true, ["Stable Master"] = true, ["Flight Master"] = true,
    ["Auctioneer"] = true, ["Postman"] = true, ["Guardian"] = true,
    ["Sentinel"] = true, ["Watchman"] = true, ["Patrol"] = true,
    ["Recruiter"] = true, ["Advisor"] = true, ["Councilor"] = true,
    ["Diplomat"] = true, ["Ambassador"] = true, ["Herald"] = true,
    ["Scribe"] = true, ["Librarian"] = true, ["Scholar"] = true,
    ["Teacher"] = true, ["Mentor"] = true, ["Apprentice"] = true,
    ["Student"] = true, ["Novice"] = true, ["Initiate"] = true,
    ["Acolyte"] = true, ["Disciple"] = true, ["Follower"] = true
}

-- FUNGSI: Cek apakah ini NPC
local function isNPC(obj)
    if not obj then return false end
    
    local objName = obj.Name
    if NPC_NAMES[objName] then
        return true
    end
    
    local humanoid = obj:FindFirstChild("Humanoid")
    if humanoid then
        if humanoid.MaxHealth == 0 or humanoid.Health == 0 then
            return true
        end
    end
    
    if obj:GetAttribute("NPC") or obj:GetAttribute("IsNPC") then
        return true
    end
    
    if obj.Parent and obj.Parent.Name:lower():find("npc") then
        return true
    end
    
    return false
end

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

-- FUNGSI: Parse string filter
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
            
            -- SKIP NPC
            if isNPC(obj) then
                continue
            end
            
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

-- FUNGSI: Mendapatkan semua mob dalam radius kill
local function getMobsInKillRange()
    if not humanoidRootPart then return {} end
    
    local mobsInRange = {}
    local playerPos = humanoidRootPart.Position
    
    local region = Region3.new(
        playerPos - Vector3.new(killRadius, killRadius, killRadius),
        playerPos + Vector3.new(killRadius, killRadius, killRadius)
    )
    
    local parts = {}
    pcall(function()
        parts = workspace:FindPartsInRegion3(region, nil, 100)
    end)
    
    for _, part in ipairs(parts) do
        local obj = part.Parent
        if obj and obj:IsA("Model") and obj:FindFirstChild("Humanoid") and not players:GetPlayerFromCharacter(obj) then
            
            -- SKIP NPC
            if isNPC(obj) then
                continue
            end
            
            if not isMobNameMatch(obj.Name) then
                continue
            end
            
            local mobRoot = obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChild("Torso")
            if mobRoot then
                local humanoid = obj:FindFirstChild("Humanoid")
                if humanoid and humanoid.Health > 0 then
                    local distance = (playerPos - mobRoot.Position).Magnitude
                    if distance <= killRadius then
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

-- FUNGSI: KILL AURA AGGRESIF (Memastikan mob mati)
local function killAura()
    if not killAuraActive or not floatingActive then return end
    
    local currentTime = tick()
    if currentTime - lastKillTime < killCooldown then return end
    
    local mobs = getMobsInKillRange()
    local killedCount = 0
    
    for _, mob in ipairs(mobs) do
        if mob and mob.humanoid and mob.humanoid.Health > 0 then
            
            -- METODE 1: Paksa health jadi 0 (jika game mengizinkan)
            local success1 = pcall(function()
                mob.humanoid.Health = 0
            end)
            
            -- Kalau metode 1 gagal atau health masih >0, coba metode lain
            if not success1 or mob.humanoid.Health > 0 then
                
                -- METODE 2: Kurangi health berulang kali dalam satu tick
                pcall(function()
                    for i = 1, 20 do  -- Kurangi 20 kali berturut-turut
                        mob.humanoid.Health = mob.humanoid.Health - damageAmount
                        wait()  -- Beri jeda kecil antar damage
                        if mob.humanoid.Health <= 0 then break end
                    end
                end)
                
                -- METODE 3: Gunakan :TakeDamage() jika tersedia
                pcall(function()
                    if mob.humanoid.TakeDamage then
                        mob.humanoid:TakeDamage(999999)  -- Damage besar
                    end
                end)
                
                -- METODE 4: Coba remote event attack (jika ada)
                pcall(function()
                    -- Cari remote event di ReplicatedStorage
                    for _, remote in ipairs(game:GetService("ReplicatedStorage"):GetChildren()) do
                        if remote:IsA("RemoteEvent") and remote.Name:lower():find("attack") then
                            remote:FireServer(mob.model)
                            break
                        end
                    end
                end)
            end
            
            -- Cek apakah mob sudah mati
            if mob.humanoid.Health <= 0 then
                killedCount = killedCount + 1
                print("💀 Mob MATI:", mob.model.Name)
                
                -- Opsional: Hancurkan model jika perlu
                -- pcall(function()
                --     mob.model:BreakJoints()
                --     wait(0.1)
                --     mob.model:Destroy()
                -- end)
            else
                print("⚔️ Damage:", mob.model.Name, "| HP:", math.floor(mob.humanoid.Health))
            end
        end
    end
    
    if #mobs > 0 then
        lastKillTime = currentTime
    end
end

-- FUNGSI: DIAGNOSA MOB (Tekan D untuk cek kenapa tidak mati)
local function diagnoseMobDeath()
    if not currentTarget or not currentTarget.humanoid then 
        print("❌ Tidak ada target untuk diagnosa")
        return 
    end
    
    local health = currentTarget.humanoid.Health
    local maxHealth = currentTarget.humanoid.MaxHealth
    
    print("=================================")
    print("🔍 DIAGNOSA MOB:")
    print("=================================")
    print("Nama:", currentTarget.model.Name)
    print("Health:", health)
    print("MaxHealth:", maxHealth)
    print("Sisa HP:", health, "/", maxHealth)
    
    -- Cek apakah bisa di-set ke 0
    local bisaSetKe0 = pcall(function()
        currentTarget.humanoid.Health = 0
        return currentTarget.humanoid.Health == 0
    end)
    
    if bisaSetKe0 then
        print("✅ Bisa di-set ke 0 (seharusnya mati)")
    else
        print("❌ TIDAK bisa di-set ke 0 (ada perlindungan)")
    end
    
    -- Cek apakah ada TakeDamage method
    if currentTarget.humanoid.TakeDamage then
        print("✅ Memiliki method TakeDamage")
    else
        print("❌ Tidak memiliki TakeDamage")
    end
    
    -- Cari remote event attack
    local remotesDitemukan = 0
    for _, remote in ipairs(game:GetService("ReplicatedStorage"):GetChildren()) do
        if remote:IsA("RemoteEvent") and remote.Name:lower():find("attack") then
            remotesDitemukan = remotesDitemukan + 1
        end
    end
    print("Remote attack ditemukan:", remotesDitemukan)
    print("=================================")
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
-- MEMBUAT GUI (DIMODIFIKASI UNTUK KILL AURA)
-- =============================================

local function createGUI()
    -- Hapus GUI lama
    pcall(function()
        for _, gui in pairs(player.PlayerGui:GetChildren()) do
            if gui.Name == "KillAuraGUI" then
                gui:Destroy()
            end
        end
    end)
    
    -- ScreenGui utama
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "KillAuraGUI"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = player.PlayerGui
    
    -- Frame utama
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 400, 0, 700)
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
    titleText.Text = "⚡ RPG GRINDER - KILL AURA"
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
    contentFrame.CanvasSize = UDim2.new(0, 0, 0, 900)
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
    
    -- Status Floating
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
    
    -- Status Kill Aura
    local killStatusFrame = Instance.new("Frame")
    killStatusFrame.Size = UDim2.new(1, 0, 0, 40)
    killStatusFrame.Position = UDim2.new(0, 0, 0, yPos)
    killStatusFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
    killStatusFrame.BorderSizePixel = 0
    killStatusFrame.Parent = contentFrame
    
    local killStatusText = Instance.new("TextLabel")
    killStatusText.Size = UDim2.new(0.5, -5, 1, 0)
    killStatusText.Position = UDim2.new(0, 10, 0, 0)
    killStatusText.BackgroundTransparency = 1
    killStatusText.Text = "Kill Aura:"
    killStatusText.TextColor3 = Color3.fromRGB(200, 200, 200)
    killStatusText.TextXAlignment = Enum.TextXAlignment.Left
    killStatusText.Font = Enum.Font.Gotham
    killStatusText.TextSize = 14
    killStatusText.Parent = killStatusFrame
    
    local killStatusValue = Instance.new("TextLabel")
    killStatusValue.Size = UDim2.new(0.5, -5, 1, 0)
    killStatusValue.Position = UDim2.new(0.5, 5, 0, 0)
    killStatusValue.BackgroundTransparency = 1
    killStatusValue.Text = "OFF"
    killStatusValue.TextColor3 = Color3.fromRGB(255, 100, 100)
    killStatusValue.TextXAlignment = Enum.TextXAlignment.Right
    killStatusValue.Font = Enum.Font.GothamBold
    killStatusValue.TextSize = 14
    killStatusValue.Parent = killStatusFrame
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
    
    -- Tombol Toggle Kill Aura
    local toggleKillBtn = Instance.new("TextButton")
    toggleKillBtn.Size = UDim2.new(1, -20, 0, 35)
    toggleKillBtn.Position = UDim2.new(0, 10, 0, yPos)
    toggleKillBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    toggleKillBtn.Text = "⚔️ AKTIFKAN KILL AURA"
    toggleKillBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggleKillBtn.Font = Enum.Font.GothamBold
    toggleKillBtn.TextSize = 14
    toggleKillBtn.Parent = contentFrame
    yPos = yPos + 45
    
    -- SECTION: MULTI-FILTER
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
    nameInput.PlaceholderText = "Contoh: Slime, Goblin, Boss"
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
    
    -- Slider Radius Kill Aura
    local killRadiusFrame = Instance.new("Frame")
    killRadiusFrame.Size = UDim2.new(1, 0, 0, 50)
    killRadiusFrame.Position = UDim2.new(0, 0, 0, yPos)
    killRadiusFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
    killRadiusFrame.BorderSizePixel = 0
    killRadiusFrame.Parent = contentFrame
    
    local killRadiusText = Instance.new("TextLabel")
    killRadiusText.Size = UDim2.new(0.5, -5, 0, 25)
    killRadiusText.Position = UDim2.new(0, 10, 0, 5)
    killRadiusText.BackgroundTransparency = 1
    killRadiusText.Text = "Radius Kill Aura:"
    killRadiusText.TextColor3 = Color3.fromRGB(200, 200, 200)
    killRadiusText.TextXAlignment = Enum.TextXAlignment.Left
    killRadiusText.Font = Enum.Font.Gotham
    killRadiusText.TextSize = 13
    killRadiusText.Parent = killRadiusFrame
    
    local killRadiusValue = Instance.new("TextLabel")
    killRadiusValue.Size = UDim2.new(0.2, 0, 0, 25)
    killRadiusValue.Position = UDim2.new(0.8, -20, 0, 5)
    killRadiusValue.BackgroundTransparency = 1
    killRadiusValue.Text = killRadius .. "m"
    killRadiusValue.TextColor3 = Color3.fromRGB(255, 255, 255)
    killRadiusValue.TextXAlignment = Enum.TextXAlignment.Right
    killRadiusValue.Font = Enum.Font.GothamBold
    killRadiusValue.TextSize = 14
    killRadiusValue.Parent = killRadiusFrame
    
    local killSliderBg = Instance.new("Frame")
    killSliderBg.Size = UDim2.new(0.6, -10, 0, 10)
    killSliderBg.Position = UDim2.new(0.4, 5, 0, 35)
    killSliderBg.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
    killSliderBg.BorderSizePixel = 0
    killSliderBg.Parent = killRadiusFrame
    
    local killSliderFill = Instance.new("Frame")
    killSliderFill.Size = UDim2.new((killRadius - 5) / 45, 0, 1, 0)
    killSliderFill.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
    killSliderFill.BorderSizePixel = 0
    killSliderFill.Parent = killSliderBg
    
    local killSliderButton = Instance.new("TextButton")
    killSliderButton.Size = UDim2.new(0, 20, 0, 20)
    killSliderButton.Position = UDim2.new((killRadius - 5) / 45, -10, 0.5, -10)
    killSliderButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    killSliderButton.Text = ""
    killSliderButton.BorderSizePixel = 0
    killSliderButton.Parent = killSliderBg
    yPos = yPos + 60
    
    -- Slider Kecepatan Kill
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
    speedText.Text = "Kecepatan Kill:"
    speedText.TextColor3 = Color3.fromRGB(200, 200, 200)
    speedText.TextXAlignment = Enum.TextXAlignment.Left
    speedText.Font = Enum.Font.Gotham
    speedText.TextSize = 13
    speedText.Parent = speedFrame
    
    local speedValue = Instance.new("TextLabel")
    speedValue.Size = UDim2.new(0.2, 0, 0, 25)
    speedValue.Position = UDim2.new(0.8, -20, 0, 5)
    speedValue.BackgroundTransparency = 1
    speedValue.Text = string.format("%.1f", killSpeed) .. "s"
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
    
    local speedPercent = 1 - ((killSpeed - 0.05) / 0.95)
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
    
    -- SECTION: DAMAGE SETTINGS
    local damageLabel = Instance.new("TextLabel")
    damageLabel.Size = UDim2.new(1, 0, 0, 25)
    damageLabel.Position = UDim2.new(0, 0, 0, yPos)
    damageLabel.BackgroundTransparency = 1
    damageLabel.Text = "💥 DAMAGE SETTINGS"
    damageLabel.TextColor3 = Color3.fromRGB(255, 150, 150)
    damageLabel.TextXAlignment = Enum.TextXAlignment.Left
    damageLabel.Font = Enum.Font.GothamBold
    damageLabel.TextSize = 14
    damageLabel.Parent = contentFrame
    yPos = yPos + 30
    
    local damageFrame = Instance.new("Frame")
    damageFrame.Size = UDim2.new(1, 0, 0, 50)
    damageFrame.Position = UDim2.new(0, 0, 0, yPos)
    damageFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
    damageFrame.BorderSizePixel = 0
    damageFrame.Parent = contentFrame
    
    local damageText = Instance.new("TextLabel")
    damageText.Size = UDim2.new(0.5, -5, 0, 25)
    damageText.Position = UDim2.new(0, 10, 0, 5)
    damageText.BackgroundTransparency = 1
    damageText.Text = "Damage per Tick:"
    damageText.TextColor3 = Color3.fromRGB(200, 200, 200)
    damageText.TextXAlignment = Enum.TextXAlignment.Left
    damageText.Font = Enum.Font.Gotham
    damageText.TextSize = 13
    damageText.Parent = damageFrame
    
    local damageValue = Instance.new("TextLabel")
    damageValue.Size = UDim2.new(0.2, 0, 0, 25)
    damageValue.Position = UDim2.new(0.8, -20, 0, 5)
    damageValue.BackgroundTransparency = 1
    damageValue.Text = damageAmount
    damageValue.TextColor3 = Color3.fromRGB(255, 255, 255)
    damageValue.TextXAlignment = Enum.TextXAlignment.Right
    damageValue.Font = Enum.Font.GothamBold
    damageValue.TextSize = 14
    damageValue.Parent = damageFrame
    
    local damageSliderBg = Instance.new("Frame")
    damageSliderBg.Size = UDim2.new(0.6, -10, 0, 10)
    damageSliderBg.Position = UDim2.new(0.4, 5, 0, 35)
    damageSliderBg.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
    damageSliderBg.BorderSizePixel = 0
    damageSliderBg.Parent = damageFrame
    
    local damageSliderFill = Instance.new("Frame")
    damageSliderFill.Size = UDim2.new((damageAmount - 5) / 95, 0, 1, 0)  -- Range 5-100
    damageSliderFill.BackgroundColor3 = Color3.fromRGB(255, 150, 150)
    damageSliderFill.BorderSizePixel = 0
    damageSliderFill.Parent = damageSliderBg
    
    local damageSliderButton = Instance.new("TextButton")
    damageSliderButton.Size = UDim2.new(0, 20, 0, 20)
    damageSliderButton.Position = UDim2.new((damageAmount - 5) / 95, -10, 0.5, -10)
    damageSliderButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    damageSliderButton.Text = ""
    damageSliderButton.BorderSizePixel = 0
    damageSliderButton.Parent = damageSliderBg
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
        
        -- Update status kill aura
        if killAuraActive then
            killStatusValue.Text = "ON"
            killStatusValue.TextColor3 = Color3.fromRGB(100, 255, 100)
            toggleKillBtn.Text = "⚔️ MATIKAN KILL AURA"
            toggleKillBtn.BackgroundColor3 = Color3.fromRGB(200, 80, 80)
        else
            killStatusValue.Text = "OFF"
            killStatusValue.TextColor3 = Color3.fromRGB(255, 100, 100)
            toggleKillBtn.Text = "⚔️ AKTIFKAN KILL AURA"
            toggleKillBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
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
        killRadiusValue.Text = killRadius .. "m"
        speedValue.Text = string.format("%.1f", killSpeed) .. "s"
        distanceValue.Text = floatDistance .. "m"
        damageValue.Text = damageAmount
        
        -- Update slider positions
        local searchPercent = (searchRadius - 20) / 130
        searchSliderFill.Size = UDim2.new(searchPercent, 0, 1, 0)
        searchSliderButton.Position = UDim2.new(searchPercent, -10, 0.5, -10)
        
        local killPercent = (killRadius - 5) / 45
        killSliderFill.Size = UDim2.new(killPercent, 0, 1, 0)
        killSliderButton.Position = UDim2.new(killPercent, -10, 0.5, -10)
        
        local speedPercent = 1 - ((killSpeed - 0.05) / 0.95)
        speedSliderFill.Size = UDim2.new(speedPercent, 0, 1, 0)
        speedSliderButton.Position = UDim2.new(speedPercent, -10, 0.5, -10)
        
        local distPercent = (floatDistance - 2) / 13
        distanceSliderFill.Size = UDim2.new(distPercent, 0, 1, 0)
        distanceSliderButton.Position = UDim2.new(distPercent, -10, 0.5, -10)
        
        local damagePercent = (damageAmount - 5) / 95
        damageSliderFill.Size = UDim2.new(damagePercent, 0, 1, 0)
        damageSliderButton.Position = UDim2.new(damagePercent, -10, 0.5, -10)
        
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
    
    -- Tombol Toggle Kill Aura
    toggleKillBtn.MouseButton1Click:Connect(function()
        pcall(function()
            killAuraActive = not killAuraActive
            print("⚔️ KILL AURA:", killAuraActive and "AKTIF" or "DIMATIKAN")
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
    local killRadiusDragging = false
    local speedDragging = false
    local distanceDragging = false
    local damageDragging = false
    
    searchSliderButton.MouseButton1Down:Connect(function()
        searchDragging = true
    end)
    
    killSliderButton.MouseButton1Down:Connect(function()
        killRadiusDragging = true
    end)
    
    speedSliderButton.MouseButton1Down:Connect(function()
        speedDragging = true
    end)
    
    distanceSliderButton.MouseButton1Down:Connect(function()
        distanceDragging = true
    end)
    
    damageSliderButton.MouseButton1Down:Connect(function()
        damageDragging = true
    end)
    
    userInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            searchDragging = false
            killRadiusDragging = false
            speedDragging = false
            distanceDragging = false
            damageDragging = false
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
            
            if killRadiusDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                local mousePos = userInputService:GetMouseLocation()
                local sliderPos = killSliderBg.AbsolutePosition
                local sliderSize = killSliderBg.AbsoluteSize.X
                
                if sliderSize > 0 then
                    local relativeX = math.clamp(mousePos.X - sliderPos.X, 0, sliderSize)
                    local percent = relativeX / sliderSize
                    
                    killRadius = math.floor(5 + (percent * 45))
                    killRadius = math.clamp(killRadius, 5, 50)
                    
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
                    
                    killSpeed = 0.05 + ((1 - percent) * 0.95)
                    killSpeed = math.clamp(killSpeed, 0.05, 1.0)
                    killCooldown = killSpeed
                    
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
            
            if damageDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                local mousePos = userInputService:GetMouseLocation()
                local sliderPos = damageSliderBg.AbsolutePosition
                local sliderSize = damageSliderBg.AbsoluteSize.X
                
                if sliderSize > 0 then
                    local relativeX = math.clamp(mousePos.X - sliderPos.X, 0, sliderSize)
                    local percent = relativeX / sliderSize
                    
                    damageAmount = math.floor(5 + (percent * 95))
                    damageAmount = math.clamp(damageAmount, 5, 100)
                    
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
        
        if input.KeyCode == Enum.KeyCode.F then
            if not character or not humanoidRootPart then
                waitForCharacter()
            end
            
            floatingActive = not floatingActive
            
            if floatingActive then
                print("🚀 FLOATING MODE: AKTIF (via keyboard)")
                noMobCount = 0
                searchCooldown = SEARCH_DELAY_NORMAL
                lastSearchTime = 0
                findNewTarget()
            else
                print("💤 FLOATING MODE: DIMATIKAN (via keyboard)")
                resetPosition()
                currentTarget = nil
            end
            
            if updateGUIFunc then
                updateGUIFunc()
            end
        end
        
        if input.KeyCode == Enum.KeyCode.G then
            killAuraActive = not killAuraActive
            print("⚔️ KILL AURA:", killAuraActive and "AKTIF" or "DIMATIKAN")
            
            if updateGUIFunc then
                updateGUIFunc()
            end
        end
        
        -- TAMBAHKAN INI (Tombol D untuk diagnosa)
        if input.KeyCode == Enum.KeyCode.D then
            diagnoseMobDeath()
        end
    end)
end)

-- LOOP UTAMA (Floating + Kill Aura)
runService.Heartbeat:Connect(function()
    pcall(function()
        if not character or not humanoidRootPart then
            if player.Character then
                updateCharacter()
            end
            return
        end
        
        -- Kill Aura (jalan terus kalau aktif)
        if killAuraActive and floatingActive then
            killAura()
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
print("⚔️ RPG Grinder - KILL AURA MODE")
print("=================================")
print("🎯 FITUR KILL AURA:")
print("   • Langsung kurangi health mob")
print("   • Radius kill bisa diatur (5-50)")
print("   • Damage per tick bisa diatur (5-100)")
print("   • Kecepatan kill bisa diatur")
print("   • Filter NPC (tidak ke NPC)")
print("=================================")
print("⚔️ Cara Penggunaan:")
print("1. Atur radius kill (5-50)")
print("2. Atur damage (5-100)")
print("3. Atur kecepatan kill")
print("4. Aktifkan Floating Mode")
print("5. Aktifkan Kill Aura")
print("6. Mob akan mati otomatis!")
print("=================================")
print("⌨️ Keyboard Shortcut:")
print("F = Toggle Floating Mode")
print("G = Toggle Kill Aura")
print("=================================")


