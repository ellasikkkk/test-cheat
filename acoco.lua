print("===================================")
print("🔍 MEMULAI RADAR PENCARI MOB...")
print("===================================")

-- Ganti dengan nama monster yang SEDANG ADA di layar kamu sekarang
local namaMonsterDiLayar = "Violet Yukibun" 

local ketemu = false

for _, objek in ipairs(workspace:GetDescendants()) do
    if objek:IsA("TextLabel") or objek:IsA("TextButton") then
        if objek.Text and string.find(string.lower(objek.Text), string.lower(namaMonsterDiLayar)) then
            print("🎯 BINGO! Monster ditemukan!")
            print("📂 PATH LENGKAP: " .. objek:GetFullName())
            ketemu = true
            break
        end
    end
end

if not ketemu then
    print("❌ Script tidak bisa menemukan UI teks monster tersebut di Workspace.")
end
print("===================================")
