-- Script Utama RPG Grinder - FLOATING MODE
-- Dengan deteksi respawn dan posisi di belakang mob
-- DILENGKAPI ANTI-LAG SAAT TIDAK ADA MOB

local player = game.Players.LocalPlayer
local userInputService = game:GetService("UserInputService")
local runService = game:GetService("RunService")
local players = game:GetService("Players")

-- VARIABEL GLOBAL
local floatingActive = false
local currentTarget = nil
local floatDistance = 5  -- Jarak di belakang mob (bukan tinggi)
local character = nil
local humanoidRootPart = nil

-- === VARIABEL ANTI-LAG === --
local searchCooldown = 0        -- Cooldown pencarian (detik)
local noMobCount = 0            -- Counter tidak ada mob
local lastSearchTime = 0        -- Waktu pencarian terakhir
local SEARCH_DELAY_NORMAL = 0.5  -- Cari setiap 0.5 detik (ada mob)
local SEARCH_DELAY_LOW = 2       -- Cari setiap 2 detik (mulai kosong)
local SEARCH_DELAY_IDLE = 5      -- Cari setiap 5 detik (sangat kosong)
local MAX_NO_MOB_COUNT = 5       -- Batas sebelum cooldown panjang

-- FUNGSI: Update referensi karakter
local function updateCharacter()
    character = player.Character
    if character then
        humanoidRootPart = character:WaitForChild("HumanoidRootPart")
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

-- FUNGSI: Mendapatkan mob terdekat (VERSI RINGAN)
local function getNearestMob(range)
    local nearestMob = nil
    local shortestDistance = range or math.huge
    local playerPos = humanoidRootPart.Position
    local mobsFound = 0
    
    -- Batasi pencarian dengan Region3 untuk performa lebih baik
    local searchRange = (range or 50) * 1.5
    local region = Region3.new(
        playerPos - Vector3.new(searchRange, searchRange, searchRange),
        playerPos + Vector3.new(searchRange, searchRange, searchRange)
    )
    
    -- Gunakan FindPartsInRegion3 yang lebih cepat dari GetDescendants
    local parts = workspace:FindPartsInRegion3(region, nil, 100)
    
    for _, part in ipairs(parts) do
        local obj = part.Parent
        if obj and obj:IsA("Model") and obj:FindFirstChild("Humanoid") and not players:GetPlayerFromCharacter(obj) then
            local mobRoot = obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChild("Torso")
            if mobRoot then
                local humanoid = obj:FindFirstChild("Humanoid")
                if humanoid and humanoid.Health > 0 then
                    mobsFound = mobsFound + 1
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
    
    return nearestMob, shortestDistance, mobsFound
end

-- FUNGSI: Teleport ke BELAKANG mob
local function floatBehindMob(mob)
    if not mob or not mob.rootPart then return end
    
    -- Hitung posisi di belakang mob
    local mobPosition = mob.rootPart.Position
    local mobDirection = mob.rootPart.CFrame.LookVector
    local behindPosition = mobPosition - (mobDirection * floatDistance)
    behindPosition = behindPosition + Vector3.new(0, 2, 0)
    local lookAtMob = CFrame.lookAt(behindPosition, mobPosition)
    humanoidRootPart.CFrame = lookAtMob
    
    print("📍 Di belakang:", mob.model.Name, 
          "| HP:", math.floor(mob.humanoid.Health),
          "| Jarak:", floatDistance, "studs")
end

-- FUNGSI: Cek apakah mob masih hidup
local function isMobAlive(mob)
    if not mob then return false end
    if not mob.model or not mob.model.Parent then return false end
    if not mob.humanoid or mob.humanoid.Health <= 0 then return false end
    if not mob.rootPart or not mob.rootPart.Parent then return false end
    return true
end

-- FUNGSI: Cari target baru (DENGAN ANTI-LAG)
local function findNewTarget()
    if not humanoidRootPart then 
        print("❌ Karakter tidak ditemukan")
        return 
    end
    
    -- CEK COOLDOWN
    local currentTime = tick()
    if currentTime - lastSearchTime < searchCooldown then
        return  -- Masih dalam cooldown
    end
    
    print("🔍 Mencari target baru...")
    local mob, _, mobsFound = getNearestMob(getgenv().TeleportRange or 50)
    
    if mob then
        -- Reset counter dan cooldown karena ada mob
        noMobCount = 0
        searchCooldown = SEARCH_DELAY_NORMAL
        currentTarget = mob
        floatBehindMob(currentTarget)
        print("✅ Target baru:", currentTarget.model.Name, 
              "| HP:", math.floor(currentTarget.humanoid.Health))
    else
        -- Tidak ada mob, naikkan counter
        noMobCount = noMobCount + 1
        
        -- Atur cooldown berdasarkan frekuensi tidak ada mob
        if noMobCount >= MAX_NO_MOB_COUNT then
            searchCooldown = SEARCH_DELAY_IDLE
            if noMobCount == MAX_NO_MOB_COUNT then
                print("⚠️ Area kosong - Mode hemat energi (cari setiap 5 detik)")
            end
        else
            searchCooldown = SEARCH_DELAY_LOW
            print("❌ Tidak ada mob (", noMobCount, "/", MAX_NO_MOB_COUNT, ")")
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

-- DETEKSI RESPAWN KARAKTER
player.CharacterAdded:Connect(function(newCharacter)
    print("🔄 Karakter respawn terdeteksi!")
    character = newCharacter
    humanoidRootPart = character:WaitForChild("HumanoidRootPart")
    
    -- Reset anti-lag counter
    noMobCount = 0
    searchCooldown = SEARCH_DELAY_NORMAL
    
    -- Jika floating mode aktif, cari target baru
    if floatingActive then
        print("🚀 Floating mode masih aktif, mencari target...")
        wait(1)
        findNewTarget()
    end
end)

-- KEYBIND SYSTEM
userInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    -- Tombol F: Toggle Floating Mode
    if input.KeyCode == Enum.KeyCode[getgenv().KeyBindToggle or "F"] then
        -- Pastikan karakter ada
        if not character or not humanoidRootPart then
            waitForCharacter()
        end
        
        floatingActive = not floatingActive
        
        if floatingActive then
            print("=================================")
            print("🚀 FLOATING MODE: AKTIF")
            print("=================================")
            print("📍 Karakter di BELAKANG mob")
            print("💀 Hanya pindah target saat mob MATI")
            print("🔄 Auto-respawn terdeteksi")
            print("⚡ Anti-lag: Cooldown pencarian")
            -- Reset anti-lag
            noMobCount = 0
            searchCooldown = SEARCH_DELAY_NORMAL
            lastSearchTime = 0
            findNewTarget()
        else
            print("=================================")
            print("💤 FLOATING MODE: DIMATIKAN")
            print("=================================")
            resetPosition()
            currentTarget = nil
        end
    end
    
    -- Tombol H: Cari target baru manual (reset cooldown)
    if input.KeyCode == Enum.KeyCode[getgenv().TeleportKey or "H"] then
        if not character or not humanoidRootPart then
            print("❌ Karakter tidak ada")
            return
        end
        
        if floatingActive then
            print("🔄 Mencari target baru secara MANUAL...")
            -- Reset cooldown untuk pencarian manual
            lastSearchTime = 0
            noMobCount = 0
            findNewTarget()
        end
    end
    
    -- Tombol R: Turun ke tanah / reset
    if input.KeyCode == Enum.KeyCode.R then
        if floatingActive then
            floatingActive = false
            resetPosition()
            currentTarget = nil
            print("⬇️ Mode floating dimatikan")
        end
    end
    
    -- Tombol +/-: Atur jarak di belakang mob
    if input.KeyCode == Enum.KeyCode.Equals then
        floatDistance = math.min(floatDistance + 1, 15)
        print("📏 Jarak belakang:", floatDistance, "studs")
        if floatingActive and currentTarget then
            floatBehindMob(currentTarget)
        end
    end
    
    if input.KeyCode == Enum.KeyCode.Minus then
        floatDistance = math.max(floatDistance - 1, 2)
        print("📏 Jarak belakang:", floatDistance, "studs")
        if floatingActive and currentTarget then
            floatBehindMob(currentTarget)
        end
    end
    
    -- Tombol P: Status (dengan info anti-lag)
    if input.KeyCode == Enum.KeyCode.P then
        print("=================================")
        print("📊 STATUS FLOATING MODE")
        print("=================================")
        print("Mode Aktif:", floatingActive and "✅ ON" or "❌ OFF")
        print("Karakter:", character and "✅ Ada" or "❌ Tidak ada")
        if floatingActive and currentTarget then
            print("Target:", currentTarget.model.Name)
            print("HP Target:", math.floor(currentTarget.humanoid.Health))
            print("Posisi: Di BELAKANG mob")
            print("Jarak:", floatDistance, "studs")
        end
        print("---------------------------------")
        print("📈 ANTI-LAG STATUS:")
        print("No Mob Counter:", noMobCount, "/", MAX_NO_MOB_COUNT)
        print("Search Cooldown:", searchCooldown, "detik")
        if noMobCount >= MAX_NO_MOB_COUNT then
            print("⚡ Mode: Hemat Energi (cari 5 detik)")
        elseif noMobCount > 0 then
            print("⚡ Mode: Cooldown Sedang (cari 2 detik)")
        else
            print("⚡ Mode: Normal (cari 0.5 detik)")
        end
        print("=================================")
    end
end)

-- LOOP UTAMA (DENGAN ANTI-LAG)
runService.Heartbeat:Connect(function()
    -- Pastikan karakter ada
    if not character or not humanoidRootPart then
        if player.Character then
            updateCharacter()
        end
        return
    end
    
    if not floatingActive then return end
    
    -- Jika tidak ada target, cari dengan sistem cooldown
    if not currentTarget then
        findNewTarget()  -- Sudah ada cooldown di dalam
        return
    end
    
    -- CEK APAKAH MOB MASIH HIDUP
    if not isMobAlive(currentTarget) then
        print("💀 Target telah MATI! Mencari target baru...")
        currentTarget = nil
        -- Reset counter karena ada mob mati
        noMobCount = 0
        searchCooldown = SEARCH_DELAY_NORMAL
        return
    end
    
    -- Tetap di belakang mob
    floatBehindMob(currentTarget)
    
    wait(0.1)
end)

-- Inisialisasi awal
updateCharacter()

print("=================================")
print("✅ RPG Grinder - FLOATING MODE")
print("    + ANTI-LAG SYSTEM")
print("=================================")
print("🎯 POSISI: DI BELAKANG MOB")
print("🔄 FITUR: Auto-respawn detection")
print("⚡ ANTI-LAG: Cooldown bertingkat")
print("=================================")
print("Tombol:")
print("F = ON/OFF Floating Mode")
print("H = Cari target baru (reset cooldown)")
print("R = Matikan mode")
print("+ / - = Atur jarak belakang")
print("P = Tampilkan status + info anti-lag")
print("=================================")
print("📢 SISTEM ANTI-LAG:")
print("• Ada mob → Cari setiap 0.5 detik")
print("• 1-5x tidak ada mob → Cari setiap 2 detik")
print("• >5x tidak ada mob → Cari setiap 5 detik")
print("• Tekan H untuk reset counter")
print("=================================")
