local VirtualUser = game:GetService("VirtualUser")
local Players = game:GetService("Players")

local player = Players.LocalPlayer

print("===================================")
print("🟢 ANTI-AFK AKTIF")
print("===================================")

player.Idled:Connect(function()
    print("⏳ Idle terdeteksi, mengirim input virtual...")
    
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
    
    print("✅ Input terkirim, status tetap aktif.")
end)
