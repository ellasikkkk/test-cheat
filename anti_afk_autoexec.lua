-- Prevent double load
if getgenv().ANTI_AFK_LOADED then
    warn("Anti-AFK already loaded!")
    return
end
getgenv().ANTI_AFK_LOADED = true

-- Config
getgenv().AntiAFKEnabled = true
getgenv().AntiAFKInterval = 60 -- seconds
getgenv().AntiAFKDebug = false

-- Optional: set this if you host a raw script for loading on teleport
-- Example: getgenv().AntiAFKRemoteURL = "https://raw.githubusercontent.com/user/repo/main/anti_afk_autoexec.lua"
getgenv().AntiAFKRemoteURL = getgenv().AntiAFKRemoteURL

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local VirtualUser = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    warn("Anti-AFK: LocalPlayer not found")
    return
end

local idleConnection
local teleportQueued = false

local function log(...)
    if getgenv().AntiAFKDebug then
        print("[AntiAFK]", ...)
    end
end

local function onIdle()
    if not getgenv().AntiAFKEnabled then
        return
    end

    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end)

    log("Idle detected, anti-AFK input sent")
end

local function startAntiAFK()
    if idleConnection and idleConnection.Connected then
        idleConnection:Disconnect()
    end

    idleConnection = LocalPlayer.Idled:Connect(onIdle)
    log("Anti-AFK active")
end

local function queueOnTeleport()
    if teleportQueued then
        return
    end
    teleportQueued = true

    local remoteURL = getgenv().AntiAFKRemoteURL
    local queuedSource

    if type(remoteURL) == "string" and remoteURL ~= "" then
        queuedSource = ([[
            pcall(function()
                loadstring(game:HttpGet(%q))()
            end)
        ]]):format(remoteURL)
    else
        -- Fallback: queue current local source code (works in executors that support readfile)
        queuedSource = [[
            pcall(function()
                local src = readfile("anti_afk_autoexec.lua")
                if src and src ~= "" then
                    loadstring(src)()
                end
            end)
        ]]
    end

    local queued = false

    if queue_on_teleport then
        pcall(function()
            queue_on_teleport(queuedSource)
            queued = true
        end)
    end

    if not queued and syn and syn.queue_on_teleport then
        pcall(function()
            syn.queue_on_teleport(queuedSource)
            queued = true
        end)
    end

    if not queued and fluxus and fluxus.queue_on_teleport then
        pcall(function()
            fluxus.queue_on_teleport(queuedSource)
            queued = true
        end)
    end

    if queued then
        log("Queued anti-AFK for next teleport/map change")
    else
        warn("Anti-AFK: queue_on_teleport is not supported by this executor")
    end
end

startAntiAFK()
queueOnTeleport()

-- Extra heartbeat pulse for some games/executors
task.spawn(function()
    while getgenv().ANTI_AFK_LOADED do
        if getgenv().AntiAFKEnabled then
            pcall(function()
                VirtualUser:CaptureController()
            end)
        end
        task.wait(getgenv().AntiAFKInterval)
    end
end)

-- Auto reattach when character respawns
LocalPlayer.CharacterAdded:Connect(function()
    if getgenv().ANTI_AFK_LOADED then
        task.wait(1)
        startAntiAFK()
    end
end)

-- Re-queue each time teleport starts
TeleportService.TeleportInitFailed:Connect(function()
    teleportQueued = false
    queueOnTeleport()
end)

-- Optional helper to stop anti afk manually in executor
getgenv().StopAntiAFK = function()
    getgenv().ANTI_AFK_LOADED = false
    getgenv().AntiAFKEnabled = false

    if idleConnection and idleConnection.Connected then
        idleConnection:Disconnect()
    end

    warn("Anti-AFK stopped")
end

warn("Anti-AFK auto execute loaded (teleport/map auto-queue enabled)")
