-- Script Utama RPG Grinder - FLOATING MODE
-- Karakter mengambang di atas mob dan hanya pindah saat mob mati

local player = game.Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
local userInputService = game:GetService("UserInputService")
local runService = game:GetService("RunService")
local players = game:GetService("Players")

-- VARIABEL FLOATING
local floatingActive = false
local currentTarget = nil
local floatHeight = 8  -- Tinggi mengambang
local isSearching = false  -- Flag untuk mencari target

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
                            lastHealth = humanoid.Health  -- Simpan health awal
                        }
                    end
                end
            end
        end
    end
    return nearestMob, shortestDistance
end

-- FUNGSI: Terbang ke atas mob
local function floatAboveMob(mob)
    if not mob or not mob.rootPart then return end
    
    local targetPos = mob.rootPart.Position + Vector3.new(0, floatHeight, 0)
    local lookDownCFrame = CFrame.new(targetPos) * CFrame.Angles(math.rad(-90), 0, 0)
    humanoidRootPart.CFrame = lookDownCFrame
end

-- FUNGSI: Cek apakah mob masih hidup
local function isMobAlive(mob)
    if not mob then return false end
    if not mob.model or not mob.model.Parent then return false end
    if not mob.humanoid or mob.humanoid.Health <= 0 then return false end
    if not mob.rootPart or not mob.rootPart.Parent then return false end
    return true
end

-- FUNGSI: Cari target baru (hanya saat dibutuhkan)
local function findNewTarget()
    if isSearching then return end  -- Hindari pencarian ganda
    
    isSearching = true
    print("🔍 Mencari target baru...")
    
    local mob = getNearestMob(getgenv().TeleportRange or 50)
    
    if mob then
        currentTarget = mob
        floatAboveMob(currentTarget)
        print("✅ Target baru:", currentTarget.model.Name, 
              "| HP:", math.floor(currentTarget.humanoid.Health))
    else
        print("❌ Tidak ada mob di sekitar")
        currentTarget = nil
    end
    
    isSearching = false
end

-- FUNGSI: Reset rotasi
local function resetRotation()
    local currentPos = humanoidRootPart.Position
    humanoidRootPart.CFrame = CFrame.new(currentPos)
end

-- KEYBIND SYSTEM
userInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    -- Tombol F: Toggle Floating Mode
    if input.KeyCode == Enum.KeyCode[getgenv().KeyBindToggle or "F"] then
        floatingActive = not floatingActive
        
        if floatingActive then
            print("=================================")
            print("🚀 FLOATING MODE: AKTIF")
            print("=================================")
            print("📍 Karakter akan mengambang di atas mob")
            print("💀 Hanya pindah target saat mob MATI")
            findNewTarget()
        else
            print("=================================")
            print("💤 FLOATING MODE: DIMATIKAN")
            print("=================================")
            resetRotation()
            currentTarget = nil
        end
    end
    
    -- Tombol H: Cari target baru manual
    if input.KeyCode == Enum.KeyCode[getgenv().TeleportKey or "H"] then
        if floatingActive then
            print("🔄 Mencari target baru secara manual...")
            findNewTarget()
        end
    end
    
    -- Tombol R: Turun ke tanah
    if input.KeyCode == Enum.KeyCode.R then
        if floatingActive then
            floatingActive = false
            resetRotation()
            currentTarget = nil
            print("⬇️ Turun ke tanah")
        end
    end
    
    -- Tombol P: Status
    if input.KeyCode == Enum.KeyCode.P then
        print("=================================")
        print("📊 STATUS FLOATING MODE")
        print("=================================")
        print("Mode Aktif:", floatingActive and "✅ ON" or "❌ OFF")
        if floatingActive and currentTarget then
            print("Target:", currentTarget.model.Name)
            print("HP Target:", math.floor(currentTarget.humanoid.Health))
            print("Status: ", currentTarget.humanoid.Health > 0 and "Hidup" or "Mati")
        end
        print("=================================")
    end
end)

-- LOOP UTAMA - Menjaga posisi di atas mob
runService.Heartbeat:Connect(function()
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
        findNewTarget()  -- Cari target baru setelah mob mati
        return
    end
    
    -- Pantau health mob
    local currentHealth = currentTarget.humanoid.Health
    local healthChanged = currentHealth ~= currentTarget.lastHealth
    
    if healthChanged then
        print("📊 HP", currentTarget.model.Name, ":", 
              math.floor(currentHealth), "/", 
              math.floor(currentTarget.lastHealth))
        currentTarget.lastHealth = currentHealth
    end
    
    -- Tetap di atas mob (selama masih hidup)
    floatAboveMob(currentTarget)
    
    wait(0.1)
end)

print("=================================")
print("✅ RPG Grinder - FLOATING MODE")
print("=================================")
print("🎯 FITUR: Pindah target saat mob MATI")
print("   (Bukan saat darah berkurang)")
print("=================================")
print("Tombol:")
print("F = ON/OFF Floating Mode")
print("H = Cari target baru (manual)")
print("R = Turun ke tanah")
print("P = Tampilkan status")
print("=================================")
print("📢 Cara kerja:")
print("1. Karakter mengambang di atas mob")
print("2. Anda klik untuk menyerang")
print("3. Script akan tetap di mob yang sama")
print("4. Pindah hanya saat mob MATI (HP = 0)")
print("=================================")
