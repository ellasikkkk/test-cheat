-- Script Utama RPG Grinder - Versi Ringan
local player = game.Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")

-- Cache untuk menyimpan mob yang sudah diproses
local mobCache = {}
local lastCleanup = tick()

-- Fungsi ringan untuk mencari mob (hanya sekali per detik)
local function findMobsInRange(range)
    local mobsInRange = {}
    local currentTime = tick()
    
    -- Bersihkan cache setiap 10 detik
    if currentTime - lastCleanup > 10 then
        mobCache = {}
        lastCleanup = currentTime
    end
    
    -- Batasi pencarian hanya di area sekitar player
    local region = Region3.new(
        humanoidRootPart.Position - Vector3.new(range, range, range),
        humanoidRootPart.Position + Vector3.new(range, range, range)
    )
    
    local parts = workspace:FindPartsInRegion3(region, nil, 100) -- Batasi jumlah parts
    
    for _, part in ipairs(parts) do
        local model = part.Parent
        if model and not mobCache[model] then
            if model:FindFirstChild("Humanoid") and not player:GetPlayerFromCharacter(model) then
                mobCache[model] = currentTime
                table.insert(mobsInRange, model)
            end
        end
    end
    
    return mobsInRange
end

-- Fungsi kill aura dengan delay
local lastKillTime = 0
local function killAura()
    if not getgenv().AutoFarm then return end
    
    local currentTime = tick()
    local killSpeed = getgenv().KillSpeed or 0.3
    
    if currentTime - lastKillTime < killSpeed then return end
    
    local mobs = findMobsInRange(getgenv().KillAuraRange or 25)
    
    for _, mob in ipairs(mobs) do
        local humanoid = mob:FindFirstChild("Humanoid")
        if humanoid and humanoid.Health > 0 then
            humanoid.Health = 0
        end
    end
    
    lastKillTime = currentTime
end

-- Gunakan game:GetService("RunService").Stepped untuk performa lebih baik
game:GetService("RunService").Stepped:Connect(killAura)

print("✅ RPG Grinder Ringan Loaded!")