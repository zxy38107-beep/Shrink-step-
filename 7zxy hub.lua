--[[
    7zxy Hub - 1+ Shrink Per Step
    Rewrote UI and updated to version V2.3
    ═══════════════════════════════════════════════════════
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local TeleportService = game:GetService("TeleportService")
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer

-- ═══════════════════════════════════════════════════════
-- LOAD WINDUI
-- ═══════════════════════════════════════════════════════
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

-- ═══════════════════════════════════════════════════════
-- EXECUTOR DETECTION
-- ═══════════════════════════════════════════════════════
local function getExecutorName()
    if identifyexecutor then
        local success, name = pcall(identifyexecutor)
        if success and name and name ~= "" then return name end
    end
    if getexecutorname then
        local success, name = pcall(getexecutorname)
        if success and name and name ~= "" then return name end
    end
    if syn and syn.crypt and syn.crypt.custom then return "Synapse" end
    if krnl then return "Krnl" end
    if fluxus then return "Fluxus" end
    if electron then return "Electron" end
    if is_sirhurt_closure then return "SirHurt" end
    if getgenv and getgenv().IS_SCRIPT_WARE then return "ScriptWare" end
    if getgenv and getgenv().IS_VEGA_X then return "Vega X" end
    if getgenv and getgenv().IS_DELTA then return "Delta" end
    if getgenv and getgenv().IS_CODE_X then return "Code X" end
    return "Unknown"
end

local executorName = getExecutorName()

task.wait(1)
WindUI:Notify({
    Title = "Executor Detected",
    Content = "Using: " .. executorName,
    Duration = 5,
    Icon = "terminal"
})

-- ═══════════════════════════════════════════════════════
-- HWID & UTILITIES
-- ═══════════════════════════════════════════════════════
local function copyToClipboard(text)
    if setclipboard then setclipboard(text)
    elseif syn and syn.write_clipboard then syn.write_clipboard(text)
    elseif toclipboard then toclipboard(text)
    else
        pcall(function()
            local input = Instance.new("TextBox")
            input.Text = text
            input.Parent = game:GetService("CoreGui")
            input:CaptureFocus()
            input:SelectAll()
            task.wait(0.1)
            input.Parent = nil
        end)
    end
end

local function getHWID()
    local success, id = pcall(function()
        return game:GetService("RbxAnalyticsService"):GetClientId()
    end)
    if success and id and id ~= "" then return id end
    success, id = pcall(function()
        return HttpService:GenerateGUID(false)
    end)
    if success and id then return id end
    return "Unknown"
end

local hwid = getHWID()

local function getPing()
    local success, stat = pcall(function()
        return game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()
    end)
    if success and type(stat) == "number" and stat > 0 then return math.floor(stat) end
    return 0
end

local function httpGet(url)
    if syn and syn.request then
        local res = syn.request({ Url = url, Method = "GET" })
        if res and res.Body then return res.Body end
    elseif request then
        local res = request({ Url = url, Method = "GET" })
        if res and res.Body then return res.Body end
    elseif http_request then
        local res = http_request({ Url = url, Method = "GET" })
        if res and res.Body then return res.Body end
    end
    return nil
end

-- ═══════════════════════════════════════════════════════
-- LOADING SCREEN (7zxy Hub Loading)
-- ═══════════════════════════════════════════════════════
local function showLoadingScreen()
    local blur = Instance.new("BlurEffect", Lighting)
    blur.Size = 0
    TweenService:Create(blur, TweenInfo.new(0.6), { Size = 18 }):Play()
    
    local screenGui = Instance.new("ScreenGui")
    screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    screenGui.Name = "ZyroYonkIntro"
    screenGui.ResetOnSpawn = false
    screenGui.IgnoreGuiInset = true
    
    local frame = Instance.new("Frame", screenGui)
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundTransparency = 1
    
    local bg = Instance.new("Frame", frame)
    bg.Size = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3 = Color3.fromRGB(25, 0, 40)
    bg.BackgroundTransparency = 1
    TweenService:Create(bg, TweenInfo.new(0.8), { BackgroundTransparency = 0.2 }):Play()
    
    local word = "7zxy Hub"
    local letters = {}
    
    for i = 1, #word do
        local char = word:sub(i, i)
        local label = Instance.new("TextLabel")
        label.Text = char
        label.Font = Enum.Font.GothamBlack
        label.TextColor3 = Color3.new(1, 1, 1)
        label.TextTransparency = 1
        label.TextSize = 20
        label.Size = UDim2.new(0, 60, 0, 60)
        label.AnchorPoint = Vector2.new(0.5, 0.5)
        label.Position = UDim2.new(0.5, (i - (#word / 2 + 0.5)) * 55, 0.5, 20)
        label.BackgroundTransparency = 1
        label.Parent = frame
        
        local gradient = Instance.new("UIGradient")
        gradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(200, 120, 255)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 0, 200))
        })
        gradient.Rotation = 90
        gradient.Parent = label
        
        TweenService:Create(label, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            TextTransparency = 0,
            TextSize = 55,
            Position = UDim2.new(0.5, (i - (#word / 2 + 0.5)) * 55, 0.5, 0)
        }):Play()
        
        table.insert(letters, label)
        task.wait(0.12)
    end
    
    task.wait(2)
    
    for _, label in pairs(letters) do
        TweenService:Create(label, TweenInfo.new(0.4), { TextTransparency = 1, TextSize = 20 }):Play()
    end
    
    TweenService:Create(bg, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
    TweenService:Create(blur, TweenInfo.new(0.6), { Size = 0 }):Play()
    task.wait(0.7)
    screenGui:Destroy()
    blur:Destroy()
end

-- ═══════════════════════════════════════════════════════
-- THEME DESIGN (ZyroTheme)
-- ═══════════════════════════════════════════════════════
WindUI:AddTheme({
    Name = "ZyroTheme",
    Font = Font.fromName("GothamSSm", Enum.FontWeight.Medium),
    Background = WindUI:Gradient({ ["0"] = { Color = Color3.fromHex("#1a1a1a") }, ["100"] = { Color = Color3.fromHex("#1a1a1a") } }, { Rotation = 180 }),
    Accent = WindUI:Gradient({ ["0"] = { Color = Color3.fromHex("#2563eb") }, ["100"] = { Color = Color3.fromHex("#1d4ed8") } }, { Rotation = 90 }),
    SideBar = WindUI:Gradient({ ["0"] = { Color = Color3.fromHex("#141414") }, ["100"] = { Color = Color3.fromHex("#141414") } }, { Rotation = 180 }),
    Tab = WindUI:Gradient({ ["0"] = { Color = Color3.fromHex("#222222") }, ["100"] = { Color = Color3.fromHex("#222222") } }, { Rotation = 90 }),
    Toggle = WindUI:Gradient({ ["0"] = { Color = Color3.fromHex("#16a34a") }, ["100"] = { Color = Color3.fromHex("#15803d") } }, { Rotation = 90 }),
    Button = WindUI:Gradient({ ["0"] = { Color = Color3.fromHex("#2563eb") }, ["100"] = { Color = Color3.fromHex("#1e40af") } }, { Rotation = 135 }),
    Text = WindUI:Gradient({ ["0"] = { Color = Color3.fromHex("#ffffff") }, ["100"] = { Color = Color3.fromHex("#d1d5db") } }, { Rotation = 90 }),
    Icon = WindUI:Gradient({ ["0"] = { Color = Color3.fromHex("#ffffff") }, ["100"] = { Color = Color3.fromHex("#9ca3af") } }, { Rotation = 90 }),
})

-- ═══════════════════════════════════════════════════════
-- ANTI-LAG SYSTEM
-- ═══════════════════════════════════════════════════════
local antiLagEnabled = false
local antiLagConnections = {}
local antiLagChangedProps = {}
local oldQualityLevel = nil
local oldSavedQualityLevel = nil

local function safeGet(instance, prop)
    local ok, val = pcall(function() return instance[prop] end)
    return ok and val or nil
end

local function safeSet(instance, prop, val)
    pcall(function() instance[prop] = val end)
end

local function rememberProp(instance, prop)
    if not instance then return end
    local data = antiLagChangedProps[instance]
    if not data then data = {}; antiLagChangedProps[instance] = data end
    if data[prop] == nil then data[prop] = safeGet(instance, prop) end
end

local function rememberAndSet(instance, prop, val)
    if not instance then return end
    rememberProp(instance, prop)
    safeSet(instance, prop, val)
end

local function shouldSkip(instance)
    local char = LocalPlayer.Character
    return char and instance:IsDescendantOf(char)
end

local function optimizeInstance(instance)
    if shouldSkip(instance) then return end
    if instance:IsA("BasePart") then
        rememberAndSet(instance, "Material", Enum.Material.SmoothPlastic)
        rememberAndSet(instance, "Reflectance", 0)
        rememberAndSet(instance, "CastShadow", false)
        if instance:IsA("MeshPart") then
            rememberAndSet(instance, "RenderFidelity", Enum.RenderFidelity.Performance)
            rememberAndSet(instance, "TextureID", "")
        end
    elseif instance:IsA("Decal") or instance:IsA("Texture") then
        rememberAndSet(instance, "Transparency", 1)
    elseif instance:IsA("ParticleEmitter") or instance:IsA("Trail") or instance:IsA("Beam") or
           instance:IsA("Smoke") or instance:IsA("Fire") or instance:IsA("Sparkles") then
        rememberAndSet(instance, "Enabled", false)
    elseif instance:IsA("PointLight") or instance:IsA("SpotLight") or instance:IsA("SurfaceLight") then
        rememberAndSet(instance, "Enabled", false)
    elseif instance:IsA("SpecialMesh") then
        rememberAndSet(instance, "TextureId", "")
    elseif instance:IsA("SurfaceAppearance") then
        rememberAndSet(instance, "ColorMap", "")
        rememberAndSet(instance, "MetalnessMap", "")
        rememberAndSet(instance, "NormalMap", "")
        rememberAndSet(instance, "RoughnessMap", "")
    end
end

local function optimizeLighting()
    rememberAndSet(Lighting, "Technology", Enum.Technology.Compatibility)
    rememberAndSet(Lighting, "GlobalShadows", false)
    rememberAndSet(Lighting, "FogEnd", 1e9)
    rememberAndSet(Lighting, "ShadowSoftness", 0)
    for _, effect in ipairs(Lighting:GetChildren()) do
        if effect:IsA("PostEffect") then
            rememberAndSet(effect, "Enabled", false)
        elseif effect:IsA("Atmosphere") then
            rememberAndSet(effect, "Density", 0)
            rememberAndSet(effect, "Haze", 0)
            rememberAndSet(effect, "Glare", 0)
        elseif effect:IsA("Sky") then
            rememberAndSet(effect, "CelestialBodiesShown", false)
            rememberAndSet(effect, "StarCount", 0)
        end
    end
end

local function optimizeTerrain()
    local terrain = Workspace:FindFirstChildOfClass("Terrain")
    if terrain then
        rememberAndSet(terrain, "Decoration", false)
        rememberAndSet(terrain, "WaterWaveSize", 0)
        rememberAndSet(terrain, "WaterWaveSpeed", 0)
        rememberAndSet(terrain, "WaterReflectance", 0)
        rememberAndSet(terrain, "WaterTransparency", 1)
    end
end

local function restoreAllProperties()
    for instance, data in pairs(antiLagChangedProps) do
        if instance and instance.Parent then
            for prop, val in pairs(data) do
                safeSet(instance, prop, val)
            end
        end
        antiLagChangedProps[instance] = nil
    end
end

local function setLowestQuality()
    pcall(function()
        local rendering = settings().Rendering
        if oldQualityLevel == nil then oldQualityLevel = rendering.QualityLevel end
        rendering.QualityLevel = Enum.QualityLevel.Level01
    end)
    pcall(function()
        local userGameSettings = UserSettings():GetService("UserGameSettings")
        if oldSavedQualityLevel == nil then oldSavedQualityLevel = userGameSettings.SavedQualityLevel end
        userGameSettings.SavedQualityLevel = Enum.SavedQualitySetting.QualityLevel1
    end)
end

local function restoreQuality()
    if oldQualityLevel ~= nil then
        pcall(function() settings().Rendering.QualityLevel = oldQualityLevel end)
    end
    if oldSavedQualityLevel ~= nil then
        pcall(function()
            UserSettings():GetService("UserGameSettings").SavedQualityLevel = oldSavedQualityLevel
        end)
    end
end

local function enableAntiLag()
    if antiLagEnabled then return end
    antiLagEnabled = true
    setLowestQuality()
    optimizeLighting()
    optimizeTerrain()
    for _, inst in ipairs(Workspace:GetDescendants()) do
        optimizeInstance(inst)
    end
    local conn = Workspace.DescendantAdded:Connect(function(inst)
        if antiLagEnabled then optimizeInstance(inst) end
    end)
    table.insert(antiLagConnections, conn)
    WindUI:Notify({ Title = "Anti-Lag", Content = "Enabled", Duration = 2, Icon = "zap" })
end

local function disableAntiLag()
    if not antiLagEnabled then return end
    antiLagEnabled = false
    for _, conn in ipairs(antiLagConnections) do
        pcall(function() conn:Disconnect() end)
    end
    antiLagConnections = {}
    restoreAllProperties()
    restoreQuality()
    WindUI:Notify({ Title = "Anti-Lag", Content = "Disabled", Duration = 2, Icon = "stop" })
end

-- ═══════════════════════════════════════════════════════
-- CONFIG & DATA MANAGEMENT
-- ═══════════════════════════════════════════════════════
local Config = {
    AutoPress         = false,
    AutoRebirth       = false,
    AutoBuyCubes      = false,
    PressCheckDelay   = 0.5,
    RebirthCheckDelay = 0.5,
    SpeedBoost        = false,
    WalkSpeed         = 200,
    Noclip            = false,
    AntiAFK           = false,
    AutoSpin          = false,
    AutoClaim         = false,
    AntiLag           = false,
    WinFarm           = false,
}

local Events = ReplicatedStorage:WaitForChild("Events", 5)
local cachedChar = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
LocalPlayer.CharacterAdded:Connect(function(char) cachedChar = char end)

local function getCharacter() return cachedChar or LocalPlayer.Character end
local function getHumanoid()
    local char = getCharacter()
    return char and char:FindFirstChildWhichIsA("Humanoid")
end
local function getRootPart()
    local char = getCharacter()
    return char and (char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart)
end

local function fireRemote(name, ...)
    local remote = Events and Events:FindFirstChild(tostring(name))
    if not remote then return nil end
    local s, r
    if remote:IsA("RemoteEvent") then
        s, r = pcall(function(...) remote:FireServer(...) end, ...)
    elseif remote:IsA("RemoteFunction") then
        s, r = pcall(function(...) return remote:InvokeServer(...) end, ...)
    end
    return r
end

local currentData = nil
local function setupDataListener()
    local updateRemote = Events and Events:FindFirstChild("UpdatePlayerData")
    if updateRemote then
        updateRemote.OnClientEvent:Connect(function(data) currentData = data end)
    end
    task.spawn(function() currentData = fireRemote("GetPlayerData") end)
end
setupDataListener()

local BASE_LEVEL_CAP = 25
local LEVEL_CAP_PER_REBIRTH = 25
local PRESS_TIERS = {
    { Name = "Obsidian", RequiredRebirths = 60 }, { Name = "Platinum", RequiredRebirths = 45 },
    { Name = "Cheese", RequiredRebirths = 20 }, { Name = "Gold", RequiredRebirths = 15 },
    { Name = "Red", RequiredRebirths = 5 }, { Name = "Diamond", RequiredRebirths = 3 },
    { Name = "Silver", RequiredRebirths = 1 }, { Name = "Normal", RequiredRebirths = 0 },
}

local function getLevelCap(rebirths)
    if rebirths == 0 then return 20 end
    return BASE_LEVEL_CAP + LEVEL_CAP_PER_REBIRTH * rebirths
end

local function getBestPress(rebirths)
    for _, tier in ipairs(PRESS_TIERS) do
        if rebirths >= tier.RequiredRebirths then
            local pressModel = Workspace:FindFirstChild("Presses")
            local press = pressModel and pressModel:FindFirstChild(tier.Name)
            if press then return press, tier end
        end
    end
    return nil, nil
end

-- ===== WIN FARM STATE (UPDATED ACCURATE VALUES) =====
local ROOM_LEVELS = {
    Rooms = {
        [0] = 1,   [1] = 25,  [2] = 50,  [3] = 75,  [4] = 100,
        [5] = 125, [6] = 150, [7] = 175, [8] = 200, [9] = 225,
        [10] = 250,[11] = 275,[12] = 300,[13] = 343,[14] = 365,
        [15] = 400,[16] = 450,[17] = 510,[18] = 575,[19] = 645,
        [20] = 720,[21] = 800,[22] = 800,
    },
    CheeseRooms = {
        [0] = 1,   [1] = 25,  [2] = 50,  [3] = 75,  [4] = 100,
        [5] = 125, [6] = 150, [7] = 175, [8] = 200, [9] = 225,
        [10] = 250,[11] = 275,[12] = 300,[13] = 343,[14] = 365,
        [15] = 400,[16] = 450,[17] = 510,[18] = 575,[19] = 645,
        [20] = 720,[21] = 800,[22] = 900,[23] = 1000,[24] = 1111,
        [25] = 1111,
    },
    MoonRooms = {
        [0] = 1,   [1] = 25,  [2] = 50,  [3] = 75,  [4] = 100,
        [5] = 125, [6] = 150, [7] = 175, [8] = 200, [9] = 225,
        [10] = 250,[11] = 275,[12] = 300,[13] = 343,[14] = 365,
        [15] = 400,[16] = 450,[17] = 510,[18] = 575,[19] = 645,
        [20] = 720,[21] = 800,[22] = 900,[23] = 1000,[24] = 1111,
        [25] = 1250,[26] = 1400,[27] = 1600,[28] = 1600,
    }
}

local function getRoomForLevel(level, world)
    local world_data = ROOM_LEVELS[world] or ROOM_LEVELS["Rooms"]
    local best = 0
    for room, req in pairs(world_data) do
        if level >= req and room > best then best = room end
    end
    return best
end

-- ═══════════════════════════════════════════════════════
-- FEATURE ARCHITECTURE
-- ═══════════════════════════════════════════════════════
local featureHandles = {}
local featureFlags = {}

local function stopFeature(key)
    featureFlags[key] = false
    if featureHandles[key] and featureHandles[key].conn then 
        pcall(function() featureHandles[key].conn:Disconnect() end) 
    end
    featureHandles[key] = nil
    
    if key == "AntiLag" then
        disableAntiLag()
    end
end

local function registerConn(key, conn)
    stopFeature(key)
    featureFlags[key] = true
    featureHandles[key] = { conn = conn }
end

local function registerThread(key, fn)
    stopFeature(key)
    featureFlags[key] = true
    task.spawn(function() fn(function() return featureFlags[key] and Config[key] end) end)
end

-- ═══════════════════════════════════════════════════════
-- FEATURE IMPLEMENTATIONS
-- ═══════════════════════════════════════════════════════
local function startAutoPress()
    registerThread("AutoPress", function(isRunning)
        while isRunning() do
            if currentData and currentData.Stats then
                local press = getBestPress(currentData.Stats.Rebirths or 0)
                if press then
                    local mainPart = press:FindFirstChild("Main")
                    local root = getRootPart()
                    if mainPart and root and (root.Position - mainPart.Position).Magnitude > 15 then
                        root.CFrame = mainPart.CFrame + Vector3.new(0, 5, 0)
                    end
                end
            end
            task.wait(Config.PressCheckDelay)
        end
    end)
end

local function startAutoRebirth()
    registerThread("AutoRebirth", function(isRunning)
        while isRunning() do
            if currentData and currentData.Stats then
                local level = currentData.Stats.Level or 0
                local cap = getLevelCap(currentData.Stats.Rebirths or 0)
                if level >= cap then
                    local success = fireRemote("Rebirth")
                    task.wait(success and 3 or 1)
                end
            end
            task.wait(Config.RebirthCheckDelay)
        end
    end)
end

local function startAutoBuyCubes()
    registerThread("AutoBuyCubes", function(isRunning)
        local eventsFolder = ReplicatedStorage:FindFirstChild("Events")
        local upgradeRemote = eventsFolder and eventsFolder:FindFirstChild("Upgraded")
        
        while isRunning() do
            if upgradeRemote then
                -- Loops through from best to worst to force highest upgrade
                for i = 50, 1, -1 do
                    pcall(function()
                        upgradeRemote:FireServer(tostring(i))
                    end)
                end
            end
            task.wait(5)
        end
    end)
end

local function startSpeedBoost()
    registerConn("SpeedBoost", RunService.Heartbeat:Connect(function()
        if not Config.SpeedBoost then return end
        local hum = getHumanoid()
        if hum then hum.WalkSpeed = Config.WalkSpeed end
    end))
end

local function startNoclip()
    registerConn("Noclip", RunService.Stepped:Connect(function()
        if not Config.Noclip then return end
        local char = getCharacter()
        if not char then return end
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = false end
        end
    end))
end

local function startAntiAFK()
    local VirtualUser = nil
    pcall(function() VirtualUser = game:GetService("VirtualUser") end)
    if not VirtualUser then return end
    
    registerConn("AntiAFK", LocalPlayer.Idled:Connect(function()
        if not Config.AntiAFK then return end
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
    end))
end

local function startAutoSpin()
    registerThread("AutoSpin", function(isRunning)
        while isRunning() do
            if currentData and currentData.Stats and (currentData.Stats.WheelSpins or 0) > 0 then
                fireRemote("WheelSpin")
            end
            task.wait(5)
        end
    end)
end

local function startAutoClaim()
    registerThread("AutoClaim", function(isRunning)
        while isRunning() do
            fireRemote("ClaimPlaytime")
            task.wait(30)
        end
    end)
end

local function startWinFarm()
    local toggleOut = false
    registerConn("WinFarm", RunService.Heartbeat:Connect(function()
        if not Config.WinFarm then return end
        if currentData and currentData.Stats then
            local level = currentData.Stats.Level or 1
            local rebirths = currentData.Stats.Rebirths or 0
            
            -- Route correctly based on Rebirths
            local selectedWorld = "Rooms"
            if rebirths >= 45 then
                selectedWorld = "MoonRooms"
            elseif rebirths >= 15 then
                selectedWorld = "CheeseRooms"
            end
            
            local room = getRoomForLevel(level, selectedWorld)
            local container = Workspace:FindFirstChild(selectedWorld)
            
            if container then
                local targetRoom = container:FindFirstChild(tostring(room))
                -- The game uses either "Win" or "WinRobux" depending on the world
                local winPart = targetRoom and (targetRoom:FindFirstChild("Win") or targetRoom:FindFirstChild("WinRobux"))
                
                if winPart then
                    local root = getRootPart()
                    if root then
                        toggleOut = not toggleOut
                        root.CFrame = CFrame.new(winPart.Position + (toggleOut and Vector3.new(0, 5, 0) or Vector3.new(0, 3, 0)))
                    end
                end
            end
        end
    end))
end

-- ═══════════════════════════════════════════════════════
-- WINDUI WINDOW SETUP
-- ═══════════════════════════════════════════════════════
local function showGUI()
    local Window = WindUI:CreateWindow({
        Title = "1+ Shrink Per step",
        Icon = "hammer",
        Author = "By 7zxy" .. utf8.char(0xE000),
        Folder = "7zxy Hub",
        Size = UDim2.fromOffset(560, 380),
        MinSize = Vector2.new(560, 350),
        MaxSize = Vector2.new(850, 560),
        Theme = "ZyroTheme",
        Resizable = true,
        SideBarWidth = 200,
        HideSearchBar = false,
        ScrollBarEnabled = false,
        User = { Enabled = true, Anonymous = false, Callback = function() end },
    })

    -- VERSION & PING TAGS
    local versionTag = Window:Tag({
        Title = "v2.2",
        Icon = "tag",
        Color = Color3.fromHex("#2563eb"),
        Radius = 100
    })

    local pingTag = Window:Tag({
        Title = "0ms",
        Icon = "wifi",
        Color = Color3.fromHex("#22c55e"),
        Radius = 100
    })

    task.spawn(function()
        while true do
            local ping = getPing()
            if pingTag and pingTag.SetTitle then
                pingTag:SetTitle(ping .. "ms")
            end
            task.wait(0.8)
        end
    end)

    Window:EditOpenButton({
        Title = "7zxy Hub Open",
        Icon = "hammer",
        CornerRadius = UDim.new(0, 8),
        StrokeThickness = 1,
        Color = ColorSequence.new(Color3.fromHex("#2563eb"), Color3.fromHex("#1d4ed8")),
        OnlyMobile = false,
        Enabled = true,
        Draggable = true,
    })

    -- ═══════════════════════════════════════════════════════
    -- TAB 1: INFORMATION
    -- ═══════════════════════════════════════════════════════
    local InfoTab = Window:Tab({ Title = "Information", Icon = "info" })
    local avatarUrl = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. LocalPlayer.UserId .. "&width=100&height=100&format=png"
    
    InfoTab:Paragraph({
        Title = "👋 Hi " .. LocalPlayer.Name .. "!",
        Desc = "Welcome to 7zxy Hub.\nIf you encounter any issues, please join our Discord via the Support tab.",
        Color = Color3.fromHex("#222222"),
        Image = avatarUrl,
        ImageSize = 64,
        ThumbnailSize = 80,
    })

    Window:Divider()

    InfoTab:Section({ Title = "Player Selector" })

    local selectedPlayerName = nil
    local playersDropdown = nil
    local profileParagraph = nil

    local function updateProfile(plr)
        if not plr then
            if profileParagraph then
                profileParagraph:SetDesc("No player selected.")
                profileParagraph:SetImage("")
            end
            return
        end

        local age = plr.AccountAge or 0
        local avatar = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. plr.UserId .. "&width=100&height=100&format=png"
        local desc = string.format("**Name:** %s\n**Account Age:** %d days\n**User ID:** %d", plr.Name, age, plr.UserId)

        if profileParagraph then
            profileParagraph:SetDesc(desc)
            profileParagraph:SetImage(avatar)
        else
            profileParagraph = InfoTab:Paragraph({
                Title = "Selected Player Profile",
                Desc = desc,
                Color = Color3.fromHex("#222222"),
                Image = avatar,
                ImageSize = 64,
                ThumbnailSize = 80,
            })
        end
    end

    local function getPlayerNames()
        local playerNames = {}
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                table.insert(playerNames, p.Name)
            end
        end
        if #playerNames == 0 then
            table.insert(playerNames, "No other players")
        end
        return playerNames
    end

    local function refreshPlayersDropdown()
        local playerNames = getPlayerNames()

        if playersDropdown then
            playersDropdown:SetValues(playerNames)
            if not table.find(playerNames, selectedPlayerName) then
                selectedPlayerName = playerNames[1]
                playersDropdown:SetValue(selectedPlayerName)
            end
        else
            playersDropdown = InfoTab:Dropdown({
                Title = "Select a player",
                Desc = "Choose a player to view their profile and teleport to them",
                Values = playerNames,
                Value = playerNames[1],
                Callback = function(option)
                    selectedPlayerName = option
                    local target = Players:FindFirstChild(option)
                    updateProfile(target)
                end
            })
            selectedPlayerName = playerNames[1]
        end

        local target = Players:FindFirstChild(selectedPlayerName)
        updateProfile(target)
    end

    refreshPlayersDropdown()

    Players.PlayerAdded:Connect(refreshPlayersDropdown)
    Players.PlayerRemoving:Connect(refreshPlayersDropdown)

    InfoTab:Button({
        Title = "Refresh Players",
        Icon = "refresh-cw",
        Callback = function()
            refreshPlayersDropdown()
            WindUI:Notify({ Title = "Players Refreshed", Duration = 1, Icon = "check" })
        end
    })

    InfoTab:Button({
        Title = "Teleport to Player",
        Icon = "send",
        Callback = function()
            if not selectedPlayerName or selectedPlayerName == "No other players" then
                WindUI:Notify({ Title = "No player selected", Duration = 2, Icon = "alert-circle" })
                return
            end

            local target = Players:FindFirstChild(selectedPlayerName)
            if not target then
                WindUI:Notify({ Title = "Player not found", Duration = 2, Icon = "alert-circle" })
                return
            end

            local char = target.Character
            local root = getRootPart()
            if not char or not char:FindFirstChild("HumanoidRootPart") then
                WindUI:Notify({ Title = "Target has no character", Duration = 2, Icon = "alert-circle" })
                return
            end
            if not root then
                WindUI:Notify({ Title = "You have no character", Duration = 2, Icon = "alert-circle" })
                return
            end

            root.CFrame = target.Character.HumanoidRootPart.CFrame + Vector3.new(0, 2, 0)
            WindUI:Notify({ Title = "Teleported to " .. target.Name, Duration = 2, Icon = "check" })
        end
    })

    -- ═══════════════════════════════════════════════════════
    -- TAB 2: MAIN FEATURES
    -- ═══════════════════════════════════════════════════════
    local MainTab = Window:Tab({ Title = "Main Features", Icon = "house" })

    MainTab:Section({ Title = "Auto Farm" })
    
    MainTab:Toggle({
        Title = "Enable Win Farm",
        Desc = "Farms wins across standard, cheese, and moon rooms dynamically",
        Default = false,
        Callback = function(v)
            Config.WinFarm = v
            if v then startWinFarm() else stopFeature("WinFarm") end
        end
    })

    MainTab:Toggle({
        Title = "Auto Press",
        Desc = "Teleports to the best available press",
        Default = false,
        Callback = function(v)
            Config.AutoPress = v
            if v then startAutoPress() else stopFeature("AutoPress") end
        end
    })

    MainTab:Toggle({
        Title = "Auto Rebirth",
        Desc = "Rebirths when level cap is reached",
        Default = false,
        Callback = function(v)
            Config.AutoRebirth = v
            if v then startAutoRebirth() else stopFeature("AutoRebirth") end
        end
    })
    
    MainTab:Toggle({
        Title = "Auto Buy Shrink Cubes",
        Desc = "Automatically buys your highest unlocked shrink cube",
        Default = false,
        Callback = function(v)
            Config.AutoBuyCubes = v
            if v then startAutoBuyCubes() else stopFeature("AutoBuyCubes") end
        end
    })

    MainTab:Section({ Title = "Automation" })

    MainTab:Toggle({
        Title = "Auto Spin",
        Default = false,
        Callback = function(v)
            Config.AutoSpin = v
            if v then startAutoSpin() else stopFeature("AutoSpin") end
        end
    })

    MainTab:Toggle({
        Title = "Auto Claim",
        Default = false,
        Callback = function(v)
            Config.AutoClaim = v
            if v then startAutoClaim() else stopFeature("AutoClaim") end
        end
    })

    Window:Divider()

    -- ═══════════════════════════════════════════════════════
    -- TAB 3: MOVEMENT
    -- ═══════════════════════════════════════════════════════
    local MovementTab = Window:Tab({ Title = "Movement", Icon = "move" })

    MovementTab:Section({ Title = "Player Modifiers" })

    MovementTab:Toggle({
        Title = "Speed Boost",
        Default = false,
        Callback = function(v)
            Config.SpeedBoost = v
            if v then startSpeedBoost() else stopFeature("SpeedBoost") end
        end
    })

    MovementTab:Slider({
        Title = "Walk Speed",
        Desc = "Set your movement speed (16-250)",
        Step = 1,
        Value = {
            Min = 16,
            Max = 250,
            Default = 200,
        },
        Callback = function(v)
            Config.WalkSpeed = v
        end
    })

    MovementTab:Toggle({
        Title = "Noclip",
        Desc = "Walk through objects",
        Default = false,
        Callback = function(v)
            Config.Noclip = v
            if v then startNoclip() else stopFeature("Noclip") end
        end
    })

    -- ═══════════════════════════════════════════════════════
    -- TAB 4: MISC
    -- ═══════════════════════════════════════════════════════
    local MiscTab = Window:Tab({ Title = "Misc", Icon = "wrench" })

    MiscTab:Section({ Title = "Optimization" })

    MiscTab:Toggle({
        Title = "Anti-Lag",
        Desc = "Reduces lag by optimizing rendering",
        Default = false,
        Callback = function(state)
            Config.AntiLag = state
            if state then enableAntiLag() else disableAntiLag() end
        end
    })

    MiscTab:Section({ Title = "Protection" })

    MiscTab:Toggle({
        Title = "Anti-AFK",
        Desc = "Prevents idle kicks",
        Default = false,
        Callback = function(v)
            Config.AntiAFK = v
            if v then startAntiAFK() else stopFeature("AntiAFK") end
        end
    })

    MiscTab:Section({ Title = "Utility" })

    MiscTab:Button({
        Title = "Stop All Features",
        Icon = "stop-circle",
        Callback = function()
            for key in pairs(Config) do
                if Config[key] == true then
                    stopFeature(key)
                    Config[key] = false
                end
            end
            WindUI:Notify({
                Title = "Stopped",
                Content = "All features disabled",
                Duration = 2,
                Icon = "check"
            })
        end
    })

    -- ═══════════════════════════════════════════════════════
    -- TAB 5: SERVER
    -- ═══════════════════════════════════════════════════════
    local ServerTab = Window:Tab({ Title = "Server", Icon = "server" })
    
    ServerTab:Section({ Title = "Player Info" })
    
    local avatarUrlServer = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. LocalPlayer.UserId .. "&width=100&height=100&format=png"
    ServerTab:Paragraph({
        Title = "Your Details",
        Desc = string.format("Name: %s\nAge: %d days\nHWID: %s", LocalPlayer.Name, LocalPlayer.AccountAge, hwid),
        Color = Color3.fromHex("#222222"),
        Image = avatarUrlServer,
        ImageSize = 64,
        ThumbnailSize = 80,
    })
    
    ServerTab:Section({ Title = "Server Actions" })
    
    ServerTab:Button({ 
        Title = "Hop Server", 
        Icon = "repeat", 
        Callback = function() 
            WindUI:Notify({ Title = "Hopping...", Duration = 2 }) 
            TeleportService:Teleport(game.PlaceId) 
        end 
    })
    
    ServerTab:Button({ 
        Title = "Rejoin", 
        Icon = "log-in", 
        Callback = function() 
            WindUI:Notify({ Title = "Rejoining...", Duration = 2 }) 
            TeleportService:Teleport(game.PlaceId, LocalPlayer) 
        end 
    })
    
    ServerTab:Button({ 
        Title = "Reset Character", 
        Icon = "refresh-cw", 
        Callback = function()
            local char = getCharacter()
            if char then
                char:BreakJoints()
                WindUI:Notify({ Title = "Reset", Content = "Respawning...", Duration = 2, Icon = "refresh-cw" })
            else
                WindUI:Notify({ Title = "Reset", Content = "No character.", Duration = 2, Icon = "info" })
            end
        end
    })

    -- ═══════════════════════════════════════════════════════
    -- TAB 6: SUPPORT
    -- ═══════════════════════════════════════════════════════
    local SupportTab = Window:Tab({ Title = "Support", Icon = "heart" })
    local InviteCode = "8mte25S8E"
    local DiscordAPI = "https://discord.com/api/v10/invites/" .. InviteCode .. "?with_counts=true&with_expiration=true"

    local raw = httpGet(DiscordAPI)
    local Response = {}
    if raw then pcall(function() Response = HttpService:JSONDecode(raw) end) end
    local onlineCount = Response and Response.approximate_presence_count or "?"
    local totalCount = Response and Response.approximate_member_count or "?"
    local guildName = (Response and Response.guild and Response.guild.name) or "7zxy Hub Support"
    local iconUrl = nil
    if Response and Response.guild and Response.guild.id and Response.guild.icon then
        iconUrl = "https://cdn.discordapp.com/icons/" .. tostring(Response.guild.id) .. "/" .. tostring(Response.guild.icon) .. ".png?size=256"
    end
    
    SupportTab:Section({ Title = "Discord Server" })
    
    local cardProps = {
        Title = guildName,
        Desc = "Online: " .. tostring(onlineCount) .. "   Members: " .. tostring(totalCount) .. "\nJoin for updates & support.",
        Color = Color3.fromHex("#222222"),
        ImageSize = 64,
        ThumbnailSize = 100,
        Buttons = {
            { 
                Title = "Copy Invite", 
                Callback = function() 
                    copyToClipboard("https://discord.gg/" .. InviteCode)
                    WindUI:Notify({ Title = "Copied!", Duration = 2, Icon = "clipboard-check" }) 
                end 
            },
            { 
                Title = "Join Discord", 
                Callback = function() 
                    if openUrl then 
                        openUrl("https://discord.gg/" .. InviteCode) 
                    else 
                        copyToClipboard("https://discord.gg/" .. InviteCode)
                        WindUI:Notify({ Title = "Link Copied", Duration = 2, Icon = "globe" }) 
                    end 
                end 
            }
        }
    }
    if iconUrl then cardProps.Image = iconUrl end
    SupportTab:Paragraph(cardProps)
    
    SupportTab:Section({ Title = "Help" })
    
    SupportTab:Paragraph({ 
        Title = "Executor", 
        Desc = "Using: " .. executorName, 
        Color = Color3.fromHex("#222222") 
    })
    
    SupportTab:Button({ 
        Title = "Report Bug", 
        Icon = "bug", 
        Callback = function()
            copyToClipboard("Bug Report\nExecutor: " .. executorName .. "\nScript: 7zxy Hub v2.2\n\nDescribe:")
            WindUI:Notify({ Title = "Template Copied", Content = "Paste in Discord.", Duration = 4, Icon = "message-square" })
        end
    })
end

showLoadingScreen()
task.wait(2.5)
showGUI()
