--[[
    7zxy Hub
    ───────────────────────────────────────
    
]]

-- ═══════════════════════════════════════
-- CONFIGURATION
-- ═══════════════════════════════════════
local Config = {
    AutoPress         = true,
    AutoRebirth       = true,
    PressCheckDelay   = 0.5,
    RebirthCheckDelay = 0.5,
    SpeedBoost        = true,
    WalkSpeed         = 200,
    Noclip            = true,
    AntiAFK           = true,
    AutoSpin          = true,
    AutoClaim         = true,
}

-- ═══════════════════════════════════════
-- SERVICES & REFERENCES
-- ═══════════════════════════════════════
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualUser       = game:GetService("VirtualUser")
local Workspace         = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Events = ReplicatedStorage:WaitForChild("Events")

local function getCharacter()
    return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
end

local function getHumanoid()
    local char = getCharacter()
    return char and char:FindFirstChildWhichIsA("Humanoid")
end

local function getRootPart()
    local char = getCharacter()
    return char and (char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart)
end

local function fireRemote(name, ...)
    local remote = Events:FindFirstChild(tostring(name))
    if not remote then return nil end
    if remote:IsA("RemoteEvent") then
        remote:FireServer(...)
        return nil
    end
    return remote:InvokeServer(...)
end

-- ═══════════════════════════════════════
-- SHARED PLAYER DATA LISTENER
-- ═══════════════════════════════════════
local currentData = nil

local function setupDataListener()
    local updateRemote = Events:FindFirstChild("UpdatePlayerData")
    if updateRemote then
        updateRemote.OnClientEvent:Connect(function(data)
            currentData = data
        end)
    end
    pcall(function()
        currentData = fireRemote("GetPlayerData")
    end)
end

-- ═══════════════════════════════════════
-- AUTO FARM — GAME CONSTANTS
-- ═══════════════════════════════════════
local BASE_LEVEL_CAP = 25
local LEVEL_CAP_PER_REBIRTH = 25

local PRESS_TIERS = {
    { Name = "Cheese",  RequiredRebirths = 15, Increase = 125 },
    { Name = "Gold",    RequiredRebirths = 10, Increase = 50  },
    { Name = "Red",     RequiredRebirths = 5,  Increase = 15  },
    { Name = "Diamond", RequiredRebirths = 3,  Increase = 7   },
    { Name = "Silver",  RequiredRebirths = 1,  Increase = 3   },
    { Name = "Normal",  RequiredRebirths = 0,  Increase = 1   },
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
                if press then
                    return press, tier
                end
            end
        end
    end
    return nil, nil
end

-- ═══════════════════════════════════════
-- AUTO FARM — FEATURE LOOPS
-- ═══════════════════════════════════════
local running = true
local connections = {}

local function startAutoPress()
    task.spawn(function()
        while running and Config.AutoPress do
            if currentData and currentData.Stats then
                local rebirths = currentData.Stats.Rebirths or 0
                local press, tier = getBestPress(rebirths)
                if press then
                    local mainPart = press:FindFirstChild("Main")
                    local root = getRootPart()
                    if mainPart and root then
                        local dist = (root.Position - mainPart.Position).Magnitude
                        if dist > 15 then
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
    task.spawn(function()
        while running and Config.AutoRebirth do
            if currentData and currentData.Stats then
                local level = currentData.Stats.Level or 0
                local rebirths = currentData.Stats.Rebirths or 0
                local cap = getLevelCap(rebirths)
                if level >= cap then
                    local ok, success = pcall(function()
                        return fireRemote("Rebirth")
                    end)
                    task.wait((ok and success) and 3 or 1)
                end
            end
            task.wait(Config.RebirthCheckDelay)
        end
    end)
end

local function startSpeedBoost()
    table.insert(connections, RunService.Heartbeat:Connect(function()
        if not (running and Config.SpeedBoost) then return end
        local hum = getHumanoid()
        if hum then hum.WalkSpeed = Config.WalkSpeed end
    end))
end

local function startNoclip()
    table.insert(connections, RunService.Stepped:Connect(function()
        if not (running and Config.Noclip) then return end
        local char = LocalPlayer.Character
        if not char then return end
        for _, part in char:GetDescendants() do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    end))
end

local function startAntiAFK()
    table.insert(connections, LocalPlayer.Idled:Connect(function()
        if Config.AntiAFK then
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end
    end))
end

local function startAutoSpin()
    task.spawn(function()
        while running and Config.AutoSpin do
            if currentData and currentData.Stats then
                local spins = currentData.Stats.WheelSpins or 0
                if spins > 0 then
                    pcall(function() fireRemote("WheelSpin") end)
                end
            end
            task.wait(5)
        end
    end)
end

local function startAutoClaim()
    task.spawn(function()
        while running and Config.AutoClaim do
            pcall(function() fireRemote("ClaimPlaytime") end)
            task.wait(30)
        end
    end)
end

_G.StopExploit = function()
    running = false
    for key, value in pairs(Config) do
        if type(value) == "boolean" then
            Config[key] = false
        end
    end
    for _, conn in ipairs(connections) do
        pcall(function() conn:Disconnect() end)
    end
    table.clear(connections)
end
_G.ExploitConfig = Config

-- ═══════════════════════════════════════
-- WIN FARM — ROOM LEVEL MAP (verified)
-- room 19 = 645, not 720
-- ═══════════════════════════════════════
local ROOM_LEVELS = {
    Rooms = {
        [0] = 0,   [1] = 1,   [2] = 25,  [3] = 50,  [4] = 75,
        [5] = 100, [6] = 125, [7] = 150, [8] = 175, [9] = 200,
        [10] = 225,[11] = 250,[12] = 275,[13] = 300,[14] = 365,
        [15] = 400,[16] = 450,[17] = 510,[18] = 575,[19] = 645,
        [20] = 720,[21] = 800,
    },
    CheeseRooms = {
        [0] = 0,   [1] = 1,   [2] = 25,  [3] = 50,  [4] = 75,
        [5] = 100, [6] = 125, [7] = 150, [8] = 175, [9] = 200,
        [10] = 225,[11] = 250,[12] = 275,[13] = 300,[14] = 365,
        [15] = 400,[16] = 450,[17] = 510,[18] = 575,[19] = 645,
        [20] = 720,[21] = 800,
    }
}

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

-- ═══════════════════════════════════════
-- WIN FARM — STATE
-- ═══════════════════════════════════════
local winFarmRunning = false
local selectedWorld  = "Rooms"
local winFarmConn    = nil
local lastStatsCheck = 0
local cachedWinPart  = nil
local cachedRoom     = nil
local toggleOut      = false

local function stopWinFarm(statusLabel)
    winFarmRunning = false
    if winFarmConn then
        winFarmConn:Disconnect()
        winFarmConn = nil
    end
    if statusLabel then statusLabel.Text = "Status: Idle" end
end

local function startWinFarm(infoLabel, statusLabel)
    winFarmRunning = true
    cachedWinPart  = nil
    cachedRoom     = nil
    lastStatsCheck = 0
    statusLabel.Text = "Farming " .. selectedWorld .. "..."

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
                infoLabel.Text = string.format("Level: %s | Room: %d", tostring(level), room)

                if room ~= cachedRoom then
                    cachedRoom = room
                    local targetRoom = container:FindFirstChild(tostring(room))
                    cachedWinPart = targetRoom and targetRoom:FindFirstChild("Win")
                end

                statusLabel.Text = cachedWinPart
                    and ("Farming " .. selectedWorld .. " room " .. room)
                    or ("Room " .. room .. " not found")
            elseif not container then
                statusLabel.Text = selectedWorld .. " not found!"
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

-- ═══════════════════════════════════════
-- UI
-- ═══════════════════════════════════════
local function createUI()
    local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

    local existing = PlayerGui:FindFirstChild("SevenZXYHub")
    if existing then existing:Destroy() end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "SevenZXYHub"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = PlayerGui

    local main = Instance.new("Frame")
    main.Name = "Main"
    main.Size = UDim2.new(0, 260, 0, 320)
    main.Position = UDim2.new(0.5, -130, 0.5, -160)
    main.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    main.BorderSizePixel = 0
    main.Active = true
    main.Parent = screenGui
    Instance.new("UICorner", main).CornerRadius = UDim.new(0, 8)

    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 34)
    titleBar.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    titleBar.BorderSizePixel = 0
    titleBar.Parent = main
    Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 8)

    local titleLabel = Instance.new("TextLabel")
    titleLabel.BackgroundTransparency = 1
    titleLabel.Size = UDim2.new(1, -40, 1, 0)
    titleLabel.Position = UDim2.new(0, 12, 0, 0)
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.Text = "⚡ 7zxy Hub"
    titleLabel.TextColor3 = Color3.new(1, 1, 1)
    titleLabel.TextSize = 14
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = titleBar

    local collapseBtn = Instance.new("TextButton")
    collapseBtn.Size = UDim2.new(0, 26, 0, 26)
    collapseBtn.Position = UDim2.new(1, -30, 0, 4)
    collapseBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    collapseBtn.Text = "-"
    collapseBtn.Font = Enum.Font.GothamBold
    collapseBtn.TextSize = 18
    collapseBtn.TextColor3 = Color3.new(1, 1, 1)
    collapseBtn.Parent = titleBar
    Instance.new("UICorner", collapseBtn).CornerRadius = UDim.new(0, 6)

    local tabBar = Instance.new("Frame")
    tabBar.Size = UDim2.new(1, -10, 0, 30)
    tabBar.Position = UDim2.new(0, 5, 0, 40)
    tabBar.BackgroundTransparency = 1
    tabBar.Parent = main

    local autoFarmTabBtn = Instance.new("TextButton")
    autoFarmTabBtn.Size = UDim2.new(0.5, -2, 1, 0)
    autoFarmTabBtn.Position = UDim2.new(0, 0, 0, 0)
    autoFarmTabBtn.Text = "Auto Farm"
    autoFarmTabBtn.Font = Enum.Font.GothamBold
    autoFarmTabBtn.TextSize = 13
    autoFarmTabBtn.TextColor3 = Color3.new(1, 1, 1)
    autoFarmTabBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 255)
    autoFarmTabBtn.Parent = tabBar
    Instance.new("UICorner", autoFarmTabBtn).CornerRadius = UDim.new(0, 6)

    local winFarmTabBtn = Instance.new("TextButton")
    winFarmTabBtn.Size = UDim2.new(0.5, -2, 1, 0)
    winFarmTabBtn.Position = UDim2.new(0.5, 2, 0, 0)
    winFarmTabBtn.Text = "Win Farm"
    winFarmTabBtn.Font = Enum.Font.GothamBold
    winFarmTabBtn.TextSize = 13
    winFarmTabBtn.TextColor3 = Color3.new(1, 1, 1)
    winFarmTabBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    winFarmTabBtn.Parent = tabBar
    Instance.new("UICorner", winFarmTabBtn).CornerRadius = UDim.new(0, 6)

    local contentHolder = Instance.new("Frame")
    contentHolder.Size = UDim2.new(1, 0, 1, -74)
    contentHolder.Position = UDim2.new(0, 0, 0, 74)
    contentHolder.BackgroundTransparency = 1
    contentHolder.ClipsDescendants = true
    contentHolder.Parent = main

    -- ════════════════════════════════
    -- TAB 1: AUTO FARM
    -- ════════════════════════════════
    local autoFarmTab = Instance.new("Frame")
    autoFarmTab.Size = UDim2.new(1, 0, 1, 0)
    autoFarmTab.BackgroundTransparency = 1
    autoFarmTab.Visible = true
    autoFarmTab.Parent = contentHolder

    local afLayout = Instance.new("UIListLayout")
    afLayout.Padding = UDim.new(0, 6)
    afLayout.SortOrder = Enum.SortOrder.LayoutOrder
    afLayout.Parent = autoFarmTab

    local afPadding = Instance.new("UIPadding")
    afPadding.PaddingTop = UDim.new(0, 6)
    afPadding.PaddingLeft = UDim.new(0, 10)
    afPadding.PaddingRight = UDim.new(0, 10)
    afPadding.Parent = autoFarmTab

    local afToggles = {}

    local function makeToggleRow(parent, order, labelText, configKey, onToggle)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 28)
        row.BackgroundTransparency = 1
        row.LayoutOrder = order
        row.Parent = parent

        local label = Instance.new("TextLabel")
        label.BackgroundTransparency = 1
        label.Size = UDim2.new(1, -54, 1, 0)
        label.Font = Enum.Font.Gotham
        label.Text = labelText
        label.TextSize = 13
        label.TextColor3 = Color3.fromRGB(220, 220, 220)
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = row

        local switch = Instance.new("Frame")
        switch.Size = UDim2.new(0, 44, 0, 22)
        switch.Position = UDim2.new(1, -44, 0.5, -11)
        switch.BackgroundColor3 = Config[configKey] and Color3.fromRGB(70, 170, 100) or Color3.fromRGB(70, 70, 76)
        switch.Parent = row
        Instance.new("UICorner", switch).CornerRadius = UDim.new(1, 0)

        local knob = Instance.new("Frame")
        knob.Size = UDim2.new(0, 18, 0, 18)
        knob.Position = Config[configKey] and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)
        knob.BackgroundColor3 = Color3.new(1, 1, 1)
        knob.Parent = switch
        Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

        local clickArea = Instance.new("TextButton")
        clickArea.Size = UDim2.new(1, 0, 1, 0)
        clickArea.BackgroundTransparency = 1
        clickArea.Text = ""
        clickArea.Parent = switch

        clickArea.MouseButton1Click:Connect(function()
            local newState = not Config[configKey]
            Config[configKey] = newState
            switch.BackgroundColor3 = newState and Color3.fromRGB(70, 170, 100) or Color3.fromRGB(70, 70, 76)
            knob:TweenPosition(
                newState and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9),
                Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.15, true
            )
            if onToggle then onToggle(newState) end
        end)

        afToggles[configKey] = { switch = switch, knob = knob }
        return row
    end

    makeToggleRow(autoFarmTab, 1, "Auto Press",   "AutoPress",   function(s) if s then startAutoPress()   end end)
    makeToggleRow(autoFarmTab, 2, "Auto Rebirth", "AutoRebirth", function(s) if s then startAutoRebirth() end end)
    makeToggleRow(autoFarmTab, 3, "Speed Boost",  "SpeedBoost",  function(s) if s then startSpeedBoost()  end end)
    makeToggleRow(autoFarmTab, 4, "Noclip",       "Noclip",      function(s) if s then startNoclip()      end end)
    makeToggleRow(autoFarmTab, 5, "Anti-AFK",     "AntiAFK")
    makeToggleRow(autoFarmTab, 6, "Auto Spin",    "AutoSpin",    function(s) if s then startAutoSpin()    end end)
    makeToggleRow(autoFarmTab, 7, "Auto Claim",   "AutoClaim",   function(s) if s then startAutoClaim()   end end)

    local afStopRow = Instance.new("Frame")
    afStopRow.Size = UDim2.new(1, 0, 0, 30)
    afStopRow.LayoutOrder = 8
    afStopRow.BackgroundTransparency = 1
    afStopRow.Parent = autoFarmTab

    local afStopBtn = Instance.new("TextButton")
    afStopBtn.Size = UDim2.new(1, 0, 1, 0)
    afStopBtn.BackgroundColor3 = Color3.fromRGB(170, 60, 60)
    afStopBtn.Text = "STOP ALL"
    afStopBtn.Font = Enum.Font.GothamBold
    afStopBtn.TextSize = 13
    afStopBtn.TextColor3 = Color3.new(1, 1, 1)
    afStopBtn.Parent = afStopRow
    Instance.new("UICorner", afStopBtn).CornerRadius = UDim.new(0, 6)

    afStopBtn.MouseButton1Click:Connect(function()
        _G.StopExploit()
        for _, t in pairs(afToggles) do
            t.switch.BackgroundColor3 = Color3.fromRGB(70, 70, 76)
            t.knob.Position = UDim2.new(0, 2, 0.5, -9)
        end
    end)

    -- ════════════════════════════════
    -- TAB 2: WIN FARM
    -- ════════════════════════════════
    local winFarmTab = Instance.new("Frame")
    winFarmTab.Size = UDim2.new(1, 0, 1, 0)
    winFarmTab.BackgroundTransparency = 1
    winFarmTab.Visible = false
    winFarmTab.Parent = contentHolder

    local wfPadding = Instance.new("UIPadding")
    wfPadding.PaddingTop = UDim.new(0, 6)
    wfPadding.PaddingLeft = UDim.new(0, 10)
    wfPadding.PaddingRight = UDim.new(0, 10)
    wfPadding.Parent = winFarmTab

    local normalBtn = Instance.new("TextButton")
    normalBtn.Size = UDim2.new(0.48, 0, 0, 28)
    normalBtn.Position = UDim2.new(0, 0, 0, 0)
    normalBtn.Text = "Normal World"
    normalBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 255)
    normalBtn.TextColor3 = Color3.new(1, 1, 1)
    normalBtn.Font = Enum.Font.GothamBold
    normalBtn.TextSize = 11
    normalBtn.Parent = winFarmTab
    Instance.new("UICorner", normalBtn).CornerRadius = UDim.new(0, 6)

    local cheeseBtn = Instance.new("TextButton")
    cheeseBtn.Size = UDim2.new(0.48, 0, 0, 28)
    cheeseBtn.Position = UDim2.new(0.52, 0, 0, 0)
    cheeseBtn.Text = "Cheese World"
    cheeseBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    cheeseBtn.TextColor3 = Color3.new(1, 1, 1)
    cheeseBtn.Font = Enum.Font.GothamBold
    cheeseBtn.TextSize = 11
    cheeseBtn.Parent = winFarmTab
    Instance.new("UICorner", cheeseBtn).CornerRadius = UDim.new(0, 6)

    local infoLabel = Instance.new("TextLabel")
    infoLabel.Size = UDim2.new(1, 0, 0, 28)
    infoLabel.Position = UDim2.new(0, 0, 0, 35)
    infoLabel.Text = "Level: -- | Room: --"
    infoLabel.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    infoLabel.TextColor3 = Color3.new(1, 1, 1)
    infoLabel.Font = Enum.Font.Gotham
    infoLabel.TextSize = 13
    infoLabel.Parent = winFarmTab
    Instance.new("UICorner", infoLabel).CornerRadius = UDim.new(0, 6)

    local wfStartBtn = Instance.new("TextButton")
    wfStartBtn.Size = UDim2.new(0.48, 0, 0, 28)
    wfStartBtn.Position = UDim2.new(0, 0, 0, 70)
    wfStartBtn.Text = "▶ Start"
    wfStartBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 0)
    wfStartBtn.TextColor3 = Color3.new(1, 1, 1)
    wfStartBtn.Font = Enum.Font.GothamBold
    wfStartBtn.TextSize = 13
    wfStartBtn.Parent = winFarmTab
    Instance.new("UICorner", wfStartBtn).CornerRadius = UDim.new(0, 6)

    local wfStopBtn = Instance.new("TextButton")
    wfStopBtn.Size = UDim2.new(0.48, 0, 0, 28)
    wfStopBtn.Position = UDim2.new(0.52, 0, 0, 70)
    wfStopBtn.Text = "■ Stop"
    wfStopBtn.BackgroundColor3 = Color3.fromRGB(180, 0, 0)
    wfStopBtn.TextColor3 = Color3.new(1, 1, 1)
    wfStopBtn.Font = Enum.Font.GothamBold
    wfStopBtn.TextSize = 13
    wfStopBtn.Parent = winFarmTab
    Instance.new("UICorner", wfStopBtn).CornerRadius = UDim.new(0, 6)

    local wfStatus = Instance.new("TextLabel")
    wfStatus.Size = UDim2.new(1, 0, 0, 25)
    wfStatus.Position = UDim2.new(0, 0, 0, 105)
    wfStatus.Text = "Status: Idle"
    wfStatus.TextColor3 = Color3.fromRGB(180, 180, 180)
    wfStatus.BackgroundTransparency = 1
    wfStatus.Font = Enum.Font.Gotham
    wfStatus.TextSize = 12
    wfStatus.Parent = winFarmTab

    local function setWorld(world)
        selectedWorld = world
        if world == "Rooms" then
            normalBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 255)
            cheeseBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        else
            cheeseBtn.BackgroundColor3 = Color3.fromRGB(255, 180, 0)
            normalBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        end
    end

    normalBtn.MouseButton1Click:Connect(function() setWorld("Rooms") end)
    cheeseBtn.MouseButton1Click:Connect(function() setWorld("CheeseRooms") end)
    wfStartBtn.MouseButton1Click:Connect(function() startWinFarm(infoLabel, wfStatus) end)
    wfStopBtn.MouseButton1Click:Connect(function() stopWinFarm(wfStatus) end)

    -- ── Tab switching ──
    local function showTab(tab)
        autoFarmTab.Visible = (tab == "AutoFarm")
        winFarmTab.Visible  = (tab == "WinFarm")
        autoFarmTabBtn.BackgroundColor3 = (tab == "AutoFarm") and Color3.fromRGB(0, 120, 255) or Color3.fromRGB(60, 60, 60)
        winFarmTabBtn.BackgroundColor3  = (tab == "WinFarm")  and Color3.fromRGB(0, 120, 255) or Color3.fromRGB(60, 60, 60)
    end

    autoFarmTabBtn.MouseButton1Click:Connect(function() showTab("AutoFarm") end)
    winFarmTabBtn.MouseButton1Click:Connect(function() showTab("WinFarm") end)

    -- ── Collapse / expand ──
    local expanded = true

    collapseBtn.MouseButton1Click:Connect(function()
        expanded = not expanded
        collapseBtn.Text = expanded and "-" or "+"
        main:TweenSize(
            expanded and UDim2.new(0, 260, 0, 320) or UDim2.new(0, 260, 0, 34),
            Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.18, true
        )
    end)

    -- ── Dragging ──
    local dragging, dragStart, startPos = false, nil, nil

    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging  = true
            dragStart = input.Position
            startPos  = main.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    titleBar.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            main.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)

    return screenGui
end

-- ═══════════════════════════════════════
-- INITIALIZATION
-- ═══════════════════════════════════════
setupDataListener()
task.wait(1)
createUI()

print("[7zxy Hub] Loaded. Auto Farm + Win Farm tabs ready.")
