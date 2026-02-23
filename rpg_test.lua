-- Script Utama RPG Grinder - FLOATING MODE
-- Dengan deteksi respawn dan posisi di belakang mob

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


if noMobCount >= MAX_NO_MOB_COUNT then
    searchCooldown = 5  -- Cooldown panjang
    print("⚠️ Mode hemat energi")
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
    local nearestMob = nil
    local shortestDistance = range or math.huge
    
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and obj:FindFirstChild("Humanoid") and not players:GetPlayerFromCharacter(obj) then
            local mobRoot = obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChild("Torso")
            if mobRoot then
                local humanoid = obj:FindFirstChild("Humanoid")
                if humanoid and humanoid.Health > 0 then
                    local distance = (humanoidRootPart.Position - mobRoot.Position).Magnitude
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
    return nearestMob, shortestDistance
end

-- FUNGSI: Teleport ke BELAKANG mob
local function floatBehindMob(mob)
    if not mob or not mob.rootPart then return end
    
    -- Hitung posisi di belakang mob
    -- Menggunakan lookVector untuk menentukan arah hadap mob
    local mobPosition = mob.rootPart.Position
    local mobDirection = mob.rootPart.CFrame.LookVector  -- Arah hadap mob
    
    -- Posisi di belakang mob (berlawanan dengan arah hadap)
    local behindPosition = mobPosition - (mobDirection * floatDistance)
    
    -- Tambahkan sedikit ketinggian agar tidak masuk tanah
    behindPosition = behindPosition + Vector3.new(0, 2, 0)
    
    -- Buat CFrame menghadap ke mob
    local lookAtMob = CFrame.lookAt(behindPosition, mobPosition)
    
    -- Terapkan CFrame
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
    
    print("🔍 Mencari target baru...")
    local mob = getNearestMob(getgenv().TeleportRange or 50)
    
    if mob then
        currentTarget = mob
        floatBehindMob(currentTarget)
        print("✅ Target baru:", currentTarget.model.Name, 
              "| HP:", math.floor(currentTarget.humanoid.Health))
    else
        print("❌ Tidak ada mob di sekitar")
        currentTarget = nil
    end
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
    
    -- Jika floating mode aktif, cari target baru
    if floatingActive then
        print("🚀 Floating mode masih aktif, mencari target...")
        wait(1)  -- Beri waktu karakter stabil
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
    if input.KeyCode == Enum.KeyCode.Equals then  -- Tombol +
        floatDistance = math.min(floatDistance + 1, 15)
        print("📏 Jarak belakang:", floatDistance, "studs")
        if floatingActive and currentTarget then
            floatBehindMob(currentTarget)
        end
    end
    
    if input.KeyCode == Enum.KeyCode.Minus then  -- Tombol -
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
        print("=================================")
    end
end)

-- LOOP UTAMA
runService.Heartbeat:Connect(function()
    -- Pastikan karakter ada
    if not character or not humanoidRootPart then
        if player.Character then
            updateCharacter()
        end
        return
    end
    
    if not floatingActive then return end
    
    -- Jika tidak ada target, cari target baru
    if not currentTarget then
        findNewTarget()
        return
    end
    
    -- CEK APAKAH MOB MASIH HIDUP
    if not isMobAlive(currentTarget) then
        print("💀 Target telah MATI! Mencari target baru...")
        currentTarget = nil
        findNewTarget()
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
print("=================================")
print("🎯 POSISI: DI BELAKANG MOB")
print("🔄 FITUR: Auto-respawn detection")
print("=================================")
print("Tombol:")
print("F = ON/OFF Floating Mode")
print("H = Cari target baru")
print("R = Matikan mode")
print("+ / - = Atur jarak belakang")
print("P = Tampilkan status")
print("=================================")
print("📢 Cara kerja:")
print("1. Karakter di belakang mob (menghadap mob)")
print("2. Jika mati, auto respawn dan lanjut")
print("3. Pindah target hanya saat mob MATI")
print("4. Atur jarak dengan +/-")
print("=================================")

