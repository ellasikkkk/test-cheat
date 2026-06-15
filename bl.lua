-- ==========================================
-- MOB PATH SCANNER & FOLDER DETECTOR
-- ==========================================
local workspace = game:GetService("Workspace")

-- Daftar kata kunci yang ingin dicari (nama mob atau nama folder umum)
local keywords = {"Pufflare", "Illusiver", "Phant", "Orbitfin", "Pico", "Mob", "Monster", "Enemy", "NPC"}
local foundLocations = {}

print("🔍 Memulai proses pemindaian struktur game...")
print("==========================================")

-- Memindai seluruh objek di Workspace
for _, object in ipairs(workspace:GetDescendants()) do
    local objNameLower = string.lower(object.Name)
    
    for _, keyword in ipairs(keywords) do
        local keywordLower = string.lower(keyword)
        
        -- Jika menemukan objek yang cocok dengan kata kunci
        if string.find(objNameLower, keywordLower) then
            -- Dapatkan lokasi foldernya (Parent)
            if object.Parent then
                local parentPath = object.Parent:GetFullName()
                
                -- Hitung jumlah mob/objek di dalam folder tersebut
                if not foundLocations[parentPath] then
                    foundLocations[parentPath] = 1
                else
                    foundLocations[parentPath] = foundLocations[parentPath] + 1
                end
            end
            break -- Lanjut ke objek berikutnya agar tidak double-count
        end
    end
end

-- Menampilkan hasil ke Konsol (Tekan F9 di game)
print("✅ PEMINDAIAN SELESAI! Hasil Penemuan Folder:")
print("------------------------------------------")

local foundSomething = false
for path, count in pairs(foundLocations) do
    -- Filter sedikit agar tidak menampilkan folder utama workspace secara langsung jika memungkinkan
    if path ~= "Workspace" then
        print("📁 LOKASI: " .. path .. " | 👾 Ditemukan: " .. count .. " objek terkait")
        foundSomething = true
    end
end

if not foundSomething then
    print("❌ Tidak menemukan folder spesifik. Mob mungkin diletakkan langsung di Workspace tanpa folder.")
end
print("==========================================")
print("💡 Buka console (Tekan F9) untuk melihat log ini dengan jelas.")
