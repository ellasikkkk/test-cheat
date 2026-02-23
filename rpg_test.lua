-- Script Utama RPG Grinder - FLOATING MODE
-- Dengan anti-lag saat tidak ada mob

local player = game.Players.LocalPlayer
local userInputService = game:GetService("UserInputService")
local runService = game:GetService("RunService")
local players = game:GetService("Players")

-- VARIABEL GLOBAL
local floatingActive = false
local currentTarget = nil
local floatDistance = 5  -- Jarak di belakang mob
local character = nil
local humanoidRootPart = nil

-- VARIABEL ANTI-LAG
local searchCooldown = 0  -- Cooldown pencarian
local noMobCount = 0      -- Counter tidak ada mob
local lastSearchTime = 0  -- Waktu pencarian terakhir
local SEARCH_DELAY = 2     -- Delay pencarian (detik)
local MAX_NO_MOB_COUNT = 5 -- Maksimal counter sebelum cooldown panjang

-- FUNGSI: Update referensi karakter
local function updateCharacter()
    character = player.Character
    if character then
        humanoidRootPart = character:WaitForChild("HumanoidRootPart")
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

-- FUNGSI: Mendapatkan mob terdekat (dengan caching)
local function getNearestMob(range)
    local nearestMob = nil
    local shortestDistance = range or math.huge
    local mobsFound = 0
    
    -- Batasi pencarian hanya di sekitar player (radius range*2)
    local playerPos = humanoidRootPart.Position
    local searchRadius = (range or 50) * 2
    
    for _, obj in pairs(workspace:GetChildren()) do  -- Gunakan GetChildren() dulu
        if obj:IsA("Model") and obj:FindFirstChild("Humanoid") and not players:GetPlayerFromCharacter(obj) then
            local mobRoot = obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChild("Torso")
            if mobRoot then
                -- Cek jarak kasar dulu
                local distance = (playerPos - mobRoot.Position).Magnitude
                if distance <= searchRadius then  -- Hanya proses yang dalam radius
                    mobsFound = mobsFound + 1
                    local humanoid = obj:FindFirstChild("Humanoid")
                    if humanoid and humanoid.Health > 0 then
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
    end
    
    return nearestMob, shortestDistance, mobsFound
end

-- FUNGSI: Teleport ke BELAKANG mob
local function floatBehindMob(mob)
    if not mob or not mob.rootPart then return end
    
    local mobPosition = mob.rootPart.Position
    local mobDirection = mob.rootPart.CFrame.LookVector
    local behindPosition = mobPosition - (mobDirection * floatDistance)
    behindPosition = behindPosition + Vector3.new(0, 2, 0)
    local lookAtMob = CFrame.lookAt(behindPosition, mobPosition)
    humanoidRootPart.CFrame = lookAtMob
end

-- FUNGSI: Cek apakah mob masih hidup
local function isMobAlive(mob)
    if not mob then return false end
    if not mob.model or not mob.model.Parent then return false end
    if not mob.humanoid or mob.humanoid.Health <= 0 then return false end
    if not mob.rootPart or not mob.rootPart.Parent then return false end
    return true
end

-- FUNGSI: Cari target baru (dengan anti-lag)
local function findNewTarget()
    if not humanoidRootPart then 
        return 
    end
    
    -- CEK COOLDOWN
    local currentTime = tick()
    if currentTime - lastSearchTime < searchCooldown then
        return  -- Masih dalam cooldown, skip pencarian
    end
    
    print("🔍 Mencari target baru...")
    local mob, _, mobsFound = getNearestMob(getgenv().TeleportRange or 50)
    
    if mob then
        -- Reset counter karena ada mob
        noMobCount = 0
        searchCooldown = 0.5  -- Cooldown normal (0.5 detik)
        currentTarget = mob
        floatBehindMob(currentTarget)
        print("✅ Target baru:", currentTarget.model.Name, 
              "| HP:", math.floor(currentTarget.humanoid.Health))
    else
        -- Tidak ada mob ditemukan
        noMobCount = noMobCount + 1
        
        -- Atur cooldown berdasarkan seberapa sering tidak ada mob
        if noMobCount >= MAX_NO_MOB_COUNT then
            searchCooldown = 5  -- Cooldown panjang (5 detik)
            if noMobCount == MAX_NO_MOB_COUNT then
                print("⚠️ Tidak ada mob dalam waktu lama")
                print("⏱️ Mode hemat energi: Cari setiap 5 detik")
            end
        else
            searchCooldown = 1  -- Cooldown sedang (1 detik)
        end
        
        print("❌ Tidak ada mob di sekitar (", noMobCount, "x )")
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
    
    if floatingActive then
        print("🚀 Floating mode masih aktif, mencari target...")
        wait(1)
        -- Reset counter dan cari target
        noMobCount = 0
        searchCooldown = 0.5
        findNewTarget()
    end
end)

-- KEYBIND SYSTEM
userInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    -- Tombol F: Toggle Floating Mode
    if input.KeyCode == Enum.KeyCode[getgenv().KeyBindToggle or "F"] then
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
            print("⚡ Anti-lag saat tidak ada mob")
            -- Reset counter saat aktivasi
            noMobCount = 0
            searchCooldown = 0.5
            findNewTarget()
        else
            print("=================================")
            print("💤 FLOATING MODE: DIMATIKAN")
            print("=================================")
            resetPosition()
            currentTarget = nil
        end
    end
    
    -- Tombol H: Cari target baru manual
    if input.KeyCode == Enum.KeyCode[getgenv().TeleportKey or "H"] then
        if not character or not humanoidRootPart then
            print("❌ Karakter tidak ada")
            return
        end
        
        if floatingActive then
            print("🔄 Mencari target baru secara manual...")
            -- Reset cooldown untuk pencarian manual
            lastSearchTime = 0
            findNewTarget()
        end
    end
    
    -- Tombol R: Turun ke tanah
    if input.KeyCode == Enum.KeyCode.R then
        if floatingActive then
            floatingActive = false
            resetPosition()
            currentTarget = nil
            print("⬇️ Mode floating dimatikan")
        end
    end
    
    -- Tombol +/-: Atur jarak
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
    
    -- Tombol P: Status
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
        print("No Mob Counter:", noMobCount)
        print("Search Cooldown:", searchCooldown, "detik")
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
    
    -- Jika tidak ada target, cari dengan cooldown
    if not currentTarget then
        findNewTarget()  -- Sudah ada cooldown di dalam fungsi
        return
    end
    
    -- CEK APAKAH MOB MASIH HIDUP
    if not isMobAlive(currentTarget) then
        print("💀 Target telah MATI! Mencari target baru...")
        currentTarget = nil
        -- Reset counter karena ada mob mati
        noMobCount = 0
        searchCooldown = 0.5
        return  -- Langsung return, nanti di loop berikutnya cari target
    end
    
    -- Tetap di belakang mob
    floatBehindMob(currentTarget)
    
    wait(0.1)  -- Delay kecil agar tidak terlalu berat
end)

-- Inisialisasi awal
updateCharacter()

print("=================================")
print("✅ RPG Grinder - FLOATING MODE")
print("=================================")
print("🎯 POSISI: DI BELAKANG MOB")
print("🔄 FITUR: Auto-respawn detection")
print("⚡ ANTI-LAG: Cooldown pencarian")
print("=================================")
print("Tombol:")
print("F = ON/OFF Floating Mode")
print("H = Cari target baru")
print("R = Matikan mode")
print("+ / - = Atur jarak belakang")
print("P = Tampilkan status")
print("=================================")
print("📢 Cara kerja ANTI-LAG:")
print("1. Ada mob → cari setiap 0.5 detik")
print("2. 5x tidak ada mob → cari setiap 5 detik")
print("3. Manual search (H) reset cooldown")
print("=================================")
