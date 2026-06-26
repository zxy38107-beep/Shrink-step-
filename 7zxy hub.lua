--[[
    7zxy Hub — v1.7.2
    Sidebar UI (Perfected Room Mapping & Display)
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

LocalPlayer.CharacterAdded:Connect(function(char)
    cachedChar = char
end)

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
    if remote:IsA("RemoteEvent") then
        remote:FireServer(...)
        return nil
    end
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
    { Name = "Cheese",  RequiredRebirths = 15 },
    { Name = "Gold",    RequiredRebirths = 10 },
    { Name = "Red",     RequiredRebirths = 5  },
    { Name = "Diamond", RequiredRebirths = 3  },
    { Name = "Silver",  RequiredRebirths = 1  },
    { Name = "Normal",  RequiredRebirths = 0  },
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
-- PER-FEATURE TRACKING (flag-based, mobile-safe)
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
    task.spawn(function()
        fn(function() return featureFlags[key] end)
    end)
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
        [20] = 720,[21] = 800,
    },
    CheeseRooms = {
        [0] = 1,   [1] = 25,  [2] = 50,  [3] = 75,  [4] = 100,
        [5] = 125, [6] = 150, [7] = 175, [8] = 200, [9] = 225,
        [10] = 250,[11] = 275,[12] = 300,[13] = 325,[14] = 365,
        [15] = 400,[16] = 450,[17] = 510,[18] = 575,[19] = 645,
        [20] = 720,[21] = 800,
    }
}

local MAX_ROOM       = 21
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
        if level >= req and room > best then
            best = room
        end
    end
    return best
end

local function stopWinFarm(statusLabel)
    winFarmRunning = false
    if winFarmConn then
        winFarmConn:Disconnect()
        winFarmConn = nil
    end
    cachedWinPart = nil
    cachedRoom    = nil
    if statusLabel then statusLabel.Text = "Status: Idle" end
end

-- ═══════════════════════════════════════
-- THEME
-- ═══════════════════════════════════════
local ACCENT     = Color3.fromRGB(120, 80, 255)
local BG_LIGHT   = Color3.fromRGB(42, 42, 56)
local TEXT_MAIN  = Color3.fromRGB(230, 230, 240)
local TEXT_DIM   = Color3.fromRGB(130, 130, 155)
local GREEN_ON   = Color3.fromRGB(52, 199, 89)
local SWITCH_OFF = Color3.fromRGB(58, 58, 72)
local RED_BTN    = Color3.fromRGB(200, 55, 55)
local GREEN_BTN  = Color3.fromRGB(40, 180, 90)

local function tw(obj, props, t)
    TweenService:Create(
        obj,
        TweenInfo.new(t or 0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        props
    ):Play()
end

-- ═══════════════════════════════════════
-- UI — PrimeX-inspired Wide Layout
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

    -- ─────────────────────────────────────
    -- TOAST
    -- ─────────────────────────────────────
    local toastQueue = {}
    local toastBusy  = false

    local toastHolder = Instance.new("Frame")
    toastHolder.Size = UDim2.new(0, 240, 0, 36)
    toastHolder.AnchorPoint = Vector2.new(0.5, 1)
    toastHolder.Position = UDim2.new(0.5, 0, 1, -20)
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
                pill.BackgroundColor3 = item.good and Color3.fromRGB(24,52,34) or Color3.fromRGB(52,22,22)
                pill.BackgroundTransparency = 0.08
                pill.BorderSizePixel = 0
                pill.ZIndex = 50
                pill.Parent = toastHolder
                Instance.new("UICorner", pill).CornerRadius = UDim.new(0, 8)
                local stroke = Instance.new("UIStroke")
                stroke.Color = item.good and GREEN_ON or RED_BTN
                stroke.Thickness = 1; stroke.Transparency = 0.4
                stroke.Parent = pill
                local dot = Instance.new("Frame")
                dot.Size = UDim2.new(0, 7, 0, 7)
                dot.Position = UDim2.new(0, 10, 0.5, -3)
                dot.BackgroundColor3 = item.good and GREEN_ON or RED_BTN
                dot.BorderSizePixel = 0; dot.ZIndex = 51
                dot.Parent = pill
                Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
                local lbl = Instance.new("TextLabel")
                lbl.Size = UDim2.new(1, -26, 1, 0)
                lbl.Position = UDim2.new(0, 24, 0, 0)
                lbl.BackgroundTransparency = 1
                lbl.Font = Enum.Font.GothamBold; lbl.TextSize = 12
                lbl.TextColor3 = TEXT_MAIN
                lbl.TextXAlignment = Enum.TextXAlignment.Left
                lbl.Text = item.msg; lbl.ZIndex = 51
                lbl.Parent = pill
                tw(pill, { Position = UDim2.new(0, 0, 0, 0) }, 0.2)
                task.wait(2.0)
                tw(pill, { BackgroundTransparency = 1 }, 0.25)
                tw(lbl,  { TextTransparency = 1 }, 0.25)
                tw(dot,  { BackgroundTransparency = 1 }, 0.25)
                task.wait(0.3)
                pill:Destroy(); task.wait(0.06)
            end
            toastBusy = false
        end)
    end

    -- ─────────────────────────────────────
    -- MINIMIZE PILL
    -- ─────────────────────────────────────
    local minPill = Instance.new("TextButton")
    minPill.Name = "MinPill"
    minPill.Size = UDim2.new(0, 150, 0, 32)
    minPill.Position = UDim2.new(0.5, -75, 0, -40)
    minPill.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
    minPill.BorderSizePixel = 0
    minPill.Text = ""
    minPill.Visible = false
    minPill.ZIndex = 50
    minPill.Parent = screenGui
    Instance.new("UICorner", minPill).CornerRadius = UDim.new(1, 0)

    local minPillStroke = Instance.new("UIStroke")
    minPillStroke.Color = ACCENT
    minPillStroke.Thickness = 1
    minPillStroke.Transparency = 0.4
    minPillStroke.Parent = minPill

    local minPillIcon = Instance.new("TextLabel")
    minPillIcon.BackgroundTransparency = 1
    minPillIcon.Size = UDim2.new(0, 20, 1, 0)
    minPillIcon.Position = UDim2.new(0, 12, 0, 0)
    minPillIcon.Font = Enum.Font.GothamBold
    minPillIcon.Text = "+"
    minPillIcon.TextColor3 = ACCENT
    minPillIcon.TextSize = 15
    minPillIcon.Parent = minPill

    local minPillText = Instance.new("TextLabel")
    minPillText.BackgroundTransparency = 1
    minPillText.Size = UDim2.new(1, -40, 1, 0)
    minPillText.Position = UDim2.new(0, 36, 0, 0)
    minPillText.Font = Enum.Font.GothamBold
    minPillText.Text = "Open 7zxy Hub"
    minPillText.TextColor3 = TEXT_MAIN
    minPillText.TextSize = 12
    minPillText.TextXAlignment = Enum.TextXAlignment.Left
    minPillText.Parent = minPill

    -- ─────────────────────────────────────
    -- LAYOUT CONSTANTS
    -- ─────────────────────────────────────
    local W         = 560
    local H         = 340
    local TITLE_H   = 32
    local SIDEBAR_W = 160
    local isMin     = false

    -- ─────────────────────────────────────
    -- MAIN FRAME
    -- ─────────────────────────────────────
    local main = Instance.new("Frame")
    main.Name = "Main"
    main.Size = UDim2.new(0, W, 0, H)
    main.Position = UDim2.new(0.5, -W/2, 0.5, -H/2)
    main.BackgroundColor3 = Color3.fromRGB(22, 22, 26)
    main.BorderSizePixel = 0
    main.Active = true
    main.ClipsDescendants = true
    main.Parent = screenGui
    Instance.new("UICorner", main).CornerRadius = UDim.new(0, 10)

    local mainStroke = Instance.new("UIStroke")
    mainStroke.Color = Color3.fromRGB(55, 55, 68)
    mainStroke.Thickness = 1
    mainStroke.Transparency = 0.3
    mainStroke.Parent = main

    -- ─────────────────────────────────────
    -- TITLE BAR
    -- ─────────────────────────────────────
    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, TITLE_H)
    titleBar.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
    titleBar.BorderSizePixel = 0
    titleBar.ZIndex = 6
    titleBar.Parent = main
    Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 10)

    local function makeDot(xOff, col)
        local d = Instance.new("Frame")
        d.Size = UDim2.new(0, 11, 0, 11)
        d.Position = UDim2.new(0, xOff, 0.5, -5)
        d.BackgroundColor3 = col
        d.BorderSizePixel = 0; d.ZIndex = 7
        d.Parent = titleBar
        Instance.new("UICorner", d).CornerRadius = UDim.new(1, 0)
        return d
    end

    local dotClose    = makeDot(12, Color3.fromRGB(255, 95, 86))
    local dotMinimize = makeDot(28, Color3.fromRGB(255, 189, 46))
    local dotMaximize = makeDot(44, Color3.fromRGB(39, 201, 63))

    local function makeDotBtn(dot)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, 0, 1, 0)
        b.BackgroundTransparency = 1; b.Text = ""; b.ZIndex = 8
        b.Parent = dot; return b
    end

    local closeBtn    = makeDotBtn(dotClose)
    local minimizeBtn = makeDotBtn(dotMinimize)
    local maximizeBtn = makeDotBtn(dotMaximize)

    local hubLabel = Instance.new("TextLabel")
    hubLabel.BackgroundTransparency = 1
    hubLabel.Size = UDim2.new(1, -75, 1, 0)
    hubLabel.Position = UDim2.new(0, 65, 0, 0)
    hubLabel.Font = Enum.Font.GothamBold
    hubLabel.Text = "7zxy Hub | Auto Farm | by 7zxy"
    hubLabel.TextColor3 = Color3.fromRGB(195, 195, 210)
    hubLabel.TextSize = 11
    hubLabel.TextXAlignment = Enum.TextXAlignment.Left
    hubLabel.ZIndex = 7
    hubLabel.Parent = titleBar

    -- ─────────────────────────────────────
    -- SIDEBAR
    -- ─────────────────────────────────────
    local sidebar = Instance.new("Frame")
    sidebar.Size = UDim2.new(0, SIDEBAR_W, 1, -TITLE_H)
    sidebar.Position = UDim2.new(0, 0, 0, TITLE_H)
    sidebar.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
    sidebar.BorderSizePixel = 0; sidebar.ZIndex = 4
    sidebar.Parent = main

    local sideList = Instance.new("UIListLayout")
    sideList.Padding = UDim.new(0, 4)
    sideList.SortOrder = Enum.SortOrder.LayoutOrder
    sideList.Parent = sidebar

    local sidePad = Instance.new("UIPadding")
    sidePad.PaddingTop  = UDim.new(0, 10)
    sidePad.PaddingLeft = UDim.new(0, 10)
    sidePad.Parent = sidebar

    local divider = Instance.new("Frame")
    divider.Size = UDim2.new(0, 1, 1, -TITLE_H)
    divider.Position = UDim2.new(0, SIDEBAR_W, 0, TITLE_H)
    divider.BackgroundColor3 = Color3.fromRGB(48, 48, 60)
    divider.BorderSizePixel = 0; divider.ZIndex = 5
    divider.Parent = main

    local sideStatus = Instance.new("TextLabel")
    sideStatus.Size = UDim2.new(1, -10, 0, 28)
    sideStatus.Position = UDim2.new(0, 0, 1, -30)
    sideStatus.BackgroundTransparency = 1
    sideStatus.Font = Enum.Font.Gotham
    sideStatus.Text = "Lv-- | R--"
    sideStatus.TextColor3 = ACCENT
    sideStatus.TextSize = 11
    sideStatus.TextXAlignment = Enum.TextXAlignment.Left
    sideStatus.ZIndex = 5
    sideStatus.Parent = sidebar

    local stopAllBtn = Instance.new("TextButton")
    stopAllBtn.Size = UDim2.new(1, -10, 0, 24)
    stopAllBtn.Position = UDim2.new(0, 0, 1, -60)
    stopAllBtn.BackgroundColor3 = RED_BTN
    stopAllBtn.Text = "Stop All"
    stopAllBtn.Font = Enum.Font.GothamBold
    stopAllBtn.TextSize = 11
    stopAllBtn.TextColor3 = Color3.new(1,1,1)
    stopAllBtn.BorderSizePixel = 0; stopAllBtn.ZIndex = 5
    stopAllBtn.Parent = sidebar
    Instance.new("UICorner", stopAllBtn).CornerRadius = UDim.new(0, 4)

    -- ─────────────────────────────────────
    -- SEARCH BAR
    -- ─────────────────────────────────────
    local searchBar = Instance.new("Frame")
    searchBar.Size = UDim2.new(1, -10, 0, 28)
    searchBar.BackgroundColor3 = Color3.fromRGB(32, 32, 40)
    searchBar.BorderSizePixel = 0; searchBar.ZIndex = 5
    searchBar.LayoutOrder = 0
    searchBar.Parent = sidebar
    Instance.new("UICorner", searchBar).CornerRadius = UDim.new(0, 6)

    local searchQ = Instance.new("TextLabel")
    searchQ.BackgroundTransparency = 1
    searchQ.Size = UDim2.new(0, 24, 1, 0)
    searchQ.Position = UDim2.new(0, 2, 0, 0)
    searchQ.Font = Enum.Font.Gotham; searchQ.Text = "O"
    searchQ.TextColor3 = TEXT_DIM; searchQ.TextSize = 12; searchQ.ZIndex = 6
    searchQ.Parent = searchBar

    local searchBox = Instance.new("TextBox")
    searchBox.Size = UDim2.new(1, -26, 1, 0)
    searchBox.Position = UDim2.new(0, 24, 0, 0)
    searchBox.BackgroundTransparency = 1
    searchBox.Font = Enum.Font.Gotham; searchBox.TextSize = 12
    searchBox.TextColor3 = TEXT_MAIN
    searchBox.PlaceholderText = "Search"
    searchBox.PlaceholderColor3 = TEXT_DIM
    searchBox.Text = ""; searchBox.ClearTextOnFocus = false
    searchBox.ZIndex = 6; searchBox.TextXAlignment = Enum.TextXAlignment.Left
    searchBox.Parent = searchBar

    -- ─────────────────────────────────────
    -- CONTENT PANEL
    -- ─────────────────────────────────────
    local contentPanel = Instance.new("Frame")
    contentPanel.Size = UDim2.new(1, -(SIDEBAR_W + 1), 1, -TITLE_H)
    contentPanel.Position = UDim2.new(0, SIDEBAR_W + 1, 0, TITLE_H)
    contentPanel.BackgroundTransparency = 1
    contentPanel.ClipsDescendants = true; contentPanel.ZIndex = 4
    contentPanel.Parent = main

    local featureScroll = Instance.new("ScrollingFrame")
    featureScroll.Size = UDim2.new(1, 0, 1, 0)
    featureScroll.Position = UDim2.new(0, 0, 0, 0)
    featureScroll.BackgroundTransparency = 1
    featureScroll.BorderSizePixel = 0
    featureScroll.ScrollBarThickness = 3
    featureScroll.ScrollBarImageColor3 = ACCENT
    featureScroll.CanvasSize = UDim2.new(0, 0, 0, 500)
    pcall(function() featureScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y end)
    featureScroll.ZIndex = 5; featureScroll.Parent = contentPanel

    local featList = Instance.new("UIListLayout")
    featList.Padding = UDim.new(0, 4)
    featList.SortOrder = Enum.SortOrder.LayoutOrder
    featList.Parent = featureScroll

    local featPad = Instance.new("UIPadding")
    featPad.PaddingTop  = UDim.new(0, 12)
    featPad.PaddingLeft = UDim.new(0, 12)
    featPad.PaddingRight = UDim.new(0, 16)
    featPad.Parent = featureScroll

    -- ─────────────────────────────────────
    -- NAV + PAGE SYSTEM
    -- ─────────────────────────────────────
    local navItems   = {}
    local allRows    = {}
    local afToggles  = {}
    local activeNav  = "main"
    local activeFeatures = {}

    local function refreshStatus()
        local stats = currentData and currentData.Stats
        if stats then
            sideStatus.Text = string.format("Lv%d | R%d", stats.Level or 0, stats.Rebirths or 0)
        end
    end

    task.spawn(function()
        while screenGui.Parent do refreshStatus(); task.wait(2) end
    end)

    local pages = {
        main     = {"auto press","auto rebirth","auto spin","auto claim","anti-afk"},
        movement = {"speed boost","noclip","walk speed"},
        winfarm  = "_custom_",
        settings = {"walk speed"},
        about    = "_custom_"
    }

    local wfRows    = {}
    local aboutRows = {}

    local function showPageRaw(name)
        activeNav = name
        searchBox.Text = ""
        for _, r in pairs(allRows) do r.row.Visible = false end
        for _, r in pairs(wfRows) do r.Visible = false end
        for _, r in pairs(aboutRows) do r.Visible = false end

        if name == "winfarm" then
            for _, r in pairs(wfRows) do r.Visible = true end
            return
        end
        if name == "about" then
            for _, r in pairs(aboutRows) do r.Visible = true end
            return
        end
        
        local keys = pages[name] or {}
        for _, key in ipairs(keys) do
            for _, r in pairs(allRows) do
                if r.label == key then r.row.Visible = true end
            end
        end
    end

    local function activateNav(name)
        for pname, ni in pairs(navItems) do
            tw(ni.icon, { TextColor3 = TEXT_DIM }, 0.15)
            tw(ni.text, { TextColor3 = TEXT_DIM }, 0.15)
            tw(ni.pill, { BackgroundTransparency = 1 }, 0.15)
        end
        local ni = navItems[name]
        if ni then
            tw(ni.icon, { TextColor3 = ACCENT }, 0.15)
            tw(ni.text, { TextColor3 = TEXT_MAIN }, 0.15)
            tw(ni.pill, { BackgroundTransparency = 0 }, 0.15)
        end
        showPageRaw(name)
    end

    local function makeSideBtn(order, icon, label, pageName)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -10, 0, 30)
        btn.BackgroundTransparency = 1; btn.Text = ""
        btn.LayoutOrder = order; btn.BorderSizePixel = 0; btn.ZIndex = 5
        btn.Parent = sidebar

        local pill = Instance.new("Frame")
        pill.Size = UDim2.new(0, 3, 0, 16)
        pill.Position = UDim2.new(0, -10, 0.5, -8)
        pill.BackgroundColor3 = ACCENT
        pill.BackgroundTransparency = 1
        pill.BorderSizePixel = 0; pill.ZIndex = 6
        pill.Parent = btn
        Instance.new("UICorner", pill).CornerRadius = UDim.new(1, 0)

        local iLbl = Instance.new("TextLabel")
        iLbl.BackgroundTransparency = 1
        iLbl.Size = UDim2.new(0, 16, 1, 0); iLbl.Position = UDim2.new(0, 4, 0, 0)
        iLbl.Font = Enum.Font.Gotham; iLbl.Text = icon
        iLbl.TextSize = 13; iLbl.TextColor3 = TEXT_DIM; iLbl.ZIndex = 6
        iLbl.Parent = btn

        local tLbl = Instance.new("TextLabel")
        tLbl.BackgroundTransparency = 1
        tLbl.Size = UDim2.new(1, -24, 1, 0); tLbl.Position = UDim2.new(0, 24, 0, 0)
        tLbl.Font = Enum.Font.Gotham; tLbl.Text = label
        tLbl.TextSize = 13; tLbl.TextColor3 = TEXT_DIM
        tLbl.TextXAlignment = Enum.TextXAlignment.Left; tLbl.ZIndex = 6
        tLbl.Parent = btn

        navItems[pageName] = { btn = btn, icon = iLbl, text = tLbl, pill = pill }
        btn.MouseButton1Click:Connect(function() activateNav(pageName) end)
    end

    makeSideBtn(1, "o", "Main",     "main")
    makeSideBtn(2, "-", "Movement", "movement")
    makeSideBtn(3, "*", "Win Farm", "winfarm")
    makeSideBtn(4, "=", "Settings", "settings")
    makeSideBtn(5, "i", "About Us", "about")

    -- ─────────────────────────────────────
    -- TOGGLE ROW BUILDER
    -- ─────────────────────────────────────
    local function makeToggleRow(order, labelText, configKey, featureName, starter)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 36)
        row.BackgroundTransparency = 1
        row.LayoutOrder = order; row.ZIndex = 5
        row.Parent = featureScroll

        local lbl = Instance.new("TextLabel")
        lbl.BackgroundTransparency = 1
        lbl.Size = UDim2.new(1, -54, 1, 0)
        lbl.Font = Enum.Font.Gotham; lbl.Text = labelText
        lbl.TextSize = 13; lbl.TextColor3 = TEXT_MAIN
        lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.ZIndex = 6
        lbl.Parent = row

        local sw = Instance.new("Frame")
        sw.Size = UDim2.new(0, 38, 0, 20)
        sw.Position = UDim2.new(1, -40, 0.5, -10)
        sw.BackgroundColor3 = Config[configKey] and GREEN_ON or SWITCH_OFF
        sw.BorderSizePixel = 0; sw.ZIndex = 6
        sw.Parent = row
        Instance.new("UICorner", sw).CornerRadius = UDim.new(1, 0)

        local knob = Instance.new("Frame")
        knob.Size = UDim2.new(0, 16, 0, 16)
        knob.Position = Config[configKey] and UDim2.new(1,-18,0.5,-8) or UDim2.new(0,2,0.5,-8)
        knob.BackgroundColor3 = Color3.new(1,1,1)
        knob.BorderSizePixel = 0; knob.ZIndex = 7
        knob.Parent = sw
        Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

        local clickBtn = Instance.new("TextButton")
        clickBtn.Size = UDim2.new(1,0,1,0); clickBtn.BackgroundTransparency = 1
        clickBtn.Text = ""; clickBtn.ZIndex = 8; clickBtn.Parent = sw

        clickBtn.MouseButton1Click:Connect(function()
            local newState = not Config[configKey]
            Config[configKey] = newState
            tw(sw, { BackgroundColor3 = newState and GREEN_ON or SWITCH_OFF }, 0.15)
            knob:TweenPosition(
                newState and UDim2.new(1,-18,0.5,-8) or UDim2.new(0,2,0.5,-8),
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
        table.insert(allRows, { row = row, label = labelText:lower() })

        if Config[configKey] and starter then
            activeFeatures[featureName] = true
            starter()
        end
    end

    makeToggleRow(1, "Auto Press",   "AutoPress",   "Auto Press",   startAutoPress)
    makeToggleRow(2, "Auto Rebirth", "AutoRebirth", "Auto Rebirth", startAutoRebirth)
    makeToggleRow(3, "Auto Spin",    "AutoSpin",    "Auto Spin",    startAutoSpin)
    makeToggleRow(4, "Auto Claim",   "AutoClaim",   "Auto Claim",   startAutoClaim)
    makeToggleRow(5, "Speed Boost",  "SpeedBoost",  "Speed Boost",  startSpeedBoost)
    makeToggleRow(6, "Noclip",       "Noclip",      "Noclip",       startNoclip)
    makeToggleRow(7, "Anti-AFK",     "AntiAFK",     "Anti-AFK",     startAntiAFK)

    -- Walk Speed row
    local wsRow = Instance.new("Frame")
    wsRow.Size = UDim2.new(1, 0, 0, 36); wsRow.BackgroundTransparency = 1
    wsRow.LayoutOrder = 8; wsRow.ZIndex = 5; wsRow.Parent = featureScroll

    local wsLbl = Instance.new("TextLabel")
    wsLbl.BackgroundTransparency = 1; wsLbl.Size = UDim2.new(1,-70,1,0)
    wsLbl.Font = Enum.Font.Gotham; wsLbl.Text = "Walk Speed"
    wsLbl.TextSize = 13; wsLbl.TextColor3 = TEXT_MAIN
    wsLbl.TextXAlignment = Enum.TextXAlignment.Left; wsLbl.ZIndex = 6
    wsLbl.Parent = wsRow

    local wsBox = Instance.new("TextBox")
    wsBox.Size = UDim2.new(0, 60, 0, 24)
    wsBox.Position = UDim2.new(1, -62, 0.5, -12)
    wsBox.BackgroundColor3 = Color3.fromRGB(32, 32, 40)
    wsBox.TextColor3 = TEXT_MAIN; wsBox.Font = Enum.Font.GothamBold
    wsBox.TextSize = 13; wsBox.Text = tostring(Config.WalkSpeed)
    wsBox.PlaceholderText = "200"; wsBox.BorderSizePixel = 0
    wsBox.ClearTextOnFocus = false; wsBox.ZIndex = 6
    wsBox.Parent = wsRow
    Instance.new("UICorner", wsBox).CornerRadius = UDim.new(0, 5)
    local wsStroke = Instance.new("UIStroke")
    wsStroke.Color = ACCENT; wsStroke.Thickness = 1; wsStroke.Transparency = 0.6
    wsStroke.Parent = wsBox

    wsBox.FocusLost:Connect(function()
        local val = tonumber(wsBox.Text)
        if val and val > 0 and val <= 10000 then
            Config.WalkSpeed = val
            showToast("Speed set to " .. val, true)
        else
            wsBox.Text = tostring(Config.WalkSpeed)
        end
    end)

    table.insert(allRows, { row = wsRow, label = "walk speed" })

    -- ─────────────────────────────────────
    -- WIN FARM ROWS
    -- ─────────────────────────────────────
    local function makeWFRow(h)
        local r = Instance.new("Frame")
        r.Size = UDim2.new(1, 0, 0, h)
        r.BackgroundTransparency = 1
        r.LayoutOrder = #wfRows + 9; r.Visible = false; r.ZIndex = 5
        r.Parent = featureScroll
        table.insert(wfRows, r)
        return r
    end

    local wfInfoRow = makeWFRow(36)
    local infoLabel = Instance.new("TextLabel")
    infoLabel.BackgroundTransparency = 1; infoLabel.Size = UDim2.new(1,0,0.55,0)
    infoLabel.Font = Enum.Font.GothamBold; infoLabel.Text = "Level: --  |  Room: --"
    infoLabel.TextSize = 12; infoLabel.TextColor3 = TEXT_MAIN
    infoLabel.TextXAlignment = Enum.TextXAlignment.Left; infoLabel.ZIndex = 6
    infoLabel.Parent = wfInfoRow

    local progressBg = Instance.new("Frame")
    progressBg.Size = UDim2.new(1,0,0,6); progressBg.Position = UDim2.new(0,0,1,-8)
    progressBg.BackgroundColor3 = Color3.fromRGB(40,40,52); progressBg.BorderSizePixel = 0
    progressBg.ZIndex = 6; progressBg.Parent = wfInfoRow
    Instance.new("UICorner", progressBg).CornerRadius = UDim.new(1,0)

    local progressFill = Instance.new("Frame")
    progressFill.Size = UDim2.new(0,0,1,0); progressFill.BackgroundColor3 = ACCENT
    progressFill.BorderSizePixel = 0; progressFill.ZIndex = 7; progressFill.Parent = progressBg
    Instance.new("UICorner", progressFill).CornerRadius = UDim.new(1,0)

    local wfWorldRow = makeWFRow(32)
    local normalBtn = Instance.new("TextButton")
    normalBtn.Size = UDim2.new(0.5,-4,1,0); normalBtn.BackgroundColor3 = ACCENT
    normalBtn.Text = "Normal"; normalBtn.TextColor3 = Color3.new(1,1,1)
    normalBtn.Font = Enum.Font.GothamBold; normalBtn.TextSize = 12
    normalBtn.BorderSizePixel = 0; normalBtn.ZIndex = 6; normalBtn.Parent = wfWorldRow
    Instance.new("UICorner", normalBtn).CornerRadius = UDim.new(0, 6)

    local cheeseBtn = Instance.new("TextButton")
    cheeseBtn.Size = UDim2.new(0.5,-4,1,0); cheeseBtn.Position = UDim2.new(0.5,4,0,0)
    cheeseBtn.BackgroundColor3 = BG_LIGHT; cheeseBtn.Text = "Cheese"
    cheeseBtn.TextColor3 = Color3.new(1,1,1); cheeseBtn.Font = Enum.Font.GothamBold
    cheeseBtn.TextSize = 12; cheeseBtn.BorderSizePixel = 0; cheeseBtn.ZIndex = 6
    cheeseBtn.Parent = wfWorldRow
    Instance.new("UICorner", cheeseBtn).CornerRadius = UDim.new(0, 6)

    local wfBtnRow = makeWFRow(32)
    local wfStartBtn = Instance.new("TextButton")
    wfStartBtn.Size = UDim2.new(0.5,-4,1,0); wfStartBtn.BackgroundColor3 = GREEN_BTN
    wfStartBtn.Text = "Start"; wfStartBtn.TextColor3 = Color3.new(1,1,1)
    wfStartBtn.Font = Enum.Font.GothamBold; wfStartBtn.TextSize = 12
    wfStartBtn.BorderSizePixel = 0; wfStartBtn.ZIndex = 6; wfStartBtn.Parent = wfBtnRow
    Instance.new("UICorner", wfStartBtn).CornerRadius = UDim.new(0, 6)

    local wfStopBtn = Instance.new("TextButton")
    wfStopBtn.Size = UDim2.new(0.5,-4,1,0); wfStopBtn.Position = UDim2.new(0.5,4,0,0)
    wfStopBtn.BackgroundColor3 = RED_BTN; wfStopBtn.Text = "Stop"
    wfStopBtn.TextColor3 = Color3.new(1,1,1); wfStopBtn.Font = Enum.Font.GothamBold
    wfStopBtn.TextSize = 12; wfStopBtn.BorderSizePixel = 0; wfStopBtn.ZIndex = 6
    wfStopBtn.Parent = wfBtnRow
    Instance.new("UICorner", wfStopBtn).CornerRadius = UDim.new(0, 6)

    local wfStatusRow = makeWFRow(26)
    local wfStatus = Instance.new("TextLabel")
    wfStatus.BackgroundTransparency = 1; wfStatus.Size = UDim2.new(1,0,1,0)
    wfStatus.Font = Enum.Font.Gotham; wfStatus.Text = "Status: Idle"
    wfStatus.TextColor3 = TEXT_DIM; wfStatus.TextSize = 12
    wfStatus.TextXAlignment = Enum.TextXAlignment.Left; wfStatus.ZIndex = 6
    wfStatus.Parent = wfStatusRow

    local function updateProgress(level, room, world)
        local world_data = ROOM_LEVELS[world] or ROOM_LEVELS["Rooms"]
        local curReq  = world_data[room] or 0
        local nextReq = world_data[room + 1]
        
        local displayRoom = room + 1 -- folder 0 = room 1, folder 1 = room 2, etc.
        
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
        cachedWinPart  = nil
        cachedRoom     = nil
        lastStatsCheck = 0
        wfStatus.Text = "Farming " .. selectedWorld .. "..."
        showToast("Win Farm started", true)

        winFarmConn = RunService.Heartbeat:Connect(function()
            if not winFarmRunning then return end

            local now = os.clock()
            if now - lastStatsCheck > 1 then
                lastStatsCheck = now
                local stats = currentData and currentData.Stats
                local container = Workspace:FindFirstChild(selectedWorld)

                if stats and container then
                    local level = stats.Level or 1
                    local room = getRoomForLevel(level, selectedWorld)
                    
                    updateProgress(level, room, selectedWorld)

                    if room ~= cachedRoom then
                        cachedRoom = room
                        local targetRoom = container:FindFirstChild(tostring(room))
                        cachedWinPart = targetRoom and targetRoom:FindFirstChild("Win")
                    end

                    wfStatus.Text = cachedWinPart
                        and ("Farming " .. selectedWorld .. " room " .. (room + 1))
                        or ("Room " .. (room + 1) .. " not found")
                elseif not container then
                    wfStatus.Text = selectedWorld .. " not found!"
                    cachedWinPart = nil
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

    local function setWorld(world)
        cachedWinPart = nil; cachedRoom = nil; selectedWorld = world
        tw(normalBtn, { BackgroundColor3 = world == "Rooms" and ACCENT or BG_LIGHT }, 0.15)
        tw(cheeseBtn, { BackgroundColor3 = world == "CheeseRooms" and Color3.fromRGB(200,145,0) or BG_LIGHT }, 0.15)
    end

    normalBtn.MouseButton1Click:Connect(function() setWorld("Rooms") end)
    cheeseBtn.MouseButton1Click:Connect(function() setWorld("CheeseRooms") end)
    wfStartBtn.MouseButton1Click:Connect(startWinFarm)
    wfStopBtn.MouseButton1Click:Connect(function()
        stopWinFarm(wfStatus); showToast("Win Farm stopped", false)
    end)

    -- ─────────────────────────────────────
    -- ABOUT ROWS
    -- ─────────────────────────────────────
    local function makeAboutRow(h)
        local r = Instance.new("Frame")
        r.Size = UDim2.new(1, 0, 0, h)
        r.BackgroundTransparency = 1
        r.LayoutOrder = #aboutRows + 30; r.Visible = false; r.ZIndex = 5
        r.Parent = featureScroll
        table.insert(aboutRows, r)
        return r
    end

    local aboutTitle = makeAboutRow(40)
    local abtLabel = Instance.new("TextLabel")
    abtLabel.BackgroundTransparency = 1
    abtLabel.Size = UDim2.new(1, 0, 1, 0)
    abtLabel.Font = Enum.Font.GothamBold
    abtLabel.Text = "7zxy Hub"
    abtLabel.TextSize = 18
    abtLabel.TextColor3 = TEXT_MAIN
    abtLabel.TextXAlignment = Enum.TextXAlignment.Center
    abtLabel.ZIndex = 6
    abtLabel.Parent = aboutTitle

    local aboutCredit = makeAboutRow(24)
    local crLabel = Instance.new("TextLabel")
    crLabel.BackgroundTransparency = 1
    crLabel.Size = UDim2.new(1, 0, 1, 0)
    crLabel.Font = Enum.Font.Gotham
    crLabel.Text = "Script Auto Farm - by 7zxy"
    crLabel.TextSize = 12
    crLabel.TextColor3 = TEXT_DIM
    crLabel.TextXAlignment = Enum.TextXAlignment.Center
    crLabel.ZIndex = 6
    crLabel.Parent = aboutCredit

    local aboutDiscord = makeAboutRow(40)
    local dscBtn = Instance.new("TextButton")
    dscBtn.Size = UDim2.new(1, 0, 1, -8)
    dscBtn.Position = UDim2.new(0, 0, 0, 4)
    dscBtn.BackgroundColor3 = ACCENT
    dscBtn.Text = "Join Discord Server"
    dscBtn.TextColor3 = Color3.new(1,1,1)
    dscBtn.Font = Enum.Font.GothamBold
    dscBtn.TextSize = 13
    dscBtn.BorderSizePixel = 0
    dscBtn.ZIndex = 6
    dscBtn.Parent = aboutDiscord
    Instance.new("UICorner", dscBtn).CornerRadius = UDim.new(0, 6)

    dscBtn.MouseButton1Click:Connect(function()
        if setclipboard then
            pcall(function() setclipboard("https://discord.gg/8mte25S8E") end)
            showToast("Copied Discord to clipboard!", true)
        else
            showToast("Clipboard not supported here", false)
        end
    end)


    -- ─────────────────────────────────────
    -- STOP ALL
    -- ─────────────────────────────────────
    stopAllBtn.MouseButton1Click:Connect(function()
        _G.StopExploit()
        for _, t in pairs(afToggles) do
            tw(t.sw, { BackgroundColor3 = SWITCH_OFF }, 0.15)
            t.knob.Position = UDim2.new(0, 2, 0.5, -8)
        end
        table.clear(activeFeatures)
        showToast("- All stopped", false)
    end)

    -- ─────────────────────────────────────
    -- SEARCH FILTER
    -- ─────────────────────────────────────
    searchBox:GetPropertyChangedSignal("Text"):Connect(function()
        local q = searchBox.Text:lower()
        if q == "" then showPageRaw(activeNav); return end
        for _, r in pairs(allRows) do
            r.row.Visible = r.label:find(q, 1, true) ~= nil
        end
        for _, r in pairs(wfRows) do r.Visible = false end
        for _, r in pairs(aboutRows) do r.Visible = false end
    end)

    -- ─────────────────────────────────────
    -- MINIMIZE CONTROLS (PILL)
    -- ─────────────────────────────────────
    minimizeBtn.MouseButton1Click:Connect(function()
        if not isMin then
            isMin = true
            main.Visible = false
            
            minPill.Visible = true
            minPill.Position = UDim2.new(0.5, -75, 0, -40)
            tw(minPill, { Position = UDim2.new(0.5, -75, 0, 20) }, 0.3)
        end
    end)

    minPill.MouseButton1Click:Connect(function()
        if isMin then
            isMin = false
            tw(minPill, { Position = UDim2.new(0.5, -75, 0, -40) }, 0.3)
            task.wait(0.2)
            minPill.Visible = false
            main.Visible = true
        end
    end)

    -- ─────────────────────────────────────
    -- WINDOW CONTROLS
    -- ─────────────────────────────────────
    closeBtn.MouseButton1Click:Connect(function()
        _G.StopExploit()
        tw(main, { BackgroundTransparency = 1 }, 0.15)
        task.wait(0.18); screenGui:Destroy()
    end)

    local maximized = false
    local prevSize = main.Size
    local prevPos  = main.Position

    maximizeBtn.MouseButton1Click:Connect(function()
        if isMin then return end
        if not maximized then
            maximized = true
            prevSize = main.Size; prevPos = main.Position
            tw(main, { Size = UDim2.new(0, W, 1, -40), Position = UDim2.new(0.5, -W/2, 0, 20) }, 0.2)
        else
            maximized = false
            tw(main, { Size = prevSize, Position = prevPos }, 0.2)
        end
    end)

    -- ─────────────────────────────────────
    -- KEYBIND (mobile-safe)
    -- ─────────────────────────────────────
    pcall(function()
        UserInputService.InputBegan:Connect(function(input, gp)
            if gp then return end
            if input.KeyCode == Enum.KeyCode.RightShift then
                if isMin then
                    isMin = false
                    tw(minPill, { Position = UDim2.new(0.5, -75, 0, -40) }, 0.3)
                    task.wait(0.2)
                    minPill.Visible = false
                    main.Visible = true
                else
                    main.Visible = not main.Visible
                end
            end
        end)
    end)

    -- ─────────────────────────────────────
    -- DRAGGING
    -- ─────────────────────────────────────
    local dragging, dragStart, startPos = false, nil, nil

    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = input.Position; startPos = main.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)

    titleBar.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - dragStart
            main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
                                      startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)

    -- ─────────────────────────────────────
    -- BOOT
    -- ─────────────────────────────────────
    activateNav("main")

    return screenGui
end

-- ═══════════════════════════════════════
-- INITIALIZATION
-- ═══════════════════════════════════════
setupDataListener()
task.wait(1)
createUI()

print("[7zxy Hub] v1.7.2 loaded — Perfected Win Farm mapping. RightShift to toggle.")
