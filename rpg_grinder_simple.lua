-- Script Utama RPG Grinder - VERSI RINGAN
-- Dioptimalkan agar tidak membuat frame drop

local player = game.Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
local userInputService = game:GetService("UserInputService")
local runService = game:GetService("RunService")
local players = game:GetService("Players")

-- Cache untuk menyimpan mob yang sudah ditemukan
local mobCache = {}
local lastCacheUpdate = tick()

-- Fungsi untuk mendapatkan semua mob di sekitar (dipanggil lebih jarang)
local function getAllMobsInRange(range)
    local currentTime = tick()
    local mobs = {}
    
    -- Update cache setiap 2 detik saja
    if currentTime - lastCacheUpdate > 2 then
        mobCache = {}
        for _, obj in pairs(workspace:GetChildren()) do  -- Gunakan GetChildren() bukan GetDescendants()
            if obj:IsA("Model") and obj:FindFirstChild("Humanoid") and not players:GetPlayerFromCharacter(obj) then
                local mobRoot = obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChild("Torso")
                if mobRoot then
                    local distance = (humanoidRootPart.Position - mobRoot.Position).Magnitude
                    if distance <= (range or 50) then
                        table.insert(mobs, obj)
                        mobCache[obj] = {
                            root = mobRoot,
                            humanoid = obj:FindFirstChild("Humanoid")
                        }
                    end
                end
            end
        end
        lastCacheUpdate = currentTime
    else
        -- Gunakan cache yang ada
        for mob, data in pairs(mobCache) do
            if mob and data.root and data.root.Parent then  -- Cek apakah mob masih ada
                table.insert(mobs, mob)
            else
                mobCache[mob] = nil  -- Hapus dari cache jika sudah tidak ada
            end
        end
    end
    
    return mobs
end

-- Fungsi untuk mendapatkan mob terdekat (lebih efisien)
local function getNearestMob(range)
    local nearestMob = nil
    local shortestDistance = range or math.huge
    
    -- Gunakan GetAllMobsInRange yang sudah dioptimasi
    local mobs = getAllMobsInRange(range)
    
    for _, mob in ipairs(mobs) do
        local mobRoot = mobCache[mob] and mobCache[mob].root
        if mobRoot then
            local distance = (humanoidRootPart.Position - mobRoot.Position).Magnitude
            if distance < shortestDistance then
                shortestDistance = distance
                nearestMob = mob
            end
        end
    end
    
    return nearestMob, shortestDistance
end

-- Fungsi Kill Aura yang dioptimasi
local killCounter = 0
local function killAura()
    if not getgenv().KillAura then return end
    
    killCounter = killCounter + 1
    -- Proses kill hanya setiap 3 frame untuk mengurangi beban
    if killCounter % 3 ~= 0 then return end
    
    local range = getgenv().KillAuraRange or 30
    local mobs = getAllMobsInRange(range)
    
    for _, mob in ipairs(mobs) do
        -- Skip player jika TargetMobsOnly true
        if getgenv().TargetMobsOnly and players:GetPlayerFromCharacter(mob) then
            continue
        end
        
        local data = mobCache[mob]
        if data and data.humanoid and data.humanoid.Health > 0 then
            data.humanoid.Health = 0
        end
    end
end

-- Fungsi Teleport ke mob terdekat
local function teleportToNearestMob()
    local mob = getNearestMob(getgenv().TeleportRange or 50)
    if mob and mobCache[mob] then
        local mobRoot = mobCache[mob].root
        humanoidRootPart.CFrame = mobRoot.CFrame + Vector3.new(0, 5, 0)
        print("✅ Teleport ke:", mob.Name)
    else
        print("❌ Tidak ada mob di sekitar")
    end
end

-- Keybind system
userInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == Enum.KeyCode[getgenv().KeyBindToggle or "F"] then
        getgenv().AutoFarm = not getgenv().AutoFarm
        print("🚀 AutoFarm:", getgenv().AutoFarm and "ON" or "OFF")
    end
    
    if input.KeyCode == Enum.KeyCode[getgenv().TeleportKey or "T"] then
        teleportToNearestMob()
    end
    
    if input.KeyCode == Enum.KeyCode.K then  -- Manual kill sekali
        killAura()
        print("⚔️ Manual kill executed")
    end
end)

-- Loop utama auto farm yang lebih efisien
runService.Heartbeat:Connect(function()
    if getgenv().AutoFarm and getgenv().KillAura then
        killAura()
    end
end)

print("=================================")
print("✅ RPG Grinder - VERSI RINGAN Loaded!")
print("=================================")
print("Tekan", getgenv().KeyBindToggle or "F", "= Toggle Auto Farm")
print("Tekan", getgenv().TeleportKey or "T", "= Teleport ke Mob")
print("Tekan K = Kill Manual")
print("=================================")
