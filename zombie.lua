print("==========================================")
print("🛠️ MEMBONGKAR SISTEM CONTROLLER GAME...")
print("==========================================")

-- Daftar modul yang ingin kita intip
local targetModules = {"AutoAttackController", "EntityController"}

-- Tempat developer biasanya menyimpan ModuleScript Controller
local searchAreas = {
    game:GetService("ReplicatedStorage"),
    game.Players.LocalPlayer:WaitForChild("PlayerScripts")
}

for _, moduleName in ipairs(targetModules) do
    local foundModule = nil
    
    -- Mencari modul di area yang ditentukan
    for _, area in ipairs(searchAreas) do
        for _, obj in ipairs(area:GetDescendants()) do
            if obj:IsA("ModuleScript") and obj.Name == moduleName then
                foundModule = obj
                break
            end
        end
        if foundModule then break end
    end
    
    if foundModule then
        print("✅ Ditemukan: " .. moduleName .. " di " .. foundModule:GetFullName())
        
        -- Mencoba Require (mengakses isi modul)
        local success, result = pcall(function()
            return require(foundModule)
        end)
        
        if success and type(result) == "table" then
            print("📂 Isi dari " .. moduleName .. ":")
            for key, value in pairs(result) do
                print("   -> " .. tostring(key) .. " [" .. type(value) .. "]")
            end
        else
            warn("⚠️ Gagal mengakses (Require) " .. moduleName .. ". Mungkin dilindungi.")
        end
    else
        print("❌ Tidak menemukan " .. moduleName)
    end
    print("------------------------------------------")
end
print("==========================================")
