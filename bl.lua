-- Script Utama RPG Grinder - GUI V7 FINAL (Hybrid Performance & Features)
local player = game.Players.LocalPlayer
local runService = game:GetService("RunService")
local virtualUser = game:GetService("VirtualUser")
local tweenService = game:GetService("TweenService")

-- ==========================================
-- SETUP GUI & VARIABEL
-- ==========================================
local ScreenGui = Instance.new("ScreenGui", game:GetService("CoreGui"))
local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Size = UDim2.new(0, 200, 0, 300); MainFrame.Position = UDim2.new(0.1, 0, 0.2, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35); MainFrame.Active = true; MainFrame.Draggable = true

local Title = Instance.new("TextLabel", MainFrame)
Title.Size = UDim2.new(1, 0, 0, 40); Title.Text = "RPG GRINDER V7"; Title.TextColor3 = Color3.new(1,1,1)

local MobListFrame = Instance.new("ScrollingFrame", MainFrame)
MobListFrame.Size = UDim2.new(0.9, 0, 0.6, 0); MobListFrame.Position = UDim2.new(0.05, 0, 0.15, 0)
Instance.new("UIListLayout", MobListFrame)

local ToggleBtn = Instance.new("TextButton", MainFrame)
ToggleBtn.Size = UDim2.new(0.9, 0, 0, 40); ToggleBtn.Position = UDim2.new(0.05, 0, 0.8, 0)
ToggleBtn.Text = "START FARM: OFF"; ToggleBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)

local autoFarmActive = false
local targetSettings = {
    {name = "Illusiver", active = false}, {name = "Pufflare", active = false},
    {name = "Phant", active = false}, {name = "Orbitfin", active = false}, {name = "Pico", active = false}
}

-- Create Buttons
for _, mob in ipairs(targetSettings) do
    local btn = Instance.new("TextButton", MobListFrame)
    btn.Size = UDim2.new(1, -10, 0, 30); btn.Text = mob.name
    btn.MouseButton1Click:Connect(function()
        mob.active = not mob.active
        btn.BackgroundColor3 = mob.active and Color3.fromRGB(0, 150, 255) or Color3.fromRGB(50, 50, 55)
    end)
end

-- ==========================================
-- LOGIKA SCAN & FARM (PERFORMA TINGGI)
-- ==========================================
local function getNearestTarget(targetName)
    local nearest, shortest = nil, math.huge
    local live = workspace:FindFirstChild("Live")
    if not live or not live:FindFirstChild("Mobs") then return nil end
    
    for _, obj in ipairs(live.Mobs.Client:GetChildren()) do
        -- Scan nama target via GUI text (Bypass UUID)
        local found = false
        for _, desc in ipairs(obj:GetDescendants()) do
            if (desc:IsA("TextLabel") or desc:IsA("TextButton")) and string.find(string.lower(desc.Text), string.lower(targetName)) then
                found = true; break
            end
        end
        
        if found then
            local root = obj:FindFirstChild("HumanoidRootPart")
            if root then
                local dist = (player.Character.HumanoidRootPart.Position - root.Position).Magnitude
                if dist < shortest then shortest = dist; nearest = root end
            end
        end
    end
    return nearest
end

-- ==========================================
-- LOOP UTAMA
-- ==========================================
ToggleBtn.MouseButton1Click:Connect(function()
    autoFarmActive = not autoFarmActive
    ToggleBtn.Text = autoFarmActive and "START FARM: ON" or "START FARM: OFF"
    ToggleBtn.BackgroundColor3 = autoFarmActive and Color3.fromRGB(40, 180, 40) or Color3.fromRGB(180, 40, 40)
    
    spawn(function()
        while autoFarmActive do
            local activeMobs = {}
            for _, m in ipairs(targetSettings) do if m.active then table.insert(activeMobs, m.name) end end
            
            for _, mobName in ipairs(activeMobs) do
                if not autoFarmActive then break end
                local target = getNearestTarget(mobName)
                
                if target then
                    -- Pergerakan Smooth (Tween)
                    local tween = tweenService:Create(player.Character.HumanoidRootPart, 
                        TweenInfo.new(0.5), {CFrame = target.CFrame * CFrame.new(0, 3, 0)})
                    tween:Play(); tween.Completed:Wait()
                    
                    -- Auto Attack (Fungsi yang kamu inginkan)
                    local tool = player.Character:FindFirstChildOfClass("Tool") or player.Backpack:FindFirstChildOfClass("Tool")
                    if tool then player.Character.Humanoid:EquipTool(tool); tool:Activate() end
                end
                wait(0.2)
            end
            wait(0.1)
        end
    end)
end)

-- Anti AFK
player.Idled:Connect(function() virtualUser:ClickButton2(Vector2.new()) end)
