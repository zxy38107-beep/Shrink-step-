local player = game.Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local root = char:WaitForChild("HumanoidRootPart")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local running = false
local selectedWorld = "Rooms"
local heartbeatConn = nil

-- Remote setup (needed to read Level for auto room detection)
local Events = ReplicatedStorage:WaitForChild("Events")
local remotes = {
    getPlayerData = Events:WaitForChild("GetPlayerData"),
}

local function getStats()
    local ok, data = pcall(function()
        return remotes.getPlayerData:InvokeServer()
    end)
    if ok and data and data.Stats then
        return data.Stats
    end
    return nil
end

-- ============================================
-- ROOM LEVEL MAP (room# -> min level required)
-- Confirmed in-game values override the placeholder formula.
-- Rooms 1-13, 21, 22 are still unverified placeholders.
-- Room 19's gap (+145) is unusually large -- double check that one.
-- ============================================
local ROOM_LEVEL_MAP = {}
for i = 1, 22 do
    ROOM_LEVEL_MAP[i] = (i == 1) and 1 or ((i - 1) * 25) -- placeholder, unverified rooms only
end

local VERIFIED_ROOM_LEVELS = {
    [14] = 365,
    [15] = 400,
    [16] = 450,
    [17] = 510,
    [18] = 575,
    [19] = 720, -- unusually large gap, double-check this one
    [20] = 800,
}
for room, level in pairs(VERIFIED_ROOM_LEVELS) do
    ROOM_LEVEL_MAP[room] = level
end

local function getRoomForLevel(level)
    local best = 1
    for room, req in pairs(ROOM_LEVEL_MAP) do
        if level >= req and room > best then
            best = room
        end
    end
    return best
end

local gui = Instance.new("ScreenGui", player.PlayerGui)
gui.ResetOnSpawn = false

local frame = Instance.new("Frame", gui)
frame.Size = UDim2.new(0, 240, 0, 175)
frame.Position = UDim2.new(0.5, -120, 0.5, -87)
frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
frame.Active = true
frame.Draggable = true

local corner = Instance.new("UICorner", frame)
corner.CornerRadius = UDim.new(0, 8)

-- Title
local title = Instance.new("TextLabel", frame)
title.Size = UDim2.new(1, 0, 0, 30)
title.Text = "⚡ 7zxy Hub"
title.TextColor3 = Color3.new(1,1,1)
title.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
title.Font = Enum.Font.GothamBold
title.TextSize = 14

local titleCorner = Instance.new("UICorner", title)
titleCorner.CornerRadius = UDim.new(0, 8)

-- World toggle buttons
local normalBtn = Instance.new("TextButton", frame)
normalBtn.Size = UDim2.new(0.48, 0, 0, 28)
normalBtn.Position = UDim2.new(0.01, 0, 0, 35)
normalBtn.Text = "Normal World"
normalBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 255)
normalBtn.TextColor3 = Color3.new(1,1,1)
normalBtn.Font = Enum.Font.GothamBold
normalBtn.TextSize = 11
Instance.new("UICorner", normalBtn).CornerRadius = UDim.new(0, 6)

local cheeseBtn = Instance.new("TextButton", frame)
cheeseBtn.Size = UDim2.new(0.48, 0, 0, 28)
cheeseBtn.Position = UDim2.new(0.51, 0, 0, 35)
cheeseBtn.Text = "Cheese World"
cheeseBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
cheeseBtn.TextColor3 = Color3.new(1,1,1)
cheeseBtn.Font = Enum.Font.GothamBold
cheeseBtn.TextSize = 11
Instance.new("UICorner", cheeseBtn).CornerRadius = UDim.new(0, 6)

-- Auto-detected level/room display (replaces the manual room number box)
local infoLabel = Instance.new("TextLabel", frame)
infoLabel.Size = UDim2.new(1, -10, 0, 28)
infoLabel.Position = UDim2.new(0, 5, 0, 70)
infoLabel.Text = "Level: -- | Room: --"
infoLabel.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
infoLabel.TextColor3 = Color3.new(1,1,1)
infoLabel.Font = Enum.Font.Gotham
infoLabel.TextSize = 13
Instance.new("UICorner", infoLabel).CornerRadius = UDim.new(0, 6)

-- Start/Stop
local startBtn = Instance.new("TextButton", frame)
startBtn.Size = UDim2.new(0.48, 0, 0, 28)
startBtn.Position = UDim2.new(0.01, 0, 0, 105)
startBtn.Text = "▶ Start"
startBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 0)
startBtn.TextColor3 = Color3.new(1,1,1)
startBtn.Font = Enum.Font.GothamBold
startBtn.TextSize = 13
Instance.new("UICorner", startBtn).CornerRadius = UDim.new(0, 6)

local stopBtn = Instance.new("TextButton", frame)
stopBtn.Size = UDim2.new(0.48, 0, 0, 28)
stopBtn.Position = UDim2.new(0.51, 0, 0, 105)
stopBtn.Text = "■ Stop"
stopBtn.BackgroundColor3 = Color3.fromRGB(180, 0, 0)
stopBtn.TextColor3 = Color3.new(1,1,1)
stopBtn.Font = Enum.Font.GothamBold
stopBtn.TextSize = 13
Instance.new("UICorner", stopBtn).CornerRadius = UDim.new(0, 6)

-- Status
local status = Instance.new("TextLabel", frame)
status.Size = UDim2.new(1, -10, 0, 25)
status.Position = UDim2.new(0, 5, 0, 142)
status.Text = "Status: Idle"
status.TextColor3 = Color3.fromRGB(180, 180, 180)
status.BackgroundTransparency = 1
status.Font = Enum.Font.Gotham
status.TextSize = 12

-- World toggle logic
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

-- Start: room is auto-detected from Level (re-checked ~1x/sec, no need to
-- spam the data remote every frame). Position toggles in/out of the Win
-- part on every single frame via Heartbeat, since standing still only
-- fires Touched once -- toggling re-fires it every frame instead.
local lastStatsCheck = 0
local cachedWinPart = nil
local cachedRoom = nil
local toggleOut = false

startBtn.MouseButton1Click:Connect(function()
    running = true
    status.Text = "Farming " .. selectedWorld .. "..."
    cachedWinPart = nil
    cachedRoom = nil
    lastStatsCheck = 0

    heartbeatConn = RunService.Heartbeat:Connect(function()
        if not running then return end

        local now = os.clock()
        if now - lastStatsCheck > 1 then
            lastStatsCheck = now
            local stats = getStats()
            local container = workspace:FindFirstChild(selectedWorld)
            if stats and container then
                local level = stats.Level or 1
                local room = getRoomForLevel(level)
                infoLabel.Text = string.format("Level: %s | Room: %d", tostring(level), room)

                if room ~= cachedRoom then
                    cachedRoom = room
                    local targetRoom = container:FindFirstChild(tostring(room))
                    cachedWinPart = targetRoom and targetRoom:FindFirstChild("Win")
                end

                if cachedWinPart then
                    status.Text = "Farming " .. selectedWorld .. " room " .. room
                else
                    status.Text = "Room " .. room .. " not found in " .. selectedWorld
                end
            elseif not container then
                status.Text = selectedWorld .. " not found!"
                cachedWinPart = nil
            end
        end

        if cachedWinPart then
            char = player.Character
            root = char and char:FindFirstChild("HumanoidRootPart")
            if root then
                -- toggle just outside then back inside the part every frame
                -- so Touched re-fires instead of only firing once on first contact
                toggleOut = not toggleOut
                local offset = toggleOut and Vector3.new(0, 6, 0) or Vector3.new(0, 3, 0)
                root.CFrame = CFrame.new(cachedWinPart.Position + offset)
            end
        end
    end)
end)

stopBtn.MouseButton1Click:Connect(function()
    running = false
    if heartbeatConn then
        heartbeatConn:Disconnect()
        heartbeatConn = nil
    end
    status.Text = "Status: Idle"
end)
