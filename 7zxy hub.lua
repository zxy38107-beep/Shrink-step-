local player = game.Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local root = char:WaitForChild("HumanoidRootPart")
local running = false
local selectedWorld = "Rooms"

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

-- Room input
local roomInput = Instance.new("TextBox", frame)
roomInput.Size = UDim2.new(1, -10, 0, 28)
roomInput.Position = UDim2.new(0, 5, 0, 70)
roomInput.PlaceholderText = "Room number (e.g. 10)"
roomInput.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
roomInput.TextColor3 = Color3.new(1,1,1)
roomInput.Font = Enum.Font.Gotham
roomInput.TextSize = 13
Instance.new("UICorner", roomInput).CornerRadius = UDim.new(0, 6)

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

startBtn.MouseButton1Click:Connect(function()
    local roomNum = roomInput.Text
    local container = workspace:FindFirstChild(selectedWorld)
    if not container then
        status.Text = "World not found!"
        return
    end
    local targetRoom = container:FindFirstChild(roomNum)
    local winPart = targetRoom and targetRoom:FindFirstChild("Win")
    if not winPart then
        status.Text = "Room " .. roomNum .. " not found!"
        return
    end
    running = true
    status.Text = "Farming " .. selectedWorld .. " room " .. roomNum
    task.spawn(function()
        while running do
            char = player.Character
            root = char and char:FindFirstChild("HumanoidRootPart")
            if root then
                root.CFrame = CFrame.new(winPart.Position + Vector3.new(0, 3, 0))
            end
            task.wait(0.2)
        end
        status.Text = "Status: Idle"
    end)
end)

stopBtn.MouseButton1Click:Connect(function()
    running = false
end)
