--[[
    7zxy Hub — v2.0.0
     UI Redesign
    ───────────────────────────────────────
]]

-- ═══════════════════════════════════════
-- CONFIG PERSISTENCE via _G
-- ═══════════════════════════════════════
local Config = _G.SevenZXYConfig or {
    AutoPress         = false,
    AutoRebirth       = false,
    PressCheckDelay   = 0.5,
    RebirthCheckDelay = 0.5,
    SpeedBoost        = false,
    WalkSpeed         = 200,
    Noclip            = false,
    AntiAFK           = false,
    AutoSpin          = false,
    AutoClaim         = false,
}
_G.SevenZXYConfig = Config

-- ═══════════════════════════════════════
-- SERVICES
-- ═══════════════════════════════════════
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local UserInputService  = game:GetService("UserInputService")
local VirtualUser       = nil
pcall(function() VirtualUser = game:GetService("VirtualUser") end)
local Workspace         = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Events = ReplicatedStorage:WaitForChild("Events")

-- ═══════════════════════════════════════
-- CHARACTER REFERENCES (respawn-safe)
-- ═══════════════════════════════════════
local cachedChar = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
LocalPlayer.CharacterAdded:Connect(function(char) cachedChar = char end)

local function getCharacter() return cachedChar end
local function getHumanoid()
    local char = getCharacter()
    return char and char:FindFirstChildWhichIsA("Humanoid")
end
local function getRootPart()
    local char = getCharacter()
    return char and (char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart)
end

-- ═══════════════════════════════════════
-- REMOTE HELPER
-- ═══════════════════════════════════════
local warnedRemotes = {}
local function fireRemote(name, ...)
    local remote = Events:FindFirstChild(tostring(name))
    if not remote then
        if not warnedRemotes[name] then
            warnedRemotes[name] = true
            warn("[7zxy Hub] Remote not found: " .. tostring(name))
        end
        return nil
    end
    if remote:IsA("RemoteEvent") then remote:FireServer(...); return nil end
    return remote:InvokeServer(...)
end

-- ═══════════════════════════════════════
-- PLAYER DATA
-- ═══════════════════════════════════════
local currentData = nil
local function setupDataListener()
    local updateRemote = Events:FindFirstChild("UpdatePlayerData")
    if updateRemote then
        updateRemote.OnClientEvent:Connect(function(data) currentData = data end)
    end
    pcall(function() currentData = fireRemote("GetPlayerData") end)
end

-- ═══════════════════════════════════════
-- GAME CONSTANTS
-- ═══════════════════════════════════════
local BASE_LEVEL_CAP        = 25
local LEVEL_CAP_PER_REBIRTH = 25

local PRESS_TIERS = {
    { Name = "Obsidian",  RequiredRebirths = 45 },
    { Name = "Platinum",  RequiredRebirths = 30 },
    { Name = "Cheese",    RequiredRebirths = 20 },
    { Name = "Gold",      RequiredRebirths = 15 },
    { Name = "Red",       RequiredRebirths = 5  },
    { Name = "Diamond",   RequiredRebirths = 3  },
    { Name = "Silver",    RequiredRebirths = 1  },
    { Name = "Normal",    RequiredRebirths = 0  },
}

local function getLevelCap(rebirths)
    if rebirths == 0 then return 20 end
    return BASE_LEVEL_CAP + LEVEL_CAP_PER_REBIRTH * rebirths
end

local function getBestPress(rebirths)
    for _, tier in ipairs(PRESS_TIERS) do
        if rebirths >= tier.RequiredRebirths then
            local pressModel = Workspace:FindFirstChild("Presses")
            if pressModel then
                local press = pressModel:FindFirstChild(tier.Name)
                if press then return press, tier end
            end
        end
    end
    return nil, nil
end

-- ═══════════════════════════════════════
-- PER-FEATURE TRACKING
-- ═══════════════════════════════════════
local featureHandles = {}
local featureFlags   = {}

local function stopFeature(key)
    featureFlags[key] = false
    local h = featureHandles[key]
    if not h then return end
    if h.conn then pcall(function() h.conn:Disconnect() end); h.conn = nil end
    featureHandles[key] = nil
end

local function registerConn(key, conn)
    stopFeature(key)
    featureFlags[key]   = true
    featureHandles[key] = { conn = conn }
end

local function registerThread(key, fn)
    stopFeature(key)
    featureFlags[key] = true
    task.spawn(function() fn(function() return featureFlags[key] end) end)
end

-- ═══════════════════════════════════════
-- FEATURE IMPLEMENTATIONS
-- ═══════════════════════════════════════
local function startAutoPress()
    registerThread("AutoPress", function(isRunning)
        while isRunning() and Config.AutoPress do
            if currentData and currentData.Stats then
                local rebirths = currentData.Stats.Rebirths or 0
                local press = getBestPress(rebirths)
                if press then
                    local mainPart = press:FindFirstChild("Main")
                    local root = getRootPart()
                    if mainPart and root then
                        if (root.Position - mainPart.Position).Magnitude > 15 then
                            root.CFrame = mainPart.CFrame + Vector3.new(0, 5, 0)
                        end
                    end
                end
            end
            task.wait(Config.PressCheckDelay)
        end
    end)
end

local function startAutoRebirth()
    registerThread("AutoRebirth", function(isRunning)
        while isRunning() and Config.AutoRebirth do
            if currentData and currentData.Stats then
                local level    = currentData.Stats.Level    or 0
                local rebirths = currentData.Stats.Rebirths or 0
                local cap      = getLevelCap(rebirths)
                if level >= cap then
                    local ok, success = pcall(function() return fireRemote("Rebirth") end)
                    task.wait((ok and success) and 3 or 1)
                end
            end
            task.wait(Config.RebirthCheckDelay)
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
        for _, part in char:GetDescendants() do
            if part:IsA("BasePart") then part.CanCollide = false end
        end
    end))
end

local function startAntiAFK()
    if not VirtualUser then
        warn("[7zxy Hub] VirtualUser not available — Anti-AFK skipped")
        return
    end
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
        while isRunning() and Config.AutoSpin do
            if currentData and currentData.Stats then
                local spins = currentData.Stats.WheelSpins or 0
                if spins > 0 then pcall(function() fireRemote("WheelSpin") end) end
            end
            task.wait(5)
        end
    end)
end

local function startAutoClaim()
    registerThread("AutoClaim", function(isRunning)
        while isRunning() and Config.AutoClaim do
            pcall(function() fireRemote("ClaimPlaytime") end)
            task.wait(30)
        end
    end)
end

local FEATURE_STARTERS = {
    AutoPress   = startAutoPress,
    AutoRebirth = startAutoRebirth,
    SpeedBoost  = startSpeedBoost,
    Noclip      = startNoclip,
    AntiAFK     = startAntiAFK,
    AutoSpin    = startAutoSpin,
    AutoClaim   = startAutoClaim,
}

_G.StopExploit = function()
    for key in pairs(FEATURE_STARTERS) do
        Config[key] = false
        stopFeature(key)
    end
end
_G.ExploitConfig = Config

-- ═══════════════════════════════════════
-- WIN FARM STATE
-- ═══════════════════════════════════════
local ROOM_LEVELS = {
    Rooms = {
        [0] = 1,   [1] = 25,  [2] = 50,  [3] = 75,  [4] = 100,
        [5] = 125, [6] = 150, [7] = 175, [8] = 200, [9] = 225,
        [10] = 250,[11] = 275,[12] = 300,[13] = 325,[14] = 365,
        [15] = 400,[16] = 450,[17] = 510,[18] = 575,[19] = 645,
        [20] = 720,[21] = 800,[22] = 885,
    },
    CheeseRooms = {
        [0] = 1,   [1] = 25,  [2] = 50,  [3] = 75,  [4] = 100,
        [5] = 125, [6] = 150, [7] = 175, [8] = 200, [9] = 225,
        [10] = 250,[11] = 275,[12] = 300,[13] = 325,[14] = 365,
        [15] = 400,[16] = 450,[17] = 510,[18] = 575,[19] = 645,
        [20] = 720,[21] = 800,[22] = 885,[23] = 975,[24] = 1070,
        [25] = 1170,
    },
    MoonRooms = {
        [0] = 1,   [1] = 25,  [2] = 50,  [3] = 75,  [4] = 100,
        [5] = 125, [6] = 150, [7] = 175, [8] = 200, [9] = 225,
        [10] = 250,[11] = 275,[12] = 300,[13] = 325,[14] = 365,
        [15] = 400,[16] = 450,[17] = 510,[18] = 575,[19] = 645,
        [20] = 720,[21] = 800,[22] = 900,[23] = 1000,[24] = 1111,
        [25] = 1170,[26] = 1275,[27] = 1385,[28] = 1500,
    }
}

local winFarmRunning = false
local selectedWorld  = "Rooms"
local winFarmConn    = nil
local lastStatsCheck = 0
local cachedWinPart  = nil
local cachedRoom     = nil
local toggleOut      = false

local function getRoomForLevel(level, world)
    local world_data = ROOM_LEVELS[world] or ROOM_LEVELS["Rooms"]
    local best = 0
    for room, req in pairs(world_data) do
        if level >= req and room > best then best = room end
    end
    return best
end

local function stopWinFarm(statusLabel)
    winFarmRunning = false
    if winFarmConn then winFarmConn:Disconnect(); winFarmConn = nil end
    cachedWinPart = nil; cachedRoom = nil
    if statusLabel then statusLabel.Text = "Status: Idle" end
end

-- ═══════════════════════════════════════
-- THEME — Night Hub Inspired
-- ═══════════════════════════════════════
local C = {
    bg         = Color3.fromRGB(15, 15, 18),
    sidebar    = Color3.fromRGB(20, 20, 25),
    titlebar   = Color3.fromRGB(20, 20, 25),
    content    = Color3.fromRGB(15, 15, 18),
    section    = Color3.fromRGB(24, 24, 30),
    sectionHdr = Color3.fromRGB(28, 28, 35),
    row        = Color3.fromRGB(20, 20, 26),
    accent     = Color3.fromRGB(65, 105, 225),
    accentDim  = Color3.fromRGB(45, 75, 180),
    toggleOn   = Color3.fromRGB(65, 105, 225),
    toggleOff  = Color3.fromRGB(50, 50, 60),
    knob       = Color3.fromRGB(255, 255, 255),
    text       = Color3.fromRGB(235, 235, 245),
    textDim    = Color3.fromRGB(120, 120, 140),
    textMuted  = Color3.fromRGB(80, 80, 100),
    border     = Color3.fromRGB(40, 40, 50),
    red        = Color3.fromRGB(200, 55, 55),
    green      = Color3.fromRGB(40, 180, 90),
    moon       = Color3.fromRGB(80, 80, 200),
    cheese     = Color3.fromRGB(200, 145, 0),
}

local function tw(obj, props, t)
    TweenService:Create(obj, TweenInfo.new(t or 0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end

-- ═══════════════════════════════════════
-- UI — Night Hub-inspired Layout
-- ═══════════════════════════════════════
local function createUI()
    local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
    local old = PlayerGui:FindFirstChild("SevenZXYHub")
    if old then old:Destroy() end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "SevenZXYHub"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.IgnoreGuiInset = true
    screenGui.Parent = PlayerGui

    -- Layout
    local W, H = 520, 370
    local TITLE_H = 28
    local SIDEBAR_W = 85

    -- ─── MAIN FRAME ───
    local main = Instance.new("Frame")
    main.Name = "Main"
    main.Size = UDim2.new(0, W, 0, H)
    main.Position = UDim2.new(0.5, -W/2, 0.5, -H/2)
    main.BackgroundColor3 = C.bg
    main.BorderSizePixel = 0
    main.Active = true
    main.ClipsDescendants = true
    main.Parent = screenGui
    Instance.new("UICorner", main).CornerRadius = UDim.new(0, 8)

    local mainStroke = Instance.new("UIStroke")
    mainStroke.Color = C.border
    mainStroke.Thickness = 1
    mainStroke.Transparency = 0.3
    mainStroke.Parent = main

    -- ─── TITLE BAR ───
    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, TITLE_H)
    titleBar.BackgroundColor3 = C.titlebar
    titleBar.BorderSizePixel = 0
    titleBar.ZIndex = 10
    titleBar.Parent = main

    local titleBorder = Instance.new("Frame")
    titleBorder.Size = UDim2.new(1, 0, 0, 1)
    titleBorder.Position = UDim2.new(0, 0, 1, -1)
    titleBorder.BackgroundColor3 = C.border
    titleBorder.BorderSizePixel = 0
    titleBorder.ZIndex = 11
    titleBorder.Parent = titleBar

    -- Hub title: "7zxy Hub @danielpark46 | discord.gg/DskebfFSd"
    local hubTitle = Instance.new("TextLabel")
    hubTitle.BackgroundTransparency = 1
    hubTitle.Size = UDim2.new(1, -100, 1, 0)
    hubTitle.Position = UDim2.new(0, 12, 0, 0)
    hubTitle.Font = Enum.Font.Gotham
    hubTitle.Text = "7zxy Hub"
    hubTitle.TextSize = 11
    hubTitle.TextColor3 = C.text
    hubTitle.TextXAlignment = Enum.TextXAlignment.Left
    hubTitle.ZIndex = 11
    hubTitle.Parent = titleBar

    local hubSub = Instance.new("TextLabel")
    hubSub.BackgroundTransparency = 1
    hubSub.Size = UDim2.new(1, -100, 1, 0)
    hubSub.Position = UDim2.new(0, 68, 0, 0)
    hubSub.Font = Enum.Font.Gotham
    hubSub.Text = "@danielpark46 | discord.gg/DskebfFSd"
    hubSub.TextSize = 10
    hubSub.TextColor3 = C.textDim
    hubSub.TextXAlignment = Enum.TextXAlignment.Left
    hubSub.ZIndex = 11
    hubSub.Parent = titleBar

    -- Window controls: — □ X (right side)
    local function makeWinBtn(text, xOff, color, hoverColor)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 28, 0, TITLE_H)
        btn.Position = UDim2.new(1, xOff, 0, 0)
        btn.BackgroundTransparency = 1
        btn.Text = text
        btn.Font = Enum.Font.Gotham
        btn.TextSize = 14
        btn.TextColor3 = color
        btn.BorderSizePixel = 0
        btn.ZIndex = 12
        btn.Parent = titleBar
        btn.MouseEnter:Connect(function() tw(btn, { TextColor3 = hoverColor }, 0.1) end)
        btn.MouseLeave:Connect(function() tw(btn, { TextColor3 = color }, 0.1) end)
        return btn
    end

    local closeBtn = makeWinBtn("X", -30, C.textDim, Color3.fromRGB(255, 80, 80))
    local maxBtn   = makeWinBtn("□", -56, C.textDim, C.text)
    local minBtn   = makeWinBtn("—", -82, C.textDim, C.text)

    -- ─── SIDEBAR ───
    local sidebar = Instance.new("Frame")
    sidebar.Size = UDim2.new(0, SIDEBAR_W, 1, -TITLE_H)
    sidebar.Position = UDim2.new(0, 0, 0, TITLE_H)
    sidebar.BackgroundColor3 = C.sidebar
    sidebar.BorderSizePixel = 0
    sidebar.ZIndex = 5
    sidebar.ClipsDescendants = true
    sidebar.Parent = main

    local sidebarBorder = Instance.new("Frame")
    sidebarBorder.Size = UDim2.new(0, 1, 1, -TITLE_H)
    sidebarBorder.Position = UDim2.new(0, SIDEBAR_W, 0, TITLE_H)
    sidebarBorder.BackgroundColor3 = C.border
    sidebarBorder.BorderSizePixel = 0
    sidebarBorder.ZIndex = 6
    sidebarBorder.Parent = main

    -- Nav container (holds only nav buttons, separate from user info)
    local navContainer = Instance.new("Frame")
    navContainer.Size = UDim2.new(1, 0, 1, -44)
    navContainer.Position = UDim2.new(0, 0, 0, 0)
    navContainer.BackgroundTransparency = 1
    navContainer.ZIndex = 5
    navContainer.Parent = sidebar

    local sideList = Instance.new("UIListLayout")
    sideList.Padding = UDim.new(0, 2)
    sideList.SortOrder = Enum.SortOrder.LayoutOrder
    sideList.Parent = navContainer

    local sidePad = Instance.new("UIPadding")
    sidePad.PaddingTop = UDim.new(0, 8)
    sidePad.PaddingLeft = UDim.new(0, 0)
    sidePad.Parent = navContainer

    -- User info at sidebar bottom
    local userInfo = Instance.new("Frame")
    userInfo.Size = UDim2.new(1, 0, 0, 36)
    userInfo.Position = UDim2.new(0, 0, 1, -36)
    userInfo.BackgroundTransparency = 1
    userInfo.ZIndex = 6
    userInfo.Parent = sidebar

    local userThumb = Instance.new("ImageLabel")
    userThumb.Size = UDim2.new(0, 24, 0, 24)
    userThumb.Position = UDim2.new(0, 10, 0.5, -12)
    userThumb.BackgroundColor3 = C.section
    userThumb.BorderSizePixel = 0
    userThumb.ZIndex = 7
    userThumb.Parent = userInfo
    Instance.new("UICorner", userThumb).CornerRadius = UDim.new(1, 0)
    pcall(function()
        local thumbUrl = Players:GetUserThumbnailAsync(
            LocalPlayer.UserId,
            Enum.ThumbnailType.HeadShot,
            Enum.ThumbnailSize.Size48x48
        )
        userThumb.Image = thumbUrl
    end)

    local userName = Instance.new("TextLabel")
    userName.BackgroundTransparency = 1
    userName.Size = UDim2.new(1, -42, 1, 0)
    userName.Position = UDim2.new(0, 38, 0, 0)
    userName.Font = Enum.Font.Gotham
    userName.Text = LocalPlayer.DisplayName
    userName.TextSize = 10
    userName.TextColor3 = C.textDim
    userName.TextXAlignment = Enum.TextXAlignment.Left
    userName.TextTruncate = Enum.TextTruncate.AtEnd
    userName.ZIndex = 7
    userName.Parent = userInfo

    -- ─── CONTENT PANEL ───
    local contentPanel = Instance.new("Frame")
    contentPanel.Size = UDim2.new(1, -(SIDEBAR_W + 1), 1, -TITLE_H)
    contentPanel.Position = UDim2.new(0, SIDEBAR_W + 1, 0, TITLE_H)
    contentPanel.BackgroundTransparency = 1
    contentPanel.ClipsDescendants = true
    contentPanel.ZIndex = 5
    contentPanel.Parent = main

    -- ─── TOAST SYSTEM ───
    local toastQueue = {}
    local toastBusy  = false

    local toastHolder = Instance.new("Frame")
    toastHolder.Size = UDim2.new(0, 220, 0, 32)
    toastHolder.AnchorPoint = Vector2.new(0.5, 1)
    toastHolder.Position = UDim2.new(0.5, 0, 1, -16)
    toastHolder.BackgroundTransparency = 1
    toastHolder.ZIndex = 50
    toastHolder.Parent = screenGui

    local function showToast(msg, isGood)
        table.insert(toastQueue, { msg = msg, good = isGood })
        if toastBusy then return end
        toastBusy = true
        task.spawn(function()
            while #toastQueue > 0 do
                local item = table.remove(toastQueue, 1)
                local pill = Instance.new("Frame")
                pill.Size = UDim2.new(1, 0, 1, 0)
                pill.Position = UDim2.new(0, 0, 1.5, 0)
                pill.BackgroundColor3 = item.good and Color3.fromRGB(20, 45, 30) or Color3.fromRGB(50, 20, 20)
                pill.BackgroundTransparency = 0.05
                pill.BorderSizePixel = 0; pill.ZIndex = 50
                pill.Parent = toastHolder
                Instance.new("UICorner", pill).CornerRadius = UDim.new(0, 6)
                local s = Instance.new("UIStroke")
                s.Color = item.good and C.green or C.red
                s.Thickness = 1; s.Transparency = 0.5; s.Parent = pill
                local lbl = Instance.new("TextLabel")
                lbl.Size = UDim2.new(1, -16, 1, 0)
                lbl.Position = UDim2.new(0, 8, 0, 0)
                lbl.BackgroundTransparency = 1
                lbl.Font = Enum.Font.GothamBold; lbl.TextSize = 11
                lbl.TextColor3 = C.text
                lbl.TextXAlignment = Enum.TextXAlignment.Left
                lbl.Text = item.msg; lbl.ZIndex = 51; lbl.Parent = pill
                tw(pill, { Position = UDim2.new(0, 0, 0, 0) }, 0.2)
                task.wait(1.8)
                tw(pill, { BackgroundTransparency = 1 }, 0.2)
                tw(lbl, { TextTransparency = 1 }, 0.2)
                task.wait(0.25)
                pill:Destroy(); task.wait(0.05)
            end
            toastBusy = false
        end)
    end

    -- ═══════════════════════════════════════
    -- PAGE SYSTEM
    -- ═══════════════════════════════════════
    local pageFrames = {}
    local navItems   = {}
    local afToggles  = {}
    local activeNav  = nil
    local activeFeatures = {}

    -- Create a page scroll frame
    local function makePage(name)
        local scroll = Instance.new("ScrollingFrame")
        scroll.Size = UDim2.new(1, 0, 1, 0)
        scroll.BackgroundTransparency = 1
        scroll.BorderSizePixel = 0
        scroll.ScrollBarThickness = 2
        scroll.ScrollBarImageColor3 = C.accent
        scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
        pcall(function() scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y end)
        scroll.Visible = false
        scroll.ZIndex = 6
        scroll.Parent = contentPanel

        local list = Instance.new("UIListLayout")
        list.Padding = UDim.new(0, 2)
        list.SortOrder = Enum.SortOrder.LayoutOrder
        list.Parent = scroll

        local pad = Instance.new("UIPadding")
        pad.PaddingTop = UDim.new(0, 10)
        pad.PaddingLeft = UDim.new(0, 14)
        pad.PaddingRight = UDim.new(0, 14)
        pad.PaddingBottom = UDim.new(0, 10)
        pad.Parent = scroll

        pageFrames[name] = scroll
        return scroll
    end

    -- Page header label
    local function makePageHeader(parent, text, order)
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, 0, 0, 30)
        lbl.BackgroundTransparency = 1
        lbl.Font = Enum.Font.GothamBold
        lbl.Text = text
        lbl.TextSize = 18
        lbl.TextColor3 = C.text
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.LayoutOrder = order or 0
        lbl.ZIndex = 7
        lbl.Parent = parent
        return lbl
    end

    -- Collapsible section
    local function makeSection(parent, title, order, defaultOpen)
        local container = Instance.new("Frame")
        container.Size = UDim2.new(1, 0, 0, 32)
        container.BackgroundTransparency = 1
        container.LayoutOrder = order
        container.ZIndex = 7
        container.ClipsDescendants = true
        container.Parent = parent
        pcall(function() container.AutomaticSize = Enum.AutomaticSize.Y end)

        -- Section header
        local header = Instance.new("TextButton")
        header.Size = UDim2.new(1, 0, 0, 32)
        header.BackgroundColor3 = C.sectionHdr
        header.BorderSizePixel = 0
        header.Text = ""
        header.ZIndex = 8
        header.Parent = container
        Instance.new("UICorner", header).CornerRadius = UDim.new(0, 6)

        local headerLabel = Instance.new("TextLabel")
        headerLabel.BackgroundTransparency = 1
        headerLabel.Size = UDim2.new(1, -40, 1, 0)
        headerLabel.Position = UDim2.new(0, 12, 0, 0)
        headerLabel.Font = Enum.Font.GothamBold
        headerLabel.Text = title
        headerLabel.TextSize = 12
        headerLabel.TextColor3 = C.text
        headerLabel.TextXAlignment = Enum.TextXAlignment.Left
        headerLabel.ZIndex = 9
        headerLabel.Parent = header

        local chevron = Instance.new("TextLabel")
        chevron.BackgroundTransparency = 1
        chevron.Size = UDim2.new(0, 20, 1, 0)
        chevron.Position = UDim2.new(1, -28, 0, 0)
        chevron.Font = Enum.Font.GothamBold
        chevron.Text = defaultOpen and "v" or ">"
        chevron.TextSize = 12
        chevron.TextColor3 = C.textDim
        chevron.ZIndex = 9
        chevron.Parent = header

        -- Content holder
        local content = Instance.new("Frame")
        content.Size = UDim2.new(1, 0, 0, 0)
        content.Position = UDim2.new(0, 0, 0, 34)
        content.BackgroundTransparency = 1
        content.ZIndex = 7
        content.Visible = defaultOpen or false
        content.Parent = container
        pcall(function() content.AutomaticSize = Enum.AutomaticSize.Y end)

        local contentList = Instance.new("UIListLayout")
        contentList.Padding = UDim.new(0, 1)
        contentList.SortOrder = Enum.SortOrder.LayoutOrder
        contentList.Parent = content

        local isOpen = defaultOpen or false

        header.MouseButton1Click:Connect(function()
            isOpen = not isOpen
            content.Visible = isOpen
            chevron.Text = isOpen and "v" or ">"
        end)

        return content
    end

    -- Toggle row with title + description
    local function makeToggleRow(parent, order, title, desc, configKey, featureName, starter)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, desc and 46 or 34)
        row.BackgroundColor3 = C.row
        row.BorderSizePixel = 0
        row.LayoutOrder = order
        row.ZIndex = 8
        row.Parent = parent
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 4)

        local titleLbl = Instance.new("TextLabel")
        titleLbl.BackgroundTransparency = 1
        titleLbl.Size = UDim2.new(1, -60, 0, desc and 20 or 34)
        titleLbl.Position = UDim2.new(0, 12, 0, desc and 4 or 0)
        titleLbl.Font = Enum.Font.GothamBold
        titleLbl.Text = title
        titleLbl.TextSize = 12
        titleLbl.TextColor3 = C.text
        titleLbl.TextXAlignment = Enum.TextXAlignment.Left
        titleLbl.ZIndex = 9
        titleLbl.Parent = row

        if desc then
            local descLbl = Instance.new("TextLabel")
            descLbl.BackgroundTransparency = 1
            descLbl.Size = UDim2.new(1, -60, 0, 18)
            descLbl.Position = UDim2.new(0, 12, 0, 24)
            descLbl.Font = Enum.Font.Gotham
            descLbl.Text = desc
            descLbl.TextSize = 10
            descLbl.TextColor3 = C.textDim
            descLbl.TextXAlignment = Enum.TextXAlignment.Left
            descLbl.ZIndex = 9
            descLbl.Parent = row
        end

        -- Toggle switch
        local sw = Instance.new("Frame")
        sw.Size = UDim2.new(0, 36, 0, 18)
        sw.Position = UDim2.new(1, -48, 0.5, -9)
        sw.BackgroundColor3 = Config[configKey] and C.toggleOn or C.toggleOff
        sw.BorderSizePixel = 0
        sw.ZIndex = 9
        sw.Parent = row
        Instance.new("UICorner", sw).CornerRadius = UDim.new(1, 0)

        local knob = Instance.new("Frame")
        knob.Size = UDim2.new(0, 14, 0, 14)
        knob.Position = Config[configKey] and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)
        knob.BackgroundColor3 = C.knob
        knob.BorderSizePixel = 0
        knob.ZIndex = 10
        knob.Parent = sw
        Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

        local clickBtn = Instance.new("TextButton")
        clickBtn.Size = UDim2.new(1, 0, 1, 0)
        clickBtn.BackgroundTransparency = 1
        clickBtn.Text = ""
        clickBtn.ZIndex = 11
        clickBtn.Parent = sw

        clickBtn.MouseButton1Click:Connect(function()
            local newState = not Config[configKey]
            Config[configKey] = newState
            tw(sw, { BackgroundColor3 = newState and C.toggleOn or C.toggleOff }, 0.15)
            knob:TweenPosition(
                newState and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7),
                Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.15, true
            )
            if newState then
                activeFeatures[featureName] = true
                if starter then starter() end
                showToast("+ " .. featureName, true)
            else
                activeFeatures[featureName] = nil
                stopFeature(configKey)
                showToast("- " .. featureName, false)
            end
        end)

        afToggles[configKey] = { sw = sw, knob = knob }

        if Config[configKey] and starter then
            activeFeatures[featureName] = true
            starter()
        end

        return row
    end

    -- ═══════════════════════════════════════
    -- PAGE: MAIN
    -- ═══════════════════════════════════════
    local mainPage = makePage("main")
    makePageHeader(mainPage, "Main", 0)

    local autoFarmSection = makeSection(mainPage, "Auto Farm", 1, true)
    makeToggleRow(autoFarmSection, 1, "Auto Press", "Teleports to the best available press", "AutoPress", "Auto Press", startAutoPress)
    makeToggleRow(autoFarmSection, 2, "Auto Rebirth", "Rebirths when level cap is reached", "AutoRebirth", "Auto Rebirth", startAutoRebirth)

    local automationSection = makeSection(mainPage, "Automation", 2, true)
    makeToggleRow(automationSection, 1, "Auto Spin", "Automatically spins the lucky wheel", "AutoSpin", "Auto Spin", startAutoSpin)
    makeToggleRow(automationSection, 2, "Auto Claim", "Claims playtime rewards", "AutoClaim", "Auto Claim", startAutoClaim)
    makeToggleRow(automationSection, 3, "Anti-AFK", "Prevents being kicked for inactivity", "AntiAFK", "Anti-AFK", startAntiAFK)

    -- ═══════════════════════════════════════
    -- PAGE: MOVEMENT
    -- ═══════════════════════════════════════
    local movePage = makePage("movement")
    makePageHeader(movePage, "Movement", 0)

    local moveSection = makeSection(movePage, "Player", 1, true)
    makeToggleRow(moveSection, 1, "Speed Boost", "Increases walk speed", "SpeedBoost", "Speed Boost", startSpeedBoost)
    makeToggleRow(moveSection, 2, "Noclip", "Walk through walls and objects", "Noclip", "Noclip", startNoclip)

    -- Walk speed input row
    local wsRow = Instance.new("Frame")
    wsRow.Size = UDim2.new(1, 0, 0, 34)
    wsRow.BackgroundColor3 = C.row
    wsRow.BorderSizePixel = 0
    wsRow.LayoutOrder = 3
    wsRow.ZIndex = 8
    wsRow.Parent = moveSection
    Instance.new("UICorner", wsRow).CornerRadius = UDim.new(0, 4)

    local wsLbl = Instance.new("TextLabel")
    wsLbl.BackgroundTransparency = 1
    wsLbl.Size = UDim2.new(1, -80, 1, 0)
    wsLbl.Position = UDim2.new(0, 12, 0, 0)
    wsLbl.Font = Enum.Font.GothamBold
    wsLbl.Text = "Walk Speed"
    wsLbl.TextSize = 12
    wsLbl.TextColor3 = C.text
    wsLbl.TextXAlignment = Enum.TextXAlignment.Left
    wsLbl.ZIndex = 9
    wsLbl.Parent = wsRow

    local wsBox = Instance.new("TextBox")
    wsBox.Size = UDim2.new(0, 55, 0, 22)
    wsBox.Position = UDim2.new(1, -65, 0.5, -11)
    wsBox.BackgroundColor3 = C.section
    wsBox.TextColor3 = C.text
    wsBox.Font = Enum.Font.GothamBold
    wsBox.TextSize = 11
    wsBox.Text = tostring(Config.WalkSpeed)
    wsBox.PlaceholderText = "200"
    wsBox.BorderSizePixel = 0
    wsBox.ClearTextOnFocus = false
    wsBox.ZIndex = 9
    wsBox.Parent = wsRow
    Instance.new("UICorner", wsBox).CornerRadius = UDim.new(0, 4)

    wsBox.FocusLost:Connect(function()
        local val = tonumber(wsBox.Text)
        if val and val > 0 and val <= 10000 then
            Config.WalkSpeed = val
            showToast("Speed: " .. val, true)
        else
            wsBox.Text = tostring(Config.WalkSpeed)
        end
    end)

    -- ═══════════════════════════════════════
    -- PAGE: WIN FARM
    -- ═══════════════════════════════════════
    local wfPage = makePage("winfarm")
    makePageHeader(wfPage, "Win Farm", 0)

    local wfSection = makeSection(wfPage, "Room Farming", 1, true)

    -- Info row
    local wfInfoRow = Instance.new("Frame")
    wfInfoRow.Size = UDim2.new(1, 0, 0, 42)
    wfInfoRow.BackgroundColor3 = C.row
    wfInfoRow.BorderSizePixel = 0
    wfInfoRow.LayoutOrder = 0
    wfInfoRow.ZIndex = 8
    wfInfoRow.Parent = wfSection
    Instance.new("UICorner", wfInfoRow).CornerRadius = UDim.new(0, 4)

    local infoLabel = Instance.new("TextLabel")
    infoLabel.BackgroundTransparency = 1
    infoLabel.Size = UDim2.new(1, -16, 0, 20)
    infoLabel.Position = UDim2.new(0, 12, 0, 4)
    infoLabel.Font = Enum.Font.GothamBold
    infoLabel.Text = "Level: -- | Room: --"
    infoLabel.TextSize = 11
    infoLabel.TextColor3 = C.text
    infoLabel.TextXAlignment = Enum.TextXAlignment.Left
    infoLabel.ZIndex = 9
    infoLabel.Parent = wfInfoRow

    local progressBg = Instance.new("Frame")
    progressBg.Size = UDim2.new(1, -24, 0, 5)
    progressBg.Position = UDim2.new(0, 12, 1, -12)
    progressBg.BackgroundColor3 = C.toggleOff
    progressBg.BorderSizePixel = 0
    progressBg.ZIndex = 9
    progressBg.Parent = wfInfoRow
    Instance.new("UICorner", progressBg).CornerRadius = UDim.new(1, 0)

    local progressFill = Instance.new("Frame")
    progressFill.Size = UDim2.new(0, 0, 1, 0)
    progressFill.BackgroundColor3 = C.accent
    progressFill.BorderSizePixel = 0
    progressFill.ZIndex = 10
    progressFill.Parent = progressBg
    Instance.new("UICorner", progressFill).CornerRadius = UDim.new(1, 0)

    -- Start/Stop
    local wfBtnRow = Instance.new("Frame")
    wfBtnRow.Size = UDim2.new(1, 0, 0, 28)
    wfBtnRow.BackgroundTransparency = 1
    wfBtnRow.LayoutOrder = 1
    wfBtnRow.ZIndex = 8
    wfBtnRow.Parent = wfSection

    local wfStartBtn = Instance.new("TextButton")
    wfStartBtn.Size = UDim2.new(0.5, -3, 1, 0)
    wfStartBtn.BackgroundColor3 = C.green
    wfStartBtn.Text = "Start"
    wfStartBtn.TextColor3 = Color3.new(1, 1, 1)
    wfStartBtn.Font = Enum.Font.GothamBold
    wfStartBtn.TextSize = 11
    wfStartBtn.BorderSizePixel = 0
    wfStartBtn.ZIndex = 9
    wfStartBtn.Parent = wfBtnRow
    Instance.new("UICorner", wfStartBtn).CornerRadius = UDim.new(0, 4)

    local wfStopBtn = Instance.new("TextButton")
    wfStopBtn.Size = UDim2.new(0.5, -3, 1, 0)
    wfStopBtn.Position = UDim2.new(0.5, 3, 0, 0)
    wfStopBtn.BackgroundColor3 = C.red
    wfStopBtn.Text = "Stop"
    wfStopBtn.TextColor3 = Color3.new(1, 1, 1)
    wfStopBtn.Font = Enum.Font.GothamBold
    wfStopBtn.TextSize = 11
    wfStopBtn.BorderSizePixel = 0
    wfStopBtn.ZIndex = 9
    wfStopBtn.Parent = wfBtnRow
    Instance.new("UICorner", wfStopBtn).CornerRadius = UDim.new(0, 4)

    -- Status
    local wfStatusRow = Instance.new("Frame")
    wfStatusRow.Size = UDim2.new(1, 0, 0, 22)
    wfStatusRow.BackgroundTransparency = 1
    wfStatusRow.LayoutOrder = 3
    wfStatusRow.ZIndex = 8
    wfStatusRow.Parent = wfSection

    local wfStatus = Instance.new("TextLabel")
    wfStatus.BackgroundTransparency = 1
    wfStatus.Size = UDim2.new(1, 0, 1, 0)
    wfStatus.Font = Enum.Font.Gotham
    wfStatus.Text = "Status: Idle"
    wfStatus.TextSize = 10
    wfStatus.TextColor3 = C.textDim
    wfStatus.TextXAlignment = Enum.TextXAlignment.Left
    wfStatus.ZIndex = 9
    wfStatus.Parent = wfStatusRow

    -- Win farm logic
    local function updateProgress(level, room, world)
        local world_data = ROOM_LEVELS[world] or ROOM_LEVELS["Rooms"]
        local curReq  = world_data[room] or 0
        local nextReq = world_data[room + 1]
        local displayRoom = room + 1

        if nextReq then
            local pct = math.clamp((level - curReq) / (nextReq - curReq), 0, 1)
            tw(progressFill, { Size = UDim2.new(pct, 0, 1, 0) }, 0.35)
            infoLabel.Text = string.format("Level: %s | Room: %d", tostring(level), displayRoom)
        else
            tw(progressFill, { Size = UDim2.new(1, 0, 1, 0) }, 0.35)
            infoLabel.Text = string.format("Level: %s | Room: %d (MAX)", tostring(level), displayRoom)
        end
    end

    local function startWinFarm()
        if winFarmRunning then return end
        winFarmRunning = true
        cachedWinPart = nil; cachedRoom = nil; lastStatsCheck = 0
        wfStatus.Text = "Farming..."
        showToast("Win Farm started", true)

        winFarmConn = RunService.Heartbeat:Connect(function()
            if not winFarmRunning then return end
            local now = os.clock()
            if now - lastStatsCheck > 1 then
                lastStatsCheck = now
                local stats = currentData and currentData.Stats
                if stats then
                    local rebirths = stats.Rebirths or 0
                    local newWorld = "Rooms"
                    if rebirths >= 30 then
                        newWorld = "MoonRooms"
                    elseif rebirths >= 10 then
                        newWorld = "CheeseRooms"
                    end
                    
                    if selectedWorld ~= newWorld then
                        selectedWorld = newWorld
                        cachedWinPart = nil
                        cachedRoom = nil
                    end

                    local container = Workspace:FindFirstChild(selectedWorld)
                    local level = stats.Level or 1
                    local room = getRoomForLevel(level, selectedWorld)
                    updateProgress(level, room, selectedWorld)
                    
                    if container then
                        if room ~= cachedRoom then
                            cachedRoom = room
                            local targetRoom = container:FindFirstChild(tostring(room))
                            cachedWinPart = targetRoom and targetRoom:FindFirstChild("Win")
                        end
                        wfStatus.Text = cachedWinPart
                            and ("Farming " .. selectedWorld .. " room " .. (room + 1))
                            or ("Room " .. (room + 1) .. " not found")
                    else
                        wfStatus.Text = selectedWorld .. " not found!"
                        cachedWinPart = nil
                    end
                end
            end
            if cachedWinPart then
                local char = LocalPlayer.Character
                local root = char and char:FindFirstChild("HumanoidRootPart")
                if root then
                    toggleOut = not toggleOut
                    local offset = toggleOut and Vector3.new(0, 6, 0) or Vector3.new(0, 3, 0)
                    root.CFrame = CFrame.new(cachedWinPart.Position + offset)
                end
            end
        end)
    end

    wfStartBtn.MouseButton1Click:Connect(startWinFarm)
    wfStopBtn.MouseButton1Click:Connect(function()
        stopWinFarm(wfStatus); showToast("Win Farm stopped", false)
    end)

    -- ═══════════════════════════════════════
    -- PAGE: MISC
    -- ═══════════════════════════════════════
    local miscPage = makePage("misc")
    makePageHeader(miscPage, "Misc", 0)

    local aboutSection = makeSection(miscPage, "About", 1, true)

    local aboutRow = Instance.new("Frame")
    aboutRow.Size = UDim2.new(1, 0, 0, 60)
    aboutRow.BackgroundColor3 = C.row
    aboutRow.BorderSizePixel = 0
    aboutRow.LayoutOrder = 1
    aboutRow.ZIndex = 8
    aboutRow.Parent = aboutSection
    Instance.new("UICorner", aboutRow).CornerRadius = UDim.new(0, 4)

    local aboutTitle = Instance.new("TextLabel")
    aboutTitle.BackgroundTransparency = 1
    aboutTitle.Size = UDim2.new(1, -16, 0, 22)
    aboutTitle.Position = UDim2.new(0, 12, 0, 6)
    aboutTitle.Font = Enum.Font.GothamBold
    aboutTitle.Text = "7zxy Hub v2.0.0"
    aboutTitle.TextSize = 14
    aboutTitle.TextColor3 = C.text
    aboutTitle.TextXAlignment = Enum.TextXAlignment.Left
    aboutTitle.ZIndex = 9
    aboutTitle.Parent = aboutRow

    local aboutDesc = Instance.new("TextLabel")
    aboutDesc.BackgroundTransparency = 1
    aboutDesc.Size = UDim2.new(1, -16, 0, 16)
    aboutDesc.Position = UDim2.new(0, 12, 0, 28)
    aboutDesc.Font = Enum.Font.Gotham
    aboutDesc.Text = "Auto Farm Script — by 7zxy"
    aboutDesc.TextSize = 10
    aboutDesc.TextColor3 = C.textDim
    aboutDesc.TextXAlignment = Enum.TextXAlignment.Left
    aboutDesc.ZIndex = 9
    aboutDesc.Parent = aboutRow

    local dscBtn = Instance.new("TextButton")
    dscBtn.Size = UDim2.new(1, 0, 0, 30)
    dscBtn.BackgroundColor3 = C.accent
    dscBtn.Text = "Copy Discord Invite"
    dscBtn.TextColor3 = Color3.new(1, 1, 1)
    dscBtn.Font = Enum.Font.GothamBold
    dscBtn.TextSize = 11
    dscBtn.BorderSizePixel = 0
    dscBtn.LayoutOrder = 2
    dscBtn.ZIndex = 8
    dscBtn.Parent = aboutSection
    Instance.new("UICorner", dscBtn).CornerRadius = UDim.new(0, 4)

    dscBtn.MouseButton1Click:Connect(function()
        if setclipboard then
            pcall(function() setclipboard("https://discord.gg/DskebfFSd") end)
            showToast("Discord link copied!", true)
        else
            showToast("Clipboard not supported", false)
        end
    end)

    local stopSection = makeSection(miscPage, "Controls", 2, true)

    local stopAllBtn = Instance.new("TextButton")
    stopAllBtn.Size = UDim2.new(1, 0, 0, 30)
    stopAllBtn.BackgroundColor3 = C.red
    stopAllBtn.Text = "Stop All Features"
    stopAllBtn.TextColor3 = Color3.new(1, 1, 1)
    stopAllBtn.Font = Enum.Font.GothamBold
    stopAllBtn.TextSize = 11
    stopAllBtn.BorderSizePixel = 0
    stopAllBtn.LayoutOrder = 1
    stopAllBtn.ZIndex = 8
    stopAllBtn.Parent = stopSection
    Instance.new("UICorner", stopAllBtn).CornerRadius = UDim.new(0, 4)

    stopAllBtn.MouseButton1Click:Connect(function()
        _G.StopExploit()
        for _, t in pairs(afToggles) do
            tw(t.sw, { BackgroundColor3 = C.toggleOff }, 0.15)
            t.knob.Position = UDim2.new(0, 2, 0.5, -7)
        end
        table.clear(activeFeatures)
        showToast("All stopped", false)
    end)

    -- ═══════════════════════════════════════
    -- SIDEBAR NAV
    -- ═══════════════════════════════════════
    local function activateNav(name)
        for pname, frame in pairs(pageFrames) do frame.Visible = false end
        if pageFrames[name] then pageFrames[name].Visible = true end

        for pname, ni in pairs(navItems) do
            tw(ni.icon, { TextColor3 = C.textMuted }, 0.15)
            tw(ni.text, { TextColor3 = C.textMuted }, 0.15)
            ni.pill.Visible = false
        end

        local ni = navItems[name]
        if ni then
            tw(ni.icon, { TextColor3 = C.accent }, 0.15)
            tw(ni.text, { TextColor3 = C.text }, 0.15)
            ni.pill.Visible = true
        end

        activeNav = name
    end

    local function makeSideBtn(order, icon, label, pageName)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, 36)
        btn.BackgroundTransparency = 1
        btn.Text = ""
        btn.LayoutOrder = order
        btn.BorderSizePixel = 0
        btn.ZIndex = 6
        btn.Parent = navContainer

        -- Active indicator pill (left edge)
        local pill = Instance.new("Frame")
        pill.Size = UDim2.new(0, 3, 0, 18)
        pill.Position = UDim2.new(0, 0, 0.5, -9)
        pill.BackgroundColor3 = C.accent
        pill.BorderSizePixel = 0
        pill.Visible = false
        pill.ZIndex = 7
        pill.Parent = btn
        Instance.new("UICorner", pill).CornerRadius = UDim.new(1, 0)

        local iLbl = Instance.new("TextLabel")
        iLbl.BackgroundTransparency = 1
        iLbl.Size = UDim2.new(1, 0, 0, 16)
        iLbl.Position = UDim2.new(0, 0, 0, 4)
        iLbl.Font = Enum.Font.Gotham
        iLbl.Text = icon
        iLbl.TextSize = 14
        iLbl.TextColor3 = C.textMuted
        iLbl.ZIndex = 7
        iLbl.Parent = btn

        local tLbl = Instance.new("TextLabel")
        tLbl.BackgroundTransparency = 1
        tLbl.Size = UDim2.new(1, 0, 0, 12)
        tLbl.Position = UDim2.new(0, 0, 0, 20)
        tLbl.Font = Enum.Font.Gotham
        tLbl.Text = label
        tLbl.TextSize = 9
        tLbl.TextColor3 = C.textMuted
        tLbl.ZIndex = 7
        tLbl.Parent = btn

        navItems[pageName] = { btn = btn, icon = iLbl, text = tLbl, pill = pill }
        btn.MouseButton1Click:Connect(function() activateNav(pageName) end)
    end

    makeSideBtn(1, "⌂", "Main",     "main")
    makeSideBtn(2, "→", "Movement", "movement")
    makeSideBtn(3, "★", "Win Farm", "winfarm")
    makeSideBtn(4, "⚙", "Misc",     "misc")

    -- Status updater
    task.spawn(function()
        while screenGui.Parent do
            local stats = currentData and currentData.Stats
            if stats then
                userName.Text = string.format("%s  Lv%d R%d",
                    LocalPlayer.DisplayName,
                    stats.Level or 0,
                    stats.Rebirths or 0
                )
            end
            task.wait(2)
        end
    end)

    -- ═══════════════════════════════════════
    -- WINDOW CONTROLS
    -- ═══════════════════════════════════════
    local isMin = false

    -- Minimize pill
    local minPill = Instance.new("TextButton")
    minPill.Size = UDim2.new(0, 140, 0, 28)
    minPill.Position = UDim2.new(0.5, -70, 0, -36)
    minPill.BackgroundColor3 = C.sidebar
    minPill.BorderSizePixel = 0
    minPill.Text = ""
    minPill.Visible = false
    minPill.ZIndex = 50
    minPill.Parent = screenGui
    Instance.new("UICorner", minPill).CornerRadius = UDim.new(1, 0)

    local minPillStroke = Instance.new("UIStroke")
    minPillStroke.Color = C.accent
    minPillStroke.Thickness = 1
    minPillStroke.Transparency = 0.4
    minPillStroke.Parent = minPill

    local minPillText = Instance.new("TextLabel")
    minPillText.BackgroundTransparency = 1
    minPillText.Size = UDim2.new(1, 0, 1, 0)
    minPillText.Font = Enum.Font.GothamBold
    minPillText.Text = "+ Open 7zxy Hub"
    minPillText.TextSize = 10
    minPillText.TextColor3 = C.text
    minPillText.ZIndex = 51
    minPillText.Parent = minPill

    minBtn.MouseButton1Click:Connect(function()
        if not isMin then
            isMin = true
            main.Visible = false
            minPill.Visible = true
            minPill.Position = UDim2.new(0.5, -70, 0, -36)
            tw(minPill, { Position = UDim2.new(0.5, -70, 0, 16) }, 0.3)
        end
    end)

    minPill.MouseButton1Click:Connect(function()
        if isMin then
            isMin = false
            tw(minPill, { Position = UDim2.new(0.5, -70, 0, -36) }, 0.3)
            task.wait(0.2)
            minPill.Visible = false
            main.Visible = true
        end
    end)

    closeBtn.MouseButton1Click:Connect(function()
        _G.StopExploit()
        tw(main, { BackgroundTransparency = 1 }, 0.15)
        task.wait(0.18)
        screenGui:Destroy()
    end)

    local maximized = false
    local prevSize = main.Size
    local prevPos  = main.Position

    maxBtn.MouseButton1Click:Connect(function()
        if isMin then return end
        if not maximized then
            maximized = true
            prevSize = main.Size; prevPos = main.Position
            tw(main, { Size = UDim2.new(1, -40, 0, H), Position = UDim2.new(0, 20, 0.5, -H/2) }, 0.2)
        else
            maximized = false
            tw(main, { Size = prevSize, Position = prevPos }, 0.2)
        end
    end)

    -- Keybind
    pcall(function()
        UserInputService.InputBegan:Connect(function(input, gp)
            if gp then return end
            if input.KeyCode == Enum.KeyCode.RightShift then
                if isMin then
                    isMin = false
                    tw(minPill, { Position = UDim2.new(0.5, -70, 0, -36) }, 0.3)
                    task.wait(0.2)
                    minPill.Visible = false
                    main.Visible = true
                else
                    main.Visible = not main.Visible
                end
            end
        end)
    end)

    -- Dragging
    local dragging, dragStart, startPos = false, nil, nil

    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = input.Position; startPos = main.Position
        end
    end)

    titleBar.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then
            local delta = input.Position - dragStart
            main.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)

    -- Init
    activateNav("main")
    showToast("7zxy Hub v2.0.0 loaded", true)
end

-- ═══════════════════════════════════════
-- BOOT
-- ═══════════════════════════════════════
setupDataListener()
createUI()
