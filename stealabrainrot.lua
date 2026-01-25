-// SERVICES
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")

local lp = Players.LocalPlayer

--// SETTINGS
local BASE_DISTANCE = 15
local TP_DISTANCE = 60

--// STATES
local autoDefenseEnabled = false
local antiTPEnabled = false
local triggeredPlayers = {}
local lastPositions = {}
local selectedPlayers = {} -- Track which players are selected for defense
local playerButtons = {} -- Store player button references

--// SCALE FACTOR
local viewport = workspace.CurrentCamera.ViewportSize
local scaleFactor = math.min(viewport.X / 1920, viewport.Y / 1080)

--// FIND ADMIN REMOTE
local function findAdminRemote()
    for _, v in ipairs(game:GetDescendants()) do
        if v:IsA("RemoteEvent") and v.Name:lower():find("352aad5") then
            return v
        end
    end
end
local NetRemote = findAdminRemote()

--// FIND BASE POSITIONS
local basePositions = {}
task.spawn(function()
    task.wait(2)
    local plots = Workspace:FindFirstChild("Plots")
    if not plots then return end

    for _, plot in ipairs(plots:GetChildren()) do
        local sign = plot:FindFirstChild("PlotSign")
        if sign and sign:FindFirstChild("SurfaceGui") then
            local txt = sign.SurfaceGui.Frame.TextLabel
            if txt and txt.Text:find(lp.DisplayName) then
                local pods = plot:FindFirstChild("AnimalPodiums")
                if pods then
                    for _, m in ipairs(pods:GetChildren()) do
                        if m:IsA("Model") then
                            table.insert(basePositions, m:GetPivot().Position)
                        end
                    end
                end
            end
        end
    end
end)

--// GUI
local gui = Instance.new("ScreenGui", CoreGui)
gui.Name = "CloudyDefense"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

--// MAIN FRAME (SMALLER)
local main = Instance.new("Frame", gui)
main.Size = UDim2.fromOffset(220 * scaleFactor, 240 * scaleFactor)
main.Position = UDim2.new(0.5, 0, 0, 5 * scaleFactor)
main.AnchorPoint = Vector2.new(0.5, 0)
main.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
main.BorderSizePixel = 0
main.ClipsDescendants = false
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 12 * scaleFactor)

--// MAIN STROKE (GRADIENT BORDER)
local mainStroke = Instance.new("UIStroke")
mainStroke.Color = Color3.fromRGB(255, 255, 255)
mainStroke.Thickness = 1.2 * scaleFactor
mainStroke.Transparency = 0
mainStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
mainStroke.Parent = main

local mainStrokeGradient = Instance.new("UIGradient")
mainStrokeGradient.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(50, 50, 65)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(80, 80, 100)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(50, 50, 65))
}
mainStrokeGradient.Rotation = 90
mainStrokeGradient.Parent = mainStroke

--// BORDER DOTS CONTAINER
local borderDotsContainer = Instance.new("Frame")
borderDotsContainer.Size = main.Size
borderDotsContainer.Position = main.Position
borderDotsContainer.AnchorPoint = Vector2.new(0.5, 0)
borderDotsContainer.BackgroundTransparency = 1
borderDotsContainer.BorderSizePixel = 0
borderDotsContainer.ZIndex = 100
borderDotsContainer.Parent = gui

--// SYNC DOTS WITH MAIN FRAME
RunService.RenderStepped:Connect(function()
    if main.Visible then
        borderDotsContainer.Position = main.Position
        borderDotsContainer.Visible = true
    else
        borderDotsContainer.Visible = false
    end
end)

--// CREATE DOT FUNCTION
local function createBorderDot(transparency)
    local dot = Instance.new("Frame")
    dot.Size = UDim2.new(0, 4 * scaleFactor, 0, 4 * scaleFactor)
    dot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    dot.BackgroundTransparency = transparency
    dot.BorderSizePixel = 0
    dot.ZIndex = 101
    dot.AnchorPoint = Vector2.new(0.5, 0.5)
    dot.Parent = borderDotsContainer
    Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
    return dot
end

--// CREATE DOTS
local dotColumns = {}
for col = 1, 2 do
    dotColumns[col] = {}
    for i = 1, 8 do
        dotColumns[col][i] = createBorderDot(0.2)
    end
end

--// DOT POSITION CALCULATION
local function getPositionAtDistance(distance, width, height, cornerRadius)
    local inset = 5 * scaleFactor
    local w = width - (inset * 2)
    local h = height - (inset * 2)
    local cr = cornerRadius
    
    local topStraight = w - (2 * cr)
    local rightStraight = h - (2 * cr)
    local bottomStraight = w - (2 * cr)
    local leftStraight = h - (2 * cr)
    local cornerLength = (math.pi / 2) * cr
    
    local totalPerimeter = topStraight + rightStraight + bottomStraight + leftStraight + (4 * cornerLength)
    distance = distance % totalPerimeter
    
    local x, y = inset, inset
    
    if distance < topStraight then
        x = inset + cr + distance
        y = inset
    elseif distance < topStraight + cornerLength then
        local d = distance - topStraight
        local angle = (d / cornerLength) * (math.pi / 2)
        x = inset + w - cr + (math.sin(angle) * cr)
        y = inset + cr - (math.cos(angle) * cr)
    elseif distance < topStraight + cornerLength + rightStraight then
        local d = distance - topStraight - cornerLength
        x = inset + w
        y = inset + cr + d
    elseif distance < topStraight + cornerLength + rightStraight + cornerLength then
        local d = distance - topStraight - cornerLength - rightStraight
        local angle = (d / cornerLength) * (math.pi / 2)
        x = inset + w - cr + (math.cos(angle) * cr)
        y = inset + h - cr + (math.sin(angle) * cr)
    elseif distance < topStraight + (2 * cornerLength) + rightStraight + bottomStraight then
        local d = distance - topStraight - (2 * cornerLength) - rightStraight
        x = inset + w - cr - d
        y = inset + h
    elseif distance < topStraight + (2 * cornerLength) + rightStraight + bottomStraight + cornerLength then
        local d = distance - topStraight - (2 * cornerLength) - rightStraight - bottomStraight
        local angle = (d / cornerLength) * (math.pi / 2)
        x = inset + cr - (math.sin(angle) * cr)
        y = inset + h - cr + (math.cos(angle) * cr)
    elseif distance < topStraight + (2 * cornerLength) + rightStraight + bottomStraight + cornerLength + leftStraight then
        local d = distance - topStraight - (2 * cornerLength) - rightStraight - bottomStraight - cornerLength
        x = inset
        y = inset + h - cr - d
    else
        local d = distance - topStraight - (2 * cornerLength) - rightStraight - bottomStraight - cornerLength - leftStraight
        local angle = (d / cornerLength) * (math.pi / 2)
        x = inset + cr - (math.cos(angle) * cr)
        y = inset + cr - (math.sin(angle) * cr)
    end
    
    return x, y
end

--// ANIMATE DOTS
task.spawn(function()
    local width = 220 * scaleFactor
    local height = 240 * scaleFactor
    local cornerRadius = 12 * scaleFactor
    
    while borderDotsContainer.Parent do
        local time = tick() * 50
        local dotSpacing = 8 * scaleFactor
        
        for i = 1, 8 do
            local distance = time + ((i - 1) * dotSpacing)
            local x, y = getPositionAtDistance(distance, width, height, cornerRadius)
            dotColumns[1][i].Position = UDim2.new(0, x, 0, y)
        end
        
        local totalPerimeter = (width - 2 * cornerRadius) * 2 + (height - 2 * cornerRadius) * 2 + (2 * math.pi * cornerRadius)
        local halfPerimeter = totalPerimeter / 2
        
        for i = 1, 8 do
            local distance = time + halfPerimeter + ((i - 1) * dotSpacing)
            local x, y = getPositionAtDistance(distance, width, height, cornerRadius)
            dotColumns[2][i].Position = UDim2.new(0, x, 0, y)
        end
        
        RunService.RenderStepped:Wait()
    end
end)

--// HEADER
local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 32 * scaleFactor)
header.Position = UDim2.new(0, 0, 0, 0)
header.BackgroundTransparency = 1
header.BorderSizePixel = 0
header.ZIndex = 10
header.Parent = main

--// CLOUDY LOGO
local logo = Instance.new("ImageLabel")
logo.Name = "Logo"
logo.Size = UDim2.new(0, 27 * scaleFactor, 0, 27 * scaleFactor)
logo.Position = UDim2.new(0, 12 * scaleFactor, 0.5, -12 * scaleFactor)
logo.BackgroundTransparency = 1
logo.BorderSizePixel = 0
logo.Image = "rbxassetid://96486400067510"
logo.ImageColor3 = Color3.fromRGB(255, 255, 255)
logo.ScaleType = Enum.ScaleType.Fit
logo.ZIndex = 18
logo.Parent = header

--// TITLE TEXT
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -48 * scaleFactor, 1, 0)
title.Position = UDim2.new(0, 42 * scaleFactor, 0, 0)
title.BackgroundTransparency = 1
title.Text = "CLOUDY DEFENSE"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 14 * scaleFactor
title.TextXAlignment = Enum.TextXAlignment.Left
title.ZIndex = 11
title.Parent = header

--// TITLE GRADIENT
local titleGradient = Instance.new("UIGradient")
titleGradient.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(240, 240, 250)),
    ColorSequenceKeypoint.new(0.4, Color3.fromRGB(240, 240, 250)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(120, 120, 150)),
    ColorSequenceKeypoint.new(0.6, Color3.fromRGB(240, 240, 250)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(240, 240, 250))
}
titleGradient.Parent = title

--// ANIMATE TITLE GRADIENT
task.spawn(function()
    while title.Parent do
        titleGradient.Offset = Vector2.new(-1, 0)
        local t = TweenService:Create(titleGradient, TweenInfo.new(2.5, Enum.EasingStyle.Linear), {Offset = Vector2.new(1, 0)})
        t:Play() t.Completed:Wait()
    end
end)

--// CONTENT AREA
local content = Instance.new("Frame")
content.Size = UDim2.new(1, -16 * scaleFactor, 1, -42 * scaleFactor)
content.Position = UDim2.new(0, 8 * scaleFactor, 0, 36 * scaleFactor)
content.BackgroundTransparency = 1
content.ZIndex = 2
content.Parent = main

--// DEFENSE SECTION FRAME
local defenseSection = Instance.new("Frame")
defenseSection.Size = UDim2.new(1, 0, 0, 77 * scaleFactor)
defenseSection.Position = UDim2.new(0, 0, 0, 0)
defenseSection.BackgroundColor3 = Color3.fromRGB(22, 22, 26)
defenseSection.BorderSizePixel = 0
defenseSection.ZIndex = 3
defenseSection.Parent = content
Instance.new("UICorner", defenseSection).CornerRadius = UDim.new(0, 8 * scaleFactor)

local defenseSectionStroke = Instance.new("UIStroke")
defenseSectionStroke.Color = Color3.fromRGB(40, 40, 48)
defenseSectionStroke.Thickness = 1 * scaleFactor
defenseSectionStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
defenseSectionStroke.Parent = defenseSection

--// DEFENSE HEADER
local defenseHeader = Instance.new("TextLabel")
defenseHeader.Size = UDim2.new(1, -12 * scaleFactor, 0, 20 * scaleFactor)
defenseHeader.Position = UDim2.new(0, 8 * scaleFactor, 0, 0 * scaleFactor)
defenseHeader.BackgroundTransparency = 1
defenseHeader.Text = "Defense"
defenseHeader.Font = Enum.Font.GothamBold
defenseHeader.TextSize = 12 * scaleFactor
defenseHeader.TextColor3 = Color3.fromRGB(200, 200, 210)
defenseHeader.TextXAlignment = Enum.TextXAlignment.Left
defenseHeader.ZIndex = 4
defenseHeader.Parent = defenseSection

--// AUTO DEFENSE CONTAINER
local autoDefenseContainer = Instance.new("Frame")
autoDefenseContainer.Size = UDim2.new(1, -12 * scaleFactor, 0, 24 * scaleFactor)
autoDefenseContainer.Position = UDim2.new(0, 6 * scaleFactor, 0, 20 * scaleFactor)
autoDefenseContainer.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
autoDefenseContainer.BorderSizePixel = 0
autoDefenseContainer.ZIndex = 4
autoDefenseContainer.Parent = defenseSection
Instance.new("UICorner", autoDefenseContainer).CornerRadius = UDim.new(0, 6 * scaleFactor)

local autoContainerStroke = Instance.new("UIStroke")
autoContainerStroke.Color = Color3.fromRGB(45, 45, 52)
autoContainerStroke.Thickness = 1 * scaleFactor
autoContainerStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
autoContainerStroke.Parent = autoDefenseContainer

--// AUTO DEFENSE LABEL
local autoLabel = Instance.new("TextLabel")
autoLabel.Size = UDim2.new(1, -50 * scaleFactor, 1, 0)
autoLabel.Position = UDim2.new(0, 8 * scaleFactor, 0, 0)
autoLabel.BackgroundTransparency = 1
autoLabel.Text = "Auto Defense"
autoLabel.Font = Enum.Font.GothamBold
autoLabel.TextSize = 11 * scaleFactor
autoLabel.TextColor3 = Color3.fromRGB(240, 240, 250)
autoLabel.TextXAlignment = Enum.TextXAlignment.Left
autoLabel.ZIndex = 5
autoLabel.Parent = autoDefenseContainer

--// AUTO DEFENSE SWITCH
local autoSwitch = Instance.new("TextButton")
autoSwitch.Size = UDim2.new(0, 36 * scaleFactor, 0, 18 * scaleFactor)
autoSwitch.Position = UDim2.new(1, -40 * scaleFactor, 0.5, -9 * scaleFactor)
autoSwitch.BackgroundColor3 = Color3.fromRGB(45, 45, 52)
autoSwitch.BorderSizePixel = 0
autoSwitch.AutoButtonColor = false
autoSwitch.Text = ""
autoSwitch.ZIndex = 5
autoSwitch.Parent = autoDefenseContainer
Instance.new("UICorner", autoSwitch).CornerRadius = UDim.new(1, 0)

local autoSwitchStroke = Instance.new("UIStroke")
autoSwitchStroke.Color = Color3.fromRGB(60, 60, 70)
autoSwitchStroke.Thickness = 1 * scaleFactor
autoSwitchStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
autoSwitchStroke.Parent = autoSwitch

--// AUTO SWITCH KNOB
local autoKnob = Instance.new("Frame")
autoKnob.Size = UDim2.new(0, 14 * scaleFactor, 0, 14 * scaleFactor)
autoKnob.Position = UDim2.new(0, 2 * scaleFactor, 0.5, -7 * scaleFactor)
autoKnob.BackgroundColor3 = Color3.fromRGB(180, 180, 190)
autoKnob.BorderSizePixel = 0
autoKnob.ZIndex = 6
autoKnob.Parent = autoSwitch
Instance.new("UICorner", autoKnob).CornerRadius = UDim.new(1, 0)

autoSwitch.MouseButton1Click:Connect(function()
    autoDefenseEnabled = not autoDefenseEnabled
    
    if autoDefenseEnabled then
        TweenService:Create(autoSwitch, TweenInfo.new(0.2), {
            BackgroundColor3 = Color3.fromRGB(70, 180, 100)
        }):Play()
        TweenService:Create(autoSwitchStroke, TweenInfo.new(0.2), {
            Color = Color3.fromRGB(100, 220, 140)
        }):Play()
        TweenService:Create(autoKnob, TweenInfo.new(0.2), {
            Position = UDim2.new(1, -16 * scaleFactor, 0.5, -7 * scaleFactor),
            BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        }):Play()
    else
        TweenService:Create(autoSwitch, TweenInfo.new(0.2), {
            BackgroundColor3 = Color3.fromRGB(45, 45, 52)
        }):Play()
        TweenService:Create(autoSwitchStroke, TweenInfo.new(0.2), {
            Color = Color3.fromRGB(60, 60, 70)
        }):Play()
        TweenService:Create(autoKnob, TweenInfo.new(0.2), {
            Position = UDim2.new(0, 2 * scaleFactor, 0.5, -7 * scaleFactor),
            BackgroundColor3 = Color3.fromRGB(180, 180, 190)
        }):Play()
    end
end)

--// ANTI TP CONTAINER
local antiTPContainer = Instance.new("Frame")
antiTPContainer.Size = UDim2.new(1, -12 * scaleFactor, 0, 24 * scaleFactor)
antiTPContainer.Position = UDim2.new(0, 6 * scaleFactor, 0, 48 * scaleFactor)
antiTPContainer.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
antiTPContainer.BorderSizePixel = 0
antiTPContainer.ZIndex = 4
antiTPContainer.Parent = defenseSection
Instance.new("UICorner", antiTPContainer).CornerRadius = UDim.new(0, 6 * scaleFactor)

local antiContainerStroke = Instance.new("UIStroke")
antiContainerStroke.Color = Color3.fromRGB(45, 45, 52)
antiContainerStroke.Thickness = 1 * scaleFactor
antiContainerStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
antiContainerStroke.Parent = antiTPContainer

--// ANTI TP LABEL
local antiLabel = Instance.new("TextLabel")
antiLabel.Size = UDim2.new(1, -50 * scaleFactor, 1, 0)
antiLabel.Position = UDim2.new(0, 8 * scaleFactor, 0, 0)
antiLabel.BackgroundTransparency = 1
antiLabel.Text = "Anti TP"
antiLabel.Font = Enum.Font.GothamBold
antiLabel.TextSize = 11 * scaleFactor
antiLabel.TextColor3 = Color3.fromRGB(240, 240, 250)
antiLabel.TextXAlignment = Enum.TextXAlignment.Left
antiLabel.ZIndex = 5
antiLabel.Parent = antiTPContainer

--// ANTI TP SWITCH
local antiSwitch = Instance.new("TextButton")
antiSwitch.Size = UDim2.new(0, 36 * scaleFactor, 0, 18 * scaleFactor)
antiSwitch.Position = UDim2.new(1, -40 * scaleFactor, 0.5, -9 * scaleFactor)
antiSwitch.BackgroundColor3 = Color3.fromRGB(45, 45, 52)
antiSwitch.BorderSizePixel = 0
antiSwitch.AutoButtonColor = false
antiSwitch.Text = ""
antiSwitch.ZIndex = 5
antiSwitch.Parent = antiTPContainer
Instance.new("UICorner", antiSwitch).CornerRadius = UDim.new(1, 0)

local antiSwitchStroke = Instance.new("UIStroke")
antiSwitchStroke.Color = Color3.fromRGB(60, 60, 70)
antiSwitchStroke.Thickness = 1 * scaleFactor
antiSwitchStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
antiSwitchStroke.Parent = antiSwitch

--// ANTI SWITCH KNOB
local antiKnob = Instance.new("Frame")
antiKnob.Size = UDim2.new(0, 14 * scaleFactor, 0, 14 * scaleFactor)
antiKnob.Position = UDim2.new(0, 2 * scaleFactor, 0.5, -7 * scaleFactor)
antiKnob.BackgroundColor3 = Color3.fromRGB(180, 180, 190)
antiKnob.BorderSizePixel = 0
antiKnob.ZIndex = 6
antiKnob.Parent = antiSwitch
Instance.new("UICorner", antiKnob).CornerRadius = UDim.new(1, 0)

antiSwitch.MouseButton1Click:Connect(function()
    antiTPEnabled = not antiTPEnabled
    
    if antiTPEnabled then
        TweenService:Create(antiSwitch, TweenInfo.new(0.2), {
            BackgroundColor3 = Color3.fromRGB(70, 180, 100)
        }):Play()
        TweenService:Create(antiSwitchStroke, TweenInfo.new(0.2), {
            Color = Color3.fromRGB(100, 220, 140)
        }):Play()
        TweenService:Create(antiKnob, TweenInfo.new(0.2), {
            Position = UDim2.new(1, -16 * scaleFactor, 0.5, -7 * scaleFactor),
            BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        }):Play()
    else
        TweenService:Create(antiSwitch, TweenInfo.new(0.2), {
            BackgroundColor3 = Color3.fromRGB(45, 45, 52)
        }):Play()
        TweenService:Create(antiSwitchStroke, TweenInfo.new(0.2), {
            Color = Color3.fromRGB(60, 60, 70)
        }):Play()
        TweenService:Create(antiKnob, TweenInfo.new(0.2), {
            Position = UDim2.new(0, 2 * scaleFactor, 0.5, -7 * scaleFactor),
            BackgroundColor3 = Color3.fromRGB(180, 180, 190)
        }):Play()
    end
end)

--// PLAYER LIST SECTION FRAME
local playerSection = Instance.new("Frame")
playerSection.Size = UDim2.new(1, 0, 0, 100 * scaleFactor)
playerSection.Position = UDim2.new(0, 0, 0, 82 * scaleFactor)
playerSection.BackgroundColor3 = Color3.fromRGB(22, 22, 26)
playerSection.BorderSizePixel = 0
playerSection.ZIndex = 3
playerSection.Parent = content
Instance.new("UICorner", playerSection).CornerRadius = UDim.new(0, 8 * scaleFactor)

local playerSectionStroke = Instance.new("UIStroke")
playerSectionStroke.Color = Color3.fromRGB(40, 40, 48)
playerSectionStroke.Thickness = 1 * scaleFactor
playerSectionStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
playerSectionStroke.Parent = playerSection

--// PLAYER LIST HEADER CONTAINER
local playerHeaderContainer = Instance.new("Frame")
playerHeaderContainer.Size = UDim2.new(1, -12 * scaleFactor, 0, 20 * scaleFactor)
playerHeaderContainer.Position = UDim2.new(0, 6 * scaleFactor, 0, 6 * scaleFactor)
playerHeaderContainer.BackgroundTransparency = 1
playerHeaderContainer.ZIndex = 4
playerHeaderContainer.Parent = playerSection

--// PLAYER LIST LABEL
local playerListLabel = Instance.new("TextLabel")
playerListLabel.Size = UDim2.new(0.5, -2 * scaleFactor, 1, 0)
playerListLabel.Position = UDim2.new(0, 2 * scaleFactor, 0, 0)
playerListLabel.BackgroundTransparency = 1
playerListLabel.Text = "Players 0 / 0"
playerListLabel.Font = Enum.Font.GothamBold
playerListLabel.TextSize = 11 * scaleFactor
playerListLabel.TextColor3 = Color3.fromRGB(200, 200, 210)
playerListLabel.TextXAlignment = Enum.TextXAlignment.Left
playerListLabel.ZIndex = 5
playerListLabel.Parent = playerHeaderContainer

--// SELECTED LABEL
local selectedLabel = Instance.new("TextLabel")
selectedLabel.Size = UDim2.new(0.5, -2 * scaleFactor, 1, 0)
selectedLabel.Position = UDim2.new(0.6, 2 * scaleFactor, 0, 0)
selectedLabel.BackgroundTransparency = 1
selectedLabel.Text = "Selected 0 / 0"
selectedLabel.Font = Enum.Font.GothamBold
selectedLabel.TextSize = 11 * scaleFactor
selectedLabel.TextColor3 = Color3.fromRGB(200, 200, 210)
selectedLabel.TextXAlignment = Enum.TextXAlignment.Left
selectedLabel.ZIndex = 5
selectedLabel.Parent = playerHeaderContainer

--// PLAYER LIST CONTAINER (SCROLLING)
local playerListFrame = Instance.new("ScrollingFrame")
playerListFrame.Size = UDim2.new(1, -12 * scaleFactor, 1, -36 * scaleFactor)
playerListFrame.Position = UDim2.new(0, 6 * scaleFactor, 0, 30 * scaleFactor)
playerListFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
playerListFrame.BorderSizePixel = 0
playerListFrame.ScrollBarThickness = 0
playerListFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
playerListFrame.ZIndex = 4
playerListFrame.Parent = playerSection
Instance.new("UICorner", playerListFrame).CornerRadius = UDim.new(0, 6 * scaleFactor)

local playerListStroke = Instance.new("UIStroke")
playerListStroke.Color = Color3.fromRGB(35, 35, 40)
playerListStroke.Thickness = 1 * scaleFactor
playerListStroke.Transparency = 0
playerListStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
playerListStroke.Parent = playerListFrame

--// PLAYER LIST LAYOUT
local playerListLayout = Instance.new("UIListLayout")
playerListLayout.SortOrder = Enum.SortOrder.Name
playerListLayout.Padding = UDim.new(0, 4 * scaleFactor)
playerListLayout.Parent = playerListFrame

-- Add padding to the list
local listPadding = Instance.new("UIPadding")
listPadding.PaddingTop = UDim.new(0, 4 * scaleFactor)
listPadding.PaddingBottom = UDim.new(0, 4 * scaleFactor)
listPadding.PaddingLeft = UDim.new(0, 4 * scaleFactor)
listPadding.PaddingRight = UDim.new(0, -3 * scaleFactor)
listPadding.Parent = playerListFrame

--// UPDATE PLAYER LIST
local function updatePlayerList()
    -- Clear existing buttons
    for _, btn in pairs(playerButtons) do
        btn:Destroy()
    end
    playerButtons = {}
    
    -- Clean up selectedPlayers table - remove players who left
    local currentPlayers = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= lp then
            currentPlayers[plr.UserId] = true
        end
    end
    for userId in pairs(selectedPlayers) do
        if not currentPlayers[userId] then
            selectedPlayers[userId] = nil
        end
    end
    
    local players = Players:GetPlayers()
    local playerCount = 0
    
    for _, plr in ipairs(players) do
        if plr ~= lp then
            playerCount = playerCount + 1
            
            -- Create player button (smaller)
            local playerBtn = Instance.new("TextButton")
            playerBtn.Size = UDim2.new(1, -8 * scaleFactor, 0, 28 * scaleFactor)
            playerBtn.BackgroundColor3 = Color3.fromRGB(22, 22, 26)
            playerBtn.BorderSizePixel = 0
            playerBtn.AutoButtonColor = false
            playerBtn.Text = ""
            playerBtn.ZIndex = 5
            playerBtn.Parent = playerListFrame
            Instance.new("UICorner", playerBtn).CornerRadius = UDim.new(0, 6 * scaleFactor)
            
            -- Player button stroke
            local btnStroke = Instance.new("UIStroke")
            btnStroke.Color = Color3.fromRGB(35, 35, 40)
            btnStroke.Thickness = 1 * scaleFactor
            btnStroke.Transparency = 0
            btnStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
            btnStroke.Parent = playerBtn
            
            -- Player avatar (smaller, circular)
            local avatar = Instance.new("ImageLabel")
            avatar.Size = UDim2.new(0, 22 * scaleFactor, 0, 22 * scaleFactor)
            avatar.Position = UDim2.new(0, 3 * scaleFactor, 0.5, -11 * scaleFactor)
            avatar.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
            avatar.BorderSizePixel = 0
            avatar.Image = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. plr.UserId .. "&width=48&height=48&format=png"
            avatar.ZIndex = 6
            avatar.Parent = playerBtn
            Instance.new("UICorner", avatar).CornerRadius = UDim.new(1, 0)
            
            -- Player name
            local playerName = Instance.new("TextLabel")
            playerName.Size = UDim2.new(1, -52 * scaleFactor, 1, 0)
            playerName.Position = UDim2.new(0, 28 * scaleFactor, 0, 0)
            playerName.BackgroundTransparency = 1
            playerName.Text = plr.DisplayName
            playerName.Font = Enum.Font.GothamBold
            playerName.TextSize = 11 * scaleFactor
            playerName.TextColor3 = Color3.fromRGB(240, 240, 250)
            playerName.TextXAlignment = Enum.TextXAlignment.Left
            playerName.TextTruncate = Enum.TextTruncate.AtEnd
            playerName.ZIndex = 6
            playerName.Parent = playerBtn
            
            -- Selection indicator (smaller checkbox)
            local indicator = Instance.new("Frame")
            indicator.Size = UDim2.new(0, 17 * scaleFactor, 0, 17 * scaleFactor)
            indicator.Position = UDim2.new(1, -22 * scaleFactor, 0.5, -8.5 * scaleFactor)
            indicator.BackgroundColor3 = Color3.fromRGB(28, 28, 32)
            indicator.BorderSizePixel = 0
            indicator.ZIndex = 6
            indicator.Parent = playerBtn
            Instance.new("UICorner", indicator).CornerRadius = UDim.new(1, 0)
            
            local indicatorStroke = Instance.new("UIStroke")
            indicatorStroke.Color = Color3.fromRGB(60, 60, 70)
            indicatorStroke.Thickness = 2.5 * scaleFactor
            indicatorStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
            indicatorStroke.Parent = indicator
            
            -- Inner circle (the "check" indicator)
            local innerCircle = Instance.new("Frame")
            innerCircle.Size = UDim2.new(0, 9 * scaleFactor, 0, 9 * scaleFactor)
            innerCircle.Position = UDim2.new(0.5, 0, 0.5, 0)
            innerCircle.AnchorPoint = Vector2.new(0.5, 0.5)
            innerCircle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            innerCircle.BorderSizePixel = 0
            innerCircle.BackgroundTransparency = 1
            innerCircle.ZIndex = 7
            innerCircle.Parent = indicator
            Instance.new("UICorner", innerCircle).CornerRadius = UDim.new(1, 0)
            
            -- Glow effect
            local glowEffect = Instance.new("ImageLabel")
            glowEffect.Size = UDim2.new(1.6, 0, 1.6, 0)
            glowEffect.Position = UDim2.new(0.5, 0, 0.5, 0)
            glowEffect.AnchorPoint = Vector2.new(0.5, 0.5)
            glowEffect.BackgroundTransparency = 1
            glowEffect.Image = "rbxassetid://5028857084"
            glowEffect.ImageColor3 = Color3.fromRGB(255, 255, 255)
            glowEffect.ImageTransparency = 1
            glowEffect.ZIndex = 5
            glowEffect.Parent = indicator
            
            -- Store reference to player UserId for this button
            local playerUserId = plr.UserId
            
            -- Initialize selection state
            if selectedPlayers[playerUserId] then
                innerCircle.BackgroundTransparency = 0
                indicatorStroke.Color = Color3.fromRGB(255, 255, 255)
                glowEffect.ImageTransparency = 0.3
            end
            
            -- Toggle selection
            playerBtn.MouseButton1Click:Connect(function()
                if selectedPlayers[playerUserId] then
                    selectedPlayers[playerUserId] = nil
                    
                    TweenService:Create(innerCircle, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
                        BackgroundTransparency = 1,
                        Size = UDim2.new(0, 0, 0, 0)
                    }):Play()
                    TweenService:Create(indicatorStroke, TweenInfo.new(0.2), {
                        Color = Color3.fromRGB(60, 60, 70)
                    }):Play()
                    TweenService:Create(glowEffect, TweenInfo.new(0.2), {
                        ImageTransparency = 1
                    }):Play()
                else
                    selectedPlayers[playerUserId] = true
                    
                    innerCircle.Size = UDim2.new(0, 0, 0, 0)
                    innerCircle.BackgroundTransparency = 0
                    TweenService:Create(innerCircle, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                        Size = UDim2.new(0, 9 * scaleFactor, 0, 9 * scaleFactor)
                    }):Play()
                    TweenService:Create(indicatorStroke, TweenInfo.new(0.2), {
                        Color = Color3.fromRGB(255, 255, 255)
                    }):Play()
                    TweenService:Create(glowEffect, TweenInfo.new(0.2), {
                        ImageTransparency = 0.3
                    }):Play()
                end
                
                -- Count selected players and update label immediately
                local selectedCount = 0
                for _ in pairs(selectedPlayers) do
                    selectedCount = selectedCount + 1
                end
                selectedLabel.Text = string.format("Selected %d / %d", selectedCount, playerCount)
            end)
            
            -- Hover effect
            playerBtn.MouseEnter:Connect(function()
                TweenService:Create(playerBtn, TweenInfo.new(0.1), {
                    BackgroundColor3 = Color3.fromRGB(28, 28, 34)
                }):Play()
            end)
            
            playerBtn.MouseLeave:Connect(function()
                TweenService:Create(playerBtn, TweenInfo.new(0.1), {
                    BackgroundColor3 = Color3.fromRGB(22, 22, 26)
                }):Play()
            end)
            
            playerButtons[plr.UserId] = playerBtn
        end
    end
    
    -- Update canvas size
    playerListFrame.CanvasSize = UDim2.new(0, 0, 0, (playerCount * 32 * scaleFactor) + (8 * scaleFactor))
    
    -- Count selected players from the actual table
    local selectedCount = 0
    for userId in pairs(selectedPlayers) do
        selectedCount = selectedCount + 1
    end
    
    -- Update labels
    playerListLabel.Text = string.format("Players %d / %d", playerCount, playerCount)
    selectedLabel.Text = string.format("Selected %d / %d", selectedCount, playerCount)
end

-- Initial update
updatePlayerList()

-- Update when players join/leave
Players.PlayerAdded:Connect(updatePlayerList)
Players.PlayerRemoving:Connect(function(plr)
    selectedPlayers[plr.UserId] = nil
    updatePlayerList()
end)

--// DISCORD LABEL
local discord = Instance.new("TextLabel")
discord.Size = UDim2.new(1, 0, 0, 12 * scaleFactor)
discord.Position = UDim2.new(0, 0, 1, -14 * scaleFactor)
discord.BackgroundTransparency = 1
discord.Text = "discord.gg/pvHh3d3pQZ"
discord.TextColor3 = Color3.fromRGB(100, 100, 120)
discord.Font = Enum.Font.GothamBold
discord.TextSize = 10 * scaleFactor
discord.ZIndex = 3
discord.Parent = content

--// DISCORD GRADIENT
local discordGradient = Instance.new("UIGradient")
discordGradient.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(100, 100, 120)),
    ColorSequenceKeypoint.new(0.4, Color3.fromRGB(100, 100, 120)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(160, 160, 180)),
    ColorSequenceKeypoint.new(0.6, Color3.fromRGB(100, 100, 120)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(100, 100, 120))
}
discordGradient.Parent = discord

--// ANIMATE DISCORD GRADIENT
task.spawn(function()
    while discord.Parent do
        discordGradient.Offset = Vector2.new(-1, 0)
        local t = TweenService:Create(discordGradient, TweenInfo.new(2.5, Enum.EasingStyle.Linear), {Offset = Vector2.new(1, 0)})
        t:Play() t.Completed:Wait()
    end
end)

--// MAKE DRAGGABLE
local dragging, dragInput, dragStart, startPos

main.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = main.Position
        
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

main.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

game:GetService("UserInputService").InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

--// FIRE ADMIN (ONCE)
local function fireAdmin(plr)
    if triggeredPlayers[plr] then return end
    triggeredPlayers[plr] = true

    for _, cmd in ipairs({"balloon","inverse","rocket","tiny"}) do
        NetRemote:FireServer(
            "78a772b6-9e1c-4827-ab8b-04a07838f298",
            plr,
            cmd
        )
    end
end

--// MAIN LOOP
RunService.Heartbeat:Connect(function()
    if not autoDefenseEnabled or not NetRemote then return end

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= lp and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
            -- Only defend against selected players
            if not selectedPlayers[plr.UserId] then continue end
            
            local root = plr.Character.HumanoidRootPart
            local pos = root.Position
            local nearBase = false

            -- WALK-IN CHECK
            for _, bpos in ipairs(basePositions) do
                if (pos - bpos).Magnitude <= BASE_DISTANCE then
                    fireAdmin(plr)
                    nearBase = true
                    break
                end
            end

            -- ANTI TP CHECK (ONLY IF ENABLED)
            if antiTPEnabled and lastPositions[plr] then
                if (pos - lastPositions[plr]).Magnitude >= TP_DISTANCE then
                    for _, bpos in ipairs(basePositions) do
                        if (pos - bpos).Magnitude <= BASE_DISTANCE then
                            fireAdmin(plr)
                        end
                    end
                end
            end

            lastPositions[plr] = pos

            -- RESET AFTER LEAVING
            if not nearBase then
                triggeredPlayers[plr] = nil
            end
        end
    end
end)
