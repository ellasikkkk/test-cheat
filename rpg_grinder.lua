-- Script Utama RPG Grinder - AUTO FARM RINGAN
-- Dioptimasi khusus untuk auto farm tanpa lag

local player = game.Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
local userInputService = game:GetService("UserInputService")
local players = game:GetService("Players")

-- VARIABEL KONTROL
local autoFarmActive = false
local killCooldown = 0
local mobList = {}  -- Daftar mob yang sudah ditemukan

-- FUNGSI: Cari mob dengan metode sangat ringan
local function scanMobs()
    -- Hanya scan jika auto farm aktif
    if not autoFarmActive then return end
    
    local currentTime = tick()
    local range = getgenv().KillAuraRange or 25
    local playerPos = humanoidRootPart.Position
    
    -- Reset daftar mob
    mobList = {}
    
    -- Scan cepat hanya di sekitar player
    local region = Region3.new(
        playerPos - Vector3.new(range, range, range),
        playerPos + Vector3.new(range, range, range)
    )
    
    -- Dapatkan semua part dalam region (jauh lebih cepat dari GetDescendants)
    local parts = workspace:FindPartsInRegion3(region, nil, 50)  -- Batasi maksimal 50 part
    
    for _, part in ipairs(parts) do
        local model = part.Parent
        -- Cek apakah ini mob (punya Humanoid dan bukan player)
        if model and model:FindFirstChild("Humanoid") and not players:GetPlayerFromCharacter(model) then
            local humanoid = model:FindFirstChild("Humanoid")
            local rootPart = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Torso")
            
            if humanoid and rootPart and humanoid.Health > 0 then
                -- Simpan data mob
                table.insert(mobList, {
                    model = model,
                    humanoid = humanoid,
                    rootPart = rootPart,
                    lastKill = 0
                })
            end
        end
    end
end

-- FUNGSI: Kill mob dengan cooldown
local function processKills()
    if not autoFarmActive then return end
    
    local currentTime = tick()
    local killSpeed = getgenv().KillSpeed or 0.3
    
    for _, mob in ipairs(mobList) do
        -- Cek apakah mob masih ada dan hidup
        if mob.model and mob.model.Parent and mob.humanoid and mob.humanoid.Health > 0 then
            -- Cek jarak
            local distance = (humanoidRootPart.Position - mob.rootPart.Position).Magnitude
            if distance <= (getgenv().KillAuraRange or 25) then
                -- Cek cooldown per mob
                if currentTime - mob.lastKill >= killSpeed then
                    mob.humanoid.Health = 0
                    mob.lastKill = currentTime
                end
            end
        end
    end
end

-- AUTO FARM LOOP - VERSI PALING RINGAN
local function startAutoFarm()
    spawn(function()
        while autoFarmActive do
            -- Scan mob baru setiap 1 detik (bukan setiap frame)
            scanMobs()
            
            -- Proses kill setiap 0.3 detik
            local startTime = tick()
            while autoFarmActive and tick() - startTime < 1 do
                processKills()
                wait(0.3)  -- Delay antar kill
            end
        end
    end)
end

-- TELEPORT FUNCTION
local function teleportToNearestMob()
    scanMobs()  -- Scan dulu
    
    if #mobList > 0 then
        local nearestMob = nil
        local shortestDist = math.huge
        local playerPos = humanoidRootPart.Position
        
        for _, mob in ipairs(mobList) do
            local dist = (playerPos - mob.rootPart.Position).Magnitude
            if dist < shortestDist then
                shortestDist = dist
                nearestMob = mob
            end
        end
        
        if nearestMob then
            humanoidRootPart.CFrame = nearestMob.rootPart.CFrame + Vector3.new(0, 5, 0)
            print("✅ Teleport ke:", nearestMob.model.Name)
        end
    else
        print("❌ Tidak ada mob di sekitar")
    end
end

-- KEYBIND SYSTEM
userInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    -- Toggle Auto Farm (Tombol F)
    if input.KeyCode == Enum.KeyCode[getgenv().KeyBindToggle or "F"] then
        autoFarmActive = not autoFarmActive
        
        if autoFarmActive then
            print("🚀 AUTO FARM: ON")
            startAutoFarm()  -- Mulai loop auto farm
        else
            print("💤 AUTO FARM: OFF")
        end
    end
    
    -- Teleport (Tombol T)
    if input.KeyCode == Enum.KeyCode[getgenv().TeleportKey or "T"] then
        teleportToNearestMob()
    end
    
    -- Kill Manual (Tombol K)
    if input.KeyCode == Enum.KeyCode.K then
        scanMobs()
        processKills()
        print("⚔️ Manual kill")
    end
end)

print("=================================")
print("✅ AUTO FARM ULTRA RINGAN Loaded!")
print("=================================")
print("Tekan", getgenv().KeyBindToggle or "F", "= ON/OFF Auto Farm")
print("Tekan", getgenv().TeleportKey or "T", "= Teleport")
print("Tekan K = Kill Manual")
print("=================================")
