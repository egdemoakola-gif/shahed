if not game:IsLoaded() then game.Loaded:Wait() end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local InsertService = game:GetService("InsertService")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local DRONE_ASSET_ID = 16531510943
local REMOTE_ASSET_ID = 4856121831
local GIF_URL = "https://raw.githubusercontent.com/egdemoakola-gif/shahed/main/shahed.gif"
local BASE_SPEED = 60
local BOOST_SPEED = 140
local ULTRA_SPEED = 320
local CRASH_DIST = 7
local BATTERY_DRAIN = 0.8
local GRACE_PERIOD = 2.0
local CRASH_TOTAL = 5
local EXPLOSION_TIME = 2
local SPAWN_HEIGHT = 20
local MODEL_YAW_FIX = math.pi
local REPAIR_TIME = 3
local WRECK_RANGE = 12
local ROCKET_SPEED = 220
local ROCKET_RANGE = 400
local ROCKET_DAMAGE = 999
local ROCKET_COOLDOWN = 0.4
local ROCKET_RADIUS = 18
local SIT_GAP = 2.8

local droneObject, droneCFrame, camSubject
local droneMode = false
local crashed = false
local frozen = false
local noclip = false
local battery = 100
local noCrashUntil = 0
local droneMethod, remoteMethod = "?", "?"
local firstPerson, ultraBoost = true, false
local fps, fpsFrames, fpsTime = 0, 0, 0
local wrecks = {}
local repairing = false
local riddenWreck = nil
local lastRocket = 0
local mountWreck
local userHoldingController = false
local currentController = nil
local rebuildCooldown = 0
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function getParent()
    local ok, r = pcall(function() return gethui() end)
    if ok and r then return r end
    local ok2, r2 = pcall(function() return game:GetService("CoreGui") end)
    if ok2 and r2 then return r2 end
    return LocalPlayer:WaitForChild("PlayerGui")
end

local parent = getParent()

local screen = Instance.new("ScreenGui")
screen.Name = "shahed_ctrl"
screen.IgnoreGuiInset = true
screen.ResetOnSpawn = false
screen.DisplayOrder = 2147483647
screen.Parent = parent

-- LOADING SCREEN
local loadingOverlay = Instance.new("Frame")
loadingOverlay.Name = "LoadingOverlay"
loadingOverlay.Size = UDim2.fromScale(1, 1)
loadingOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
loadingOverlay.BorderSizePixel = 0
loadingOverlay.ZIndex = 9999
loadingOverlay.Parent = screen

local gifHolder = Instance.new("Frame")
gifHolder.Size = UDim2.fromOffset(400, 300)
gifHolder.Position = UDim2.new(0.5, -200, 0.5, -280)
gifHolder.BackgroundTransparency = 1
gifHolder.ZIndex = 10000
gifHolder.Parent = loadingOverlay

local gifImage = Instance.new("ImageLabel")
gifImage.Size = UDim2.fromScale(1, 1)
gifImage.BackgroundTransparency = 1
gifImage.ScaleType = Enum.ScaleType.Fit
gifImage.Image = ""
gifImage.ZIndex = 10001
gifImage.Parent = gifHolder

local progressBg = Instance.new("Frame")
progressBg.Size = UDim2.fromOffset(600, 20)
progressBg.Position = UDim2.new(0.5, -300, 0.5, 60)
progressBg.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
progressBg.BorderSizePixel = 0
progressBg.ZIndex = 10000
progressBg.Parent = loadingOverlay
Instance.new("UICorner", progressBg).CornerRadius = UDim.new(0, 10)

local progressFill = Instance.new("Frame")
progressFill.Size = UDim2.fromScale(0, 1)
progressFill.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
progressFill.BorderSizePixel = 0
progressFill.ZIndex = 10001
progressFill.Parent = progressBg
Instance.new("UICorner", progressFill).CornerRadius = UDim.new(0, 10)

local progressLabel = Instance.new("TextLabel")
progressLabel.Size = UDim2.fromOffset(600, 24)
progressLabel.Position = UDim2.new(0.5, -300, 0.5, 90)
progressLabel.BackgroundTransparency = 1
progressLabel.Text = "0%"
progressLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
progressLabel.TextSize = 18
progressLabel.Font = Enum.Font.GothamBold
progressLabel.ZIndex = 10000
progressLabel.Parent = loadingOverlay

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.fromOffset(600, 30)
statusLabel.Position = UDim2.new(0.5, -300, 0.5, 20)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "загрузка ассетов моделей скриптов картинок"
statusLabel.TextColor3 = Color3.fromRGB(180, 180, 190)
statusLabel.TextSize = 15
statusLabel.Font = Enum.Font.Gotham
statusLabel.ZIndex = 10000
statusLabel.Parent = loadingOverlay

-- GIF download
local gifAsset = ""
task.spawn(function()
    pcall(function()
        if writefile and isfile and getcustomasset and isfolder and makefolder then
            if not isfolder("shahed") then makefolder("shahed") end
            local gifPath = "shahed/loading.gif"
            if not isfile(gifPath) then
                local bytes = game:HttpGet(GIF_URL)
                if bytes and #bytes > 0 then
                    writefile(gifPath, bytes)
                end
            end
            if isfile(gifPath) then
                local ok, asset = pcall(getcustomasset, gifPath)
                if ok and asset then
                    gifAsset = asset
                    pcall(function() gifImage.Image = asset end)
                end
            end
        end
    end)
end)

local function setProgress(pct, txt)
    progressFill.Size = UDim2.fromScale(pct / 100, 1)
    progressLabel.Text = tostring(pct) .. "%"
    if txt then statusLabel.Text = txt end
end

task.spawn(function()
    local target = 100
    local current = 0
    while current < target do
        current = current + math.random(2, 5)
        if current > target then current = target end
        setProgress(current)
        task.wait(0.04)
    end
end)

-- Main UI hidden during loading
local uiRoot = Instance.new("Frame")
uiRoot.Size = UDim2.fromScale(1, 1)
uiRoot.BackgroundTransparency = 1
uiRoot.Visible = false
uiRoot.Parent = screen

local statusPlate = Instance.new("TextLabel")
statusPlate.Size = UDim2.fromOffset(760, 36)
statusPlate.Position = UDim2.new(0.5, -380, 0, 4)
statusPlate.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
statusPlate.BackgroundTransparency = 0.3
statusPlate.Text = ""
statusPlate.TextColor3 = Color3.fromRGB(255, 230, 100)
statusPlate.TextSize = 13
statusPlate.Font = Enum.Font.Code
statusPlate.TextWrapped = true
statusPlate.BorderSizePixel = 0
statusPlate.ZIndex = 500
statusPlate.Visible = false
statusPlate.Parent = uiRoot
Instance.new("UICorner", statusPlate).CornerRadius = UDim.new(0, 6)

local function setStatus(msg, persistent)
    statusPlate.Text = msg
    statusPlate.Visible = (msg ~= "")
    if msg ~= "" and not persistent then
        local myMsg = msg
        task.delay(15, function()
            if statusPlate.Text == myMsg then
                statusPlate.Text = ""
                statusPlate.Visible = false
            end
        end)
    end
end

local function loadAsset(id)
    if not id or id <= 0 then return nil, "no id" end
    local ok1, objs = pcall(function() return game:GetObjects("rbxassetid://" .. tostring(id)) end)
    if ok1 and objs and #objs > 0 then
        for _, o in ipairs(objs) do
            if o:IsA("Model") or o:IsA("Tool") then return o, "GetObjects" end
        end
        for _, o in ipairs(objs) do
            if o:IsA("BasePart") then return o, "GetObjects-part" end
        end
        return objs[1], "GetObjects-other"
    end
    local ok2, inst = pcall(function() return InsertService:LoadAsset(id) end)
    if ok2 and inst then
        local child = inst:FindFirstChildWhichIsA("Model")
        if child and child ~= inst then return child, "InsertService-inner" end
        return inst, "InsertService"
    end
    return nil, "failed"
end

local function prepareAndCheck(model)
    if not model then return 0, 0 end
    local count, visibleCount = 0, 0
    for _, p in ipairs(model:GetDescendants()) do
        if p:IsA("BasePart") then
            count = count + 1
            pcall(function()
                if p.Size.Magnitude < 0.5 then p.Size = Vector3.new(1, 1, 1) end
                if p.Transparency >= 1 then p.Transparency = 0 end
                p.Anchored = true
                p.CanCollide = false
                p.CanQuery = false
                p.CanTouch = false
                p.Massless = true
            end)
            if p.Transparency < 1 and p.Size.Magnitude > 0.5 then visibleCount = visibleCount + 1 end
        end
    end
    return count, visibleCount
end

local function setPrimary(model)
    if not model or not model:IsA("Model") then return end
    if model.PrimaryPart then return end
    for _, p in ipairs(model:GetDescendants()) do
        if p:IsA("BasePart") then
            pcall(function() model.PrimaryPart = p end)
            return
        end
    end
end

local function forceScale(model, targetSize)
    if not model then return end
    pcall(function()
        local extents = model:GetExtentsSize()
        if extents.Magnitude > 0.1 and extents.Magnitude < 3 then
            model:ScaleTo(targetSize / extents.Magnitude)
        elseif extents.Magnitude > 100 then
            model:ScaleTo(targetSize / extents.Magnitude)
        end
    end)
end

local function forcePlaceModel(model, targetCFrame)
    if not model then return false end
    local parts = {}
    for _, p in ipairs(model:GetDescendants()) do
        if p:IsA("BasePart") and p.Size.Magnitude > 0.1 then table.insert(parts, p) end
    end
    if #parts == 0 then return false end
    local fixedTarget = targetCFrame * CFrame.Angles(0, MODEL_YAW_FIX, 0)
    local primary = model.PrimaryPart or parts[1]
    local baseCF = primary.CFrame
    for _, p in ipairs(parts) do
        pcall(function()
            p.Anchored = true
            p.CanCollide = false
            p.CFrame = fixedTarget * (baseCF:Inverse() * p.CFrame)
        end)
    end
    return true
end

local function getSitOffset()
    if not droneObject then return 3.8 end
    local primary = droneObject.PrimaryPart or droneObject:FindFirstChildWhichIsA("BasePart")
    if not primary then return 3.8 end
    return primary.Size.Y / 2 + SIT_GAP
end

local function spawnExplosion(pos)
    local core = Instance.new("Part")
    core.Shape = Enum.PartType.Ball
    core.Size = Vector3.new(2, 2, 2)
    core.Position = pos
    core.Color = Color3.fromRGB(255, 200, 100)
    core.Material = Enum.Material.Neon
    core.Anchored = true
    core.CanCollide = false
    core.CanQuery = false
    core.CanTouch = false
    core.Transparency = 0.1
    core.Parent = workspace

    local emitter = Instance.new("ParticleEmitter")
    emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    emitter.Rate = 0
    emitter.Lifetime = NumberRange.new(0.5, 1.5)
    emitter.Speed = NumberRange.new(30, 70)
    emitter.SpreadAngle = Vector2.new(180, 180)
    emitter.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 4), NumberSequenceKeypoint.new(1, 0)})
    emitter.Color = ColorSequence.new(Color3.fromRGB(255, 180, 50))
    emitter.LightEmission = 1
    emitter.Parent = core
    emitter:Emit(200)

    local light = Instance.new("PointLight")
    light.Color = Color3.fromRGB(255, 150, 50)
    light.Range = 70
    light.Brightness = 20
    light.Parent = core

    task.spawn(function()
        for i = 1, 10 do
            task.wait(0.06)
            pcall(function()
                core.Size = core.Size + Vector3.new(4, 4, 4)
                core.Transparency = core.Transparency + 0.09
                light.Brightness = light.Brightness - 1.8
            end)
        end
        pcall(function() core:Destroy() end)
    end)

    local flash = Instance.new("Frame")
    flash.Size = UDim2.fromScale(1, 1)
    flash.BackgroundColor3 = Color3.fromRGB(255, 220, 140)
    flash.BackgroundTransparency = 0.1
    flash.BorderSizePixel = 0
    flash.ZIndex = 1000
    flash.Parent = uiRoot
    TweenService:Create(flash, TweenInfo.new(0.5), {BackgroundTransparency = 1}):Play()
    task.delay(0.6, function() pcall(function() flash:Destroy() end) end)
end

local function makeFallingWreck(drone, origColors)
    if not drone then return nil end
    local parts = {}
    for _, p in ipairs(drone:GetDescendants()) do
        if p:IsA("BasePart") then table.insert(parts, p) end
    end
    if #parts == 0 then pcall(function() drone:Destroy() end) return nil end
    local primary = drone.PrimaryPart or parts[1]

    for _, p in ipairs(parts) do
        if p ~= primary then
            for _, c in ipairs(p:GetChildren()) do
                if c:IsA("Weld") or c:IsA("WeldConstraint") or c:IsA("Motor6D") then
                    pcall(function() c:Destroy() end)
                end
            end
            local w = Instance.new("Weld")
            w.Part0 = primary
            w.Part1 = p
            w.C0 = primary.CFrame:Inverse() * p.CFrame
            w.Parent = p
            p.Anchored = false
            p.CanCollide = false
            p.Massless = true
        end
        if not origColors[p] then
            origColors[p] = {Color = p.Color, Material = p.Material, Transparency = p.Transparency}
        end
        p.Color = Color3.fromRGB(30, 25, 20)
        p.Material = Enum.Material.Slate
        p.CanQuery = false
        p.CanTouch = false
    end

    primary.Anchored = false
    primary.CanCollide = true
    primary.Massless = false
    primary.Color = Color3.fromRGB(30, 25, 20)
    primary.Material = Enum.Material.Slate

    local fire = Instance.new("Fire")
    fire.Size = 8
    fire.Heat = 12
    fire.Color = Color3.fromRGB(255, 120, 30)
    fire.SecondaryColor = Color3.fromRGB(255, 60, 0)
    fire.Parent = primary

    task.spawn(function()
        task.wait(0.3)
        local lastY = primary.Position.Y
        local sameCount = 0
        while primary and primary.Parent do
            task.wait(0.2)
            local curY = primary.Position.Y
            if math.abs(curY - lastY) < 0.3 then
                sameCount = sameCount + 1
                if sameCount >= 3 then
                    pcall(function()
                        primary.Anchored = true
                        primary.CanCollide = false
                    end)
                    break
                end
            else
                sameCount = 0
            end
            lastY = curY
        end
    end)

    return drone
end

local function buildFallbackTool()
    local tool = Instance.new("Tool")
    tool.Name = "Shahed Controller"
    tool.RequiresHandle = true
    tool.CanBeDropped = false
    tool.ToolTip = "Управление шахедом"

    local handle = Instance.new("Part")
    handle.Name = "Handle"
    handle.Size = Vector3.new(2, 1.2, 0.6)
    handle.Color = Color3.fromRGB(25, 25, 30)
    handle.Material = Enum.Material.Metal
    handle.Anchored = false
    handle.CanCollide = false
    handle.Massless = true
    handle.Transparency = 0
    handle.Parent = tool

    local scr = Instance.new("Part")
    scr.Size = Vector3.new(1.3, 0.8, 0.06)
    scr.Color = Color3.fromRGB(40, 200, 255)
    scr.Material = Enum.Material.Neon
    scr.Anchored = false
    scr.CanCollide = false
    scr.Massless = true
    scr.Parent = tool
    local w1 = Instance.new("Weld")
    w1.Part0 = handle; w1.Part1 = scr
    w1.C0 = CFrame.new(0, 0.15, -0.31); w1.Parent = handle

    return tool
end

local buildTool

local function buildFallbackDrone()
    local m = Instance.new("Model")
    m.Name = "ShahedDrone"

    local body = Instance.new("Part")
    body.Name = "Body"
    body.Size = Vector3.new(2, 2, 8)
    body.Color = Color3.fromRGB(200, 195, 175)
    body.Material = Enum.Material.SmoothPlastic
    body.Anchored = true
    body.CanCollide = false
    body.Parent = m

    local wingL = Instance.new("Part")
    wingL.Size = Vector3.new(8, 0.3, 3)
    wingL.Color = Color3.fromRGB(180, 175, 155)
    wingL.Anchored = true
    wingL.CanCollide = false
    wingL.CFrame = CFrame.new(-4.5, 0.3, 0.5) * CFrame.Angles(0, 0, math.rad(-8))
    wingL.Parent = m

    local wingR = wingL:Clone()
    wingR.CFrame = CFrame.new(4.5, 0.3, 0.5) * CFrame.Angles(0, 0, math.rad(8))
    wingR.Parent = m

    local nose = Instance.new("Part")
    nose.Shape = Enum.PartType.Ball
    nose.Size = Vector3.new(2.2, 2.2, 2.2)
    nose.Color = Color3.fromRGB(160, 45, 45)
    nose.Material = Enum.Material.Neon
    nose.Anchored = true
    nose.CanCollide = false
    nose.CFrame = CFrame.new(0, 0, -4.2)
    nose.Parent = m

    pcall(function() m.PrimaryPart = body end)
    return m
end

local function loadDrone()
    local inst, method = loadAsset(DRONE_ASSET_ID)
    droneMethod = method or "?"
    if inst then
        local m
        if inst:IsA("Model") then m = inst
        elseif inst:IsA("BasePart") then m = Instance.new("Model"); inst.Parent = m
        elseif inst:IsA("Tool") and inst:FindFirstChild("Handle") then
            m = Instance.new("Model"); inst.Handle:Clone().Parent = m; pcall(function() inst:Destroy() end)
        end
        if m then
            local cnt, vis = prepareAndCheck(m)
            if cnt > 0 and vis > 0 then
                setPrimary(m)
                forceScale(m, 12)
                m.Parent = workspace
                return m
            end
        end
        pcall(function() inst:Destroy() end)
    end
    droneMethod = "fallback"
    local f = buildFallbackDrone()
    f.Parent = workspace
    return f
end

buildTool = function()
    local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
    if not backpack then
        local ok, result = pcall(function() return LocalPlayer:WaitForChild("Backpack", 5) end)
        if ok and result then backpack = result end
    end
    if not backpack then return nil end

    if LocalPlayer.Character then
        local inHand = LocalPlayer.Character:FindFirstChild("Shahed Controller")
        if inHand then return inHand end
    end
    for _, x in ipairs(backpack:GetChildren()) do
        if x.Name == "Shahed Controller" then return x end
    end

    local inst, method = loadAsset(REMOTE_ASSET_ID)
    remoteMethod = method or "?"

    local function finalizeTool(t, handlePart)
        handlePart.Transparency = 0
        handlePart.Anchored = false
        handlePart.CanCollide = false
        handlePart.Massless = true
        if handlePart.Size.Magnitude < 1 then
            pcall(function() handlePart.Size = Vector3.new(2, 1.2, 0.6) end)
        end
        t.Grip = CFrame.new(0, -1.4, -1.2) * CFrame.Angles(math.rad(-20), math.rad(90), 0)
        t.Parent = backpack
    end

    if inst and inst:IsA("Tool") then
        local ok = pcall(function()
            local h = inst:FindFirstChild("Handle")
            if not h or not h:IsA("BasePart") then
                if h then h:Destroy() end
                h = Instance.new("Part")
                h.Name = "Handle"
                h.Size = Vector3.new(2, 1.2, 0.6)
                h.Color = Color3.fromRGB(25, 25, 30)
                h.Material = Enum.Material.Metal
                h.Parent = inst
            end
            for _, p in ipairs(inst:GetDescendants()) do
                if p:IsA("BasePart") and p ~= h then
                    p.Anchored = false; p.CanCollide = false; p.Massless = true
                end
            end
            inst.Name = "Shahed Controller"
            inst.RequiresHandle = true
            inst.CanBeDropped = false
            finalizeTool(inst, h)
        end)
        if ok then return inst end
        pcall(function() inst:Destroy() end)
    end

    if inst then
        local ok, tool = pcall(function()
            local parts = {}
            if inst:IsA("BasePart") then table.insert(parts, inst)
            else
                for _, p in ipairs(inst:GetDescendants()) do
                    if p:IsA("BasePart") then table.insert(parts, p) end
                end
            end
            if #parts == 0 then error("no parts", 0) end

            local largest = parts[1]
            for _, p in ipairs(parts) do
                if p.Size.Magnitude > largest.Size.Magnitude then largest = p end
            end
            local baseCFrame = largest.CFrame
            local rel = {}
            for _, p in ipairs(parts) do rel[p] = baseCFrame:Inverse() * p.CFrame end
            for _, p in ipairs(parts) do
                for _, d in ipairs(p:GetChildren()) do
                    if d:IsA("JointInstance") or d:IsA("Motor6D") or d:IsA("WeldConstraint") then
                        pcall(function() d:Destroy() end)
                    end
                end
            end

            local t = Instance.new("Tool")
            t.Name = "Shahed Controller"
            t.RequiresHandle = true
            t.CanBeDropped = false
            largest.Name = "Handle"
            largest.Parent = t
            for _, p in ipairs(parts) do
                if p ~= largest then
                    p.Anchored = false; p.CanCollide = false; p.Massless = true
                    if p.Size.Magnitude < 0.3 then p.Size = Vector3.new(1, 1, 1) end
                    p.Parent = t
                    local w = Instance.new("Weld")
                    w.Part0 = largest; w.Part1 = p; w.C0 = rel[p]
                    w.Parent = p
                end
            end
            pcall(function() inst:Destroy() end)
            finalizeTool(t, largest)
            return t
        end)
        if ok and tool then return tool end
        pcall(function() inst:Destroy() end)
    end

    remoteMethod = "fallback"
    local tool = buildFallbackTool()
    tool.Grip = CFrame.new(0, -1.4, -1.2) * CFrame.Angles(math.rad(-20), math.rad(90), 0)
    tool.Parent = backpack
    return tool
end

local function makeBtn(size, pos, color, text, tsize)
    local b = Instance.new("TextButton")
    b.Size = size
    b.Position = pos
    b.BackgroundColor3 = color
    b.Text = text
    b.TextColor3 = Color3.fromRGB(255, 255, 255)
    b.TextSize = tsize or 14
    b.Font = Enum.Font.GothamBold
    b.Visible = false
    b.BorderSizePixel = 0
    b.Parent = uiRoot
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
    return b
end

local launchBtn = Instance.new("TextButton")
launchBtn.Size = UDim2.fromOffset(240, 72)
launchBtn.Position = UDim2.new(0.5, -120, 1, -120)
launchBtn.BackgroundColor3 = Color3.fromRGB(0, 170, 40)
launchBtn.Text = "PLAY"
launchBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
launchBtn.TextSize = 26
launchBtn.Font = Enum.Font.GothamBold
launchBtn.Visible = false
launchBtn.BorderSizePixel = 0
launchBtn.Parent = uiRoot
Instance.new("UICorner", launchBtn).CornerRadius = UDim.new(0, 12)
local lbStroke = Instance.new("UIStroke")
lbStroke.Color = Color3.fromRGB(255, 255, 255)
lbStroke.Thickness = 2
lbStroke.Parent = launchBtn

local putAwayBtn = Instance.new("TextButton")
putAwayBtn.Size = UDim2.fromOffset(85, 30)
putAwayBtn.Position = UDim2.new(0, 8, 0, 8)
putAwayBtn.BackgroundColor3 = Color3.fromRGB(100, 30, 30)
putAwayBtn.Text = "УБРАТЬ"
putAwayBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
putAwayBtn.TextSize = 11
putAwayBtn.Font = Enum.Font.GothamBold
putAwayBtn.Visible = false
putAwayBtn.BorderSizePixel = 0
putAwayBtn.Parent = uiRoot
Instance.new("UICorner", putAwayBtn).CornerRadius = UDim.new(0, 6)

local stopBtn    = makeBtn(UDim2.fromOffset(90, 40),  UDim2.new(1, -110, 0, 44),  Color3.fromRGB(180, 30, 30),  "СПРЫГНУТЬ", 11)
local boostBtn   = makeBtn(UDim2.fromOffset(70, 40),  UDim2.new(1, -190, 0, 44),  Color3.fromRGB(200, 100, 20), "BOOST", 12)
local fovBtn     = makeBtn(UDim2.fromOffset(70, 40),  UDim2.new(1, -270, 0, 44),  Color3.fromRGB(40, 80, 180),  "1ST",   12)
local freezeBtn  = makeBtn(UDim2.fromOffset(70, 40),  UDim2.new(1, -350, 0, 44),  Color3.fromRGB(80, 80, 80),   "HOLD",  12)
local noclipBtn  = makeBtn(UDim2.fromOffset(70, 40),  UDim2.new(1, -430, 0, 44),  Color3.fromRGB(60, 60, 100),  "NOCLIP", 11)
local rocketBtn  = makeBtn(UDim2.fromOffset(140, 70), UDim2.new(1, -160, 1, -100), Color3.fromRGB(200, 60, 20), "РАКЕТА", 20)
local repairBtn  = makeBtn(UDim2.fromOffset(180, 60), UDim2.new(0.5, -90, 1, -200), Color3.fromRGB(200, 150, 20), "РЕМОНТ", 16)
local rideBtn    = makeBtn(UDim2.fromOffset(180, 60), UDim2.new(0.5, -90, 1, -200), Color3.fromRGB(0, 150, 200), "СЕСТЬ", 16)

local hud = Instance.new("Frame")
hud.Size = UDim2.fromScale(1, 1)
hud.BackgroundTransparency = 1
hud.Visible = false
hud.Parent = uiRoot

local function corner(xS, yS, wSign, hSign)
    local h = Instance.new("Frame")
    h.Size = UDim2.fromOffset(60, 3)
    h.Position = UDim2.new(xS, wSign * 60 * -1, yS, 0)
    h.BackgroundColor3 = Color3.fromRGB(0, 255, 100)
    h.BorderSizePixel = 0
    h.Parent = hud
    local v = Instance.new("Frame")
    v.Size = UDim2.fromOffset(3, 60)
    v.Position = UDim2.new(xS, wSign * 3 * -1, yS, hSign * 60 * -1)
    v.BackgroundColor3 = Color3.fromRGB(0, 255, 100)
    v.BorderSizePixel = 0
    v.Parent = hud
end
corner(0.02, 0.05, 1, 1)
corner(0.98, 0.05, -1, 1)
corner(0.02, 0.95, 1, -1)
corner(0.98, 0.95, -1, -1)

local batteryLbl = Instance.new("TextLabel")
batteryLbl.Size = UDim2.fromOffset(360, 32)
batteryLbl.Position = UDim2.new(0.5, -180, 0, 60)
batteryLbl.BackgroundTransparency = 1
batteryLbl.Text = "BATTERY: 100%"
batteryLbl.TextColor3 = Color3.fromRGB(0, 255, 100)
batteryLbl.TextSize = 22
batteryLbl.Font = Enum.Font.Code
batteryLbl.Parent = hud

local speedLbl = Instance.new("TextLabel")
speedLbl.Size = UDim2.fromOffset(500, 26)
speedLbl.Position = UDim2.new(0.5, -250, 1, -55)
speedLbl.BackgroundTransparency = 1
speedLbl.Text = "AUTO | SPEED: 0 | ALT: 0"
speedLbl.TextColor3 = Color3.fromRGB(0, 255, 100)
speedLbl.TextSize = 16
speedLbl.Font = Enum.Font.Code
speedLbl.Parent = hud

local fpsLbl = Instance.new("TextLabel")
fpsLbl.Size = UDim2.fromOffset(120, 20)
fpsLbl.Position = UDim2.new(0, 12, 0, 12)
fpsLbl.BackgroundTransparency = 1
fpsLbl.Text = "FPS: 0"
fpsLbl.TextColor3 = Color3.fromRGB(0, 255, 100)
fpsLbl.TextSize = 14
fpsLbl.Font = Enum.Font.Code
fpsLbl.TextXAlignment = Enum.TextXAlignment.Left
fpsLbl.Parent = hud

local repairGui = Instance.new("Frame")
repairGui.Size = UDim2.fromOffset(400, 80)
repairGui.Position = UDim2.new(0.5, -200, 0.7, 0)
repairGui.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
repairGui.BorderSizePixel = 0
repairGui.Visible = false
repairGui.Parent = uiRoot
Instance.new("UICorner", repairGui).CornerRadius = UDim.new(0, 10)
local rpStroke = Instance.new("UIStroke")
rpStroke.Color = Color3.fromRGB(200, 150, 20)
rpStroke.Thickness = 2
rpStroke.Parent = repairGui

local repairLbl = Instance.new("TextLabel")
repairLbl.Size = UDim2.new(1, 0, 0, 24)
repairLbl.Position = UDim2.fromOffset(0, 6)
repairLbl.BackgroundTransparency = 1
repairLbl.Text = "РЕМОНТ..."
repairLbl.TextColor3 = Color3.fromRGB(255, 220, 100)
repairLbl.TextSize = 16
repairLbl.Font = Enum.Font.GothamBold
repairLbl.Parent = repairGui

local repairBarBg = Instance.new("Frame")
repairBarBg.Size = UDim2.new(1, -20, 0, 20)
repairBarBg.Position = UDim2.new(0, 10, 0, 40)
repairBarBg.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
repairBarBg.BorderSizePixel = 0
repairBarBg.Parent = repairGui
Instance.new("UICorner", repairBarBg).CornerRadius = UDim.new(0, 10)

local repairBarFill = Instance.new("Frame")
repairBarFill.Size = UDim2.fromScale(0, 1)
repairBarFill.BackgroundColor3 = Color3.fromRGB(200, 150, 20)
repairBarFill.BorderSizePixel = 0
repairBarFill.Parent = repairBarBg
Instance.new("UICorner", repairBarFill).CornerRadius = UDim.new(0, 10)

local crashGui = Instance.new("Frame")
crashGui.Size = UDim2.fromScale(1, 1)
crashGui.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
crashGui.BorderSizePixel = 0
crashGui.Visible = false
crashGui.ZIndex = 100
crashGui.Parent = uiRoot

local staticBg = Instance.new("Frame")
staticBg.Size = UDim2.fromScale(1, 1)
staticBg.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
staticBg.BackgroundTransparency = 0.6
staticBg.ZIndex = 101
staticBg.Parent = crashGui

local glitchLines = {}
for i = 1, 10 do
    local line = Instance.new("Frame")
    line.Size = UDim2.new(1, 0, 0, math.random(2, 10))
    line.Position = UDim2.new(0, 0, math.random(), 0)
    line.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    line.BackgroundTransparency = 0.7
    line.ZIndex = 102
    line.Parent = crashGui
    table.insert(glitchLines, line)
end

local noConnect = Instance.new("TextLabel")
noConnect.Size = UDim2.fromOffset(800, 120)
noConnect.Position = UDim2.new(0.5, -400, 0.5, -60)
noConnect.BackgroundTransparency = 1
noConnect.Text = "NO CONNECT"
noConnect.TextColor3 = Color3.fromRGB(255, 30, 30)
noConnect.TextSize = 90
noConnect.Font = Enum.Font.Code
noConnect.ZIndex = 103
noConnect.Parent = crashGui

local function setBackpack(vis)
    pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, vis) end)
end

local function safeRestore()
    if camSubject then pcall(function() camSubject:Destroy() end) camSubject = nil end

    local char = LocalPlayer.Character
    if char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then pcall(function() hrp.Anchored = false end) end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            pcall(function() hum.Sit = false end)
            pcall(function() hum.WalkSpeed = 16 end)
            pcall(function() hum.JumpPower = 50 end)
            pcall(function()
                Camera.CameraType = Enum.CameraType.Custom
                Camera.CameraSubject = hum
            end)
        end
        local anim = char:FindFirstChild("Animate")
        if anim then pcall(function() anim.Disabled = false end) end
    end

    pcall(function() LocalPlayer.CameraMinZoomDistance = 0.5 end)
    pcall(function() LocalPlayer.CameraMaxZoomDistance = 128 end)
    setBackpack(true)

    droneMode, crashed, frozen, ultraBoost = false, false, false, false
    droneCFrame = nil
    riddenWreck = nil
    droneObject = nil
    hud.Visible = false
    stopBtn.Visible, boostBtn.Visible, fovBtn.Visible, freezeBtn.Visible, rocketBtn.Visible = false, false, false, false, false
    noclipBtn.Visible = false
    noclip = false
    noclipBtn.Text = "NOCLIP"
    noclipBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 100)
    crashGui.Visible = false
    noConnect.Visible = true
    launchBtn.Visible = true
    repairBtn.Visible = false
    rideBtn.Visible = false
    repairGui.Visible = false
    boostBtn.Text, boostBtn.BackgroundColor3 = "BOOST", Color3.fromRGB(200, 100, 20)
    freezeBtn.Text, freezeBtn.BackgroundColor3 = "HOLD", Color3.fromRGB(80, 80, 80)
    statusPlate.Text = ""
    statusPlate.Visible = false
end

local function fireRocket()
    if not droneMode or not droneCFrame then return end
    local now = os.clock()
    if now - lastRocket < ROCKET_COOLDOWN then return end
    lastRocket = now

    local startPos = droneCFrame.Position
    local dir = droneCFrame.LookVector
    if dir.Magnitude < 0.1 then dir = Vector3.new(0, 0, -1) end
    dir = dir.Unit

    local rocket = Instance.new("Part")
    rocket.Shape = Enum.PartType.Cylinder
    rocket.Size = Vector3.new(0.6, 0.6, 3)
    rocket.CFrame = CFrame.lookAt(startPos + dir * 4, startPos + dir * 4 + dir) * CFrame.Angles(0, math.rad(90), 0)
    rocket.Color = Color3.fromRGB(255, 130, 40)
    rocket.Material = Enum.Material.Neon
    rocket.Anchored = true
    rocket.CanCollide = false
    rocket.CanQuery = false
    rocket.CanTouch = false
    rocket.Parent = workspace

    local trail = Instance.new("Trail")
    trail.Lifetime = 0.5
    trail.Color = ColorSequence.new(Color3.fromRGB(255, 200, 80), Color3.fromRGB(255, 60, 0))
    trail.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1)})
    local a0 = Instance.new("Attachment"); a0.Parent = rocket; a0.Position = Vector3.new(0, 1.5, 0)
    local a1 = Instance.new("Attachment"); a1.Parent = rocket; a1.Position = Vector3.new(0, -1.5, 0)
    trail.Attachment0 = a0; trail.Attachment1 = a1
    trail.Parent = rocket

    task.spawn(function()
        local travelled = 0
        local rp = RaycastParams.new()
        rp.FilterType = Enum.RaycastFilterType.Exclude
        rp.FilterDescendantsInstances = {rocket, droneObject, LocalPlayer.Character, camSubject}
        while rocket.Parent and travelled < ROCKET_RANGE do
            local dt = task.wait(0.02)
            local stepDist = ROCKET_SPEED * dt
            local nextPos = rocket.Position + dir * stepDist
            rocket.CFrame = CFrame.lookAt(nextPos, nextPos + dir) * CFrame.Angles(0, math.rad(90), 0)
            travelled = travelled + stepDist

            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer and plr.Character then
                    local tHRP = plr.Character:FindFirstChild("HumanoidRootPart")
                    local tHum = plr.Character:FindFirstChildOfClass("Humanoid")
                    if tHRP and tHum and tHum.Health > 0 then
                        if (tHRP.Position - rocket.Position).Magnitude < ROCKET_RADIUS then
                            local impactPos = rocket.Position
                            spawnExplosion(impactPos)
                            pcall(function() tHum:TakeDamage(ROCKET_DAMAGE) end)
                            pcall(function() tHum.Health = 0 end)
                            if firetouchinterest then
                                pcall(function()
                                    firetouchinterest(rocket, tHRP, 0)
                                    task.wait(0.03)
                                    firetouchinterest(rocket, tHRP, 1)
                                end)
                            end
                            if sethiddenproperty then
                                pcall(function() sethiddenproperty(tHum, "Health", 0) end)
                            end
                            for _, plr2 in ipairs(Players:GetPlayers()) do
                                if plr2 ~= LocalPlayer and plr2.Character then
                                    local t2HRP = plr2.Character:FindFirstChild("HumanoidRootPart")
                                    local t2Hum = plr2.Character:FindFirstChildOfClass("Humanoid")
                                    if t2HRP and t2Hum and t2Hum.Health > 0 then
                                        if (t2HRP.Position - impactPos).Magnitude < ROCKET_RADIUS then
                                            pcall(function() t2Hum:TakeDamage(ROCKET_DAMAGE) end)
                                            pcall(function() t2Hum.Health = 0 end)
                                        end
                                    end
                                end
                            end
                            pcall(function() rocket:Destroy() end)
                            return
                        end
                    end
                end
            end

            local hit = workspace:Raycast(rocket.Position, dir * (stepDist + 1), rp)
            if hit then
                local impactPos = hit.Position
                spawnExplosion(impactPos)
                for _, plr in ipairs(Players:GetPlayers()) do
                    if plr ~= LocalPlayer and plr.Character then
                        local tHRP = plr.Character:FindFirstChild("HumanoidRootPart")
                        local tHum = plr.Character:FindFirstChildOfClass("Humanoid")
                        if tHRP and tHum and tHum.Health > 0 then
                            if (tHRP.Position - impactPos).Magnitude < ROCKET_RADIUS then
                                pcall(function() tHum:TakeDamage(ROCKET_DAMAGE) end)
                                pcall(function() tHum.Health = 0 end)
                                if firetouchinterest then
                                    pcall(function()
                                        firetouchinterest(rocket, tHRP, 0)
                                        task.wait(0.03)
                                        firetouchinterest(rocket, tHRP, 1)
                                    end)
                                end
                                if sethiddenproperty then
                                    pcall(function() sethiddenproperty(tHum, "Health", 0) end)
                                end
                            end
                        end
                    end
                end
                pcall(function() rocket:Destroy() end)
                return
            end
        end
        if rocket.Parent then
            spawnExplosion(rocket.Position)
            pcall(function() rocket:Destroy() end)
        end
    end)
end

local function jumpOff()
    if not droneMode or not riddenWreck then return end
    local w = riddenWreck
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")

    if w.model then
        for _, p in ipairs(w.model:GetDescendants()) do
            if p:IsA("BasePart") then
                p.Anchored = true
                p.CanCollide = false
                p.CanQuery = false
                p.CanTouch = false
            end
        end
    end

    droneMode = false
    crashed = false
    droneObject = nil
    riddenWreck = nil
    noclip = false
    if camSubject then pcall(function() camSubject:Destroy() end) camSubject = nil end

    hud.Visible = false
    stopBtn.Visible, boostBtn.Visible, fovBtn.Visible, freezeBtn.Visible, rocketBtn.Visible = false, false, false, false, false
    noclipBtn.Visible = false
    noclipBtn.Text = "NOCLIP"
    noclipBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 100)
    setBackpack(true)
    pcall(function() LocalPlayer.CameraMinZoomDistance = 0.5 end)
    pcall(function() LocalPlayer.CameraMaxZoomDistance = 128 end)

    if char and hum and hrp then
        hrp.Anchored = false
        hrp.CanCollide = true
        pcall(function() hum.Sit = false end)
        hum.WalkSpeed = 16
        hum.JumpPower = 50
        Camera.CameraType = Enum.CameraType.Custom
        Camera.CameraSubject = hum
        local anim = char:FindFirstChild("Animate")
        if anim then pcall(function() anim.Disabled = false end) end
    end
    droneCFrame = nil
end

local function launchDrone()
    if droneMode or repairing then return false end

    local char = LocalPlayer.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end

    for _, w in ipairs(wrecks) do
        if w.repaired and w.rideable and w.model and w.model.Parent then
            if mountWreck then
                local ok, result = pcall(mountWreck, w)
                if ok and result then return true end
            end
        end
    end

    for i = #wrecks, 1, -1 do
        local w = wrecks[i]
        if not w.repaired then
            pcall(function() if w.model then w.model:Destroy() end end)
            table.remove(wrecks, i)
        end
    end

    local dObj = loadDrone()
    if not dObj then return false end

    local spawnPos = hrp.Position + Vector3.new(0, SPAWN_HEIGHT, 0)
    if not forcePlaceModel(dObj, CFrame.new(spawnPos)) then
        pcall(function() dObj:Destroy() end)
        dObj = buildFallbackDrone()
        dObj.Parent = workspace
        forcePlaceModel(dObj, CFrame.new(spawnPos))
        droneMethod = "fallback-forced"
    end

    droneObject = dObj
    droneCFrame = CFrame.new(spawnPos)
    riddenWreck = nil

    hrp.Anchored = true
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then hum.WalkSpeed = 0; hum.JumpPower = 0 end
    local anim = char:FindFirstChild("Animate")
    if anim then anim.Disabled = true end

    camSubject = Instance.new("Part")
    camSubject.Name = "ShahedCamSubject"
    camSubject.Anchored = true
    camSubject.CanCollide = false
    camSubject.CanQuery = false
    camSubject.CanTouch = false
    camSubject.Transparency = 1
    camSubject.Size = Vector3.new(0.5, 0.5, 0.5)
    camSubject.CFrame = droneCFrame
    camSubject.Parent = workspace

    firstPerson = true
    pcall(function() LocalPlayer.CameraMinZoomDistance = 0.5 end)
    pcall(function() LocalPlayer.CameraMaxZoomDistance = 3 end)
    Camera.CameraType = Enum.CameraType.Custom
    Camera.CameraSubject = camSubject

    setBackpack(false)

    droneMode = true
    crashed = false
    frozen = false
    ultraBoost = false
    noclip = false
    battery = 100
    lastRocket = 0
    noCrashUntil = os.clock() + GRACE_PERIOD
    hud.Visible = true
    stopBtn.Visible, boostBtn.Visible, fovBtn.Visible, freezeBtn.Visible, noclipBtn.Visible = true, true, true, true, true
    stopBtn.Text = "STOP"
    rocketBtn.Visible = false
    launchBtn.Visible = false
    repairBtn.Visible = false
    rideBtn.Visible = false
    noclipBtn.Text = "NOCLIP"
    noclipBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 100)
    return true
end

mountWreck = function(w)
    if not w or not w.repaired or not w.rideable or not w.model or not w.model.Parent then return false end
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return false end

    for _, p in ipairs(w.model:GetDescendants()) do
        if p:IsA("BasePart") then
            p.Anchored = true
            p.CanCollide = false
        end
    end

    local primary = w.model.PrimaryPart or w.model:FindFirstChildWhichIsA("BasePart")
    if not primary then return false end

    droneObject = w.model
    droneCFrame = primary.CFrame
    riddenWreck = w

    hrp.Anchored = true
    pcall(function() hrp.CanCollide = false end)
    pcall(function() hum.Sit = false end)
    hum.WalkSpeed = 0
    hum.JumpPower = 0

    local sitY = primary.Position.Y + primary.Size.Y / 2 + SIT_GAP
    local basePos = Vector3.new(primary.Position.X, sitY, primary.Position.Z)
    hrp.CFrame = CFrame.lookAt(basePos, basePos + primary.CFrame.LookVector)

    battery = 100
    lastRocket = 0

    firstPerson = false
    pcall(function() LocalPlayer.CameraMinZoomDistance = 8 end)
    pcall(function() LocalPlayer.CameraMaxZoomDistance = 16 end)
    Camera.CameraType = Enum.CameraType.Custom
    Camera.CameraSubject = hum

    setBackpack(false)

    droneMode = true
    crashed = false
    frozen = false
    ultraBoost = false
    noclip = false
    noCrashUntil = os.clock() + GRACE_PERIOD
    hud.Visible = true
    stopBtn.Visible, boostBtn.Visible, fovBtn.Visible, freezeBtn.Visible, noclipBtn.Visible, rocketBtn.Visible = true, true, true, true, true, true
    stopBtn.Text = "СПРЫГНУТЬ"
    launchBtn.Visible = false
    repairBtn.Visible = false
    rideBtn.Visible = false
    fovBtn.Text = "1ST"
    fovBtn.BackgroundColor3 = Color3.fromRGB(40, 80, 180)
    noclipBtn.Text = "NOCLIP"
    noclipBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 100)
    batteryLbl.Text = "BATTERY: 100%"
    return true
end

local function crash()
    if crashed or not droneMode then return end
    crashed = true
    droneMode = false

    local crashPos = droneCFrame and droneCFrame.Position or Vector3.new(0, 50, 0)
    spawnExplosion(crashPos)

    if droneObject then
        local origColors = {}
        local wreck = makeFallingWreck(droneObject, origColors)
        if wreck then
            table.insert(wrecks, {
                model = wreck,
                position = crashPos,
                repaired = false,
                rideable = false,
                originalColors = origColors,
            })
        end
        droneObject = nil
    end

    hud.Visible = false
    stopBtn.Visible, boostBtn.Visible, fovBtn.Visible, freezeBtn.Visible, rocketBtn.Visible, noclipBtn.Visible = false, false, false, false, false, false
    launchBtn.Visible = false
    riddenWreck = nil
    noclip = false

    task.spawn(function()
        task.wait(EXPLOSION_TIME)
        crashGui.Visible = true
        noConnect.Visible = true
        local start = os.clock()
        while (os.clock() - start) < (CRASH_TOTAL - EXPLOSION_TIME) do
            for _, line in ipairs(glitchLines) do
                pcall(function()
                    line.Position = UDim2.new(0, 0, math.random(), 0)
                    line.BackgroundTransparency = math.random(40, 90) / 100
                end)
            end
            pcall(function()
                staticBg.BackgroundColor3 = Color3.fromRGB(math.random(15, 70), math.random(15, 70), math.random(15, 70))
            end)
            noConnect.Visible = math.random() > 0.25
            task.wait(0.05)
        end
        safeRestore()
    end)
end

local function startRepair(w)
    if not w or w.repaired or repairing then return end
    repairing = true
    repairBtn.Visible = false
    rideBtn.Visible = false
    repairGui.Visible = true
    repairBarFill.Size = UDim2.fromScale(0, 1)

    local char = LocalPlayer.Character
    if char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local primary = w.model.PrimaryPart or w.model:FindFirstChildWhichIsA("BasePart")
        if hrp and primary then
            hrp.Anchored = true
            hrp.CFrame = primary.CFrame * CFrame.new(0, 2, 0)
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                hum.WalkSpeed = 0
                hum.JumpPower = 0
            end
        end
    end

    task.spawn(function()
        local startT = os.clock()
        while repairing and (os.clock() - startT) < REPAIR_TIME do
            local t = (os.clock() - startT) / REPAIR_TIME
            repairBarFill.Size = UDim2.fromScale(math.clamp(t, 0, 1), 1)
            task.wait(0.05)
        end
        if not repairing then return end

        w.repaired = true
        w.rideable = true
        repairing = false
        repairGui.Visible = false

        local primary = w.model.PrimaryPart or w.model:FindFirstChildWhichIsA("BasePart")
        if primary then
            for _, c in ipairs(primary:GetChildren()) do
                if c:IsA("Fire") or c:IsA("Smoke") then
                    pcall(function() c:Destroy() end)
                end
            end
        end

        for p, saved in pairs(w.originalColors) do
            pcall(function()
                if p and p.Parent then
                    p.Color = saved.Color
                    p.Material = saved.Material
                    p.Transparency = saved.Transparency
                end
            end)
        end

        for _, p in ipairs(w.model:GetDescendants()) do
            if p:IsA("BasePart") then
                p.Anchored = true
                p.CanCollide = false
            end
        end

        local char = LocalPlayer.Character
        if char then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then hrp.Anchored = false end
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                hum.WalkSpeed = 16
                hum.JumpPower = 50
            end
        end
    end)
end

local function wireTool(t)
    if not t then return end
    currentController = t
    pcall(function()
        t.Equipped:Connect(function()
            userHoldingController = true
            putAwayBtn.Visible = true
            if droneMode or repairing then return end
            launchBtn.Visible = true
        end)
        t.Unequipped:Connect(function()
            task.delay(0.15, function()
                if not userHoldingController then
                    launchBtn.Visible = false
                    putAwayBtn.Visible = false
                    return
                end
                local char = LocalPlayer.Character
                if not char then return end
                local hum = char:FindFirstChildOfClass("Humanoid")
                if not hum then return end

                local inHand = char:FindFirstChildOfClass("Tool")
                if inHand and inHand ~= t then
                    userHoldingController = false
                    launchBtn.Visible = false
                    putAwayBtn.Visible = false
                    return
                end

                if droneMode or crashed or repairing then
                    return
                end

                if t.Parent and not inHand then
                    pcall(function() hum:EquipTool(t) end)
                end
            end)
        end)
    end)
end

putAwayBtn.MouseButton1Click:Connect(function()
    userHoldingController = false
    launchBtn.Visible = false
    putAwayBtn.Visible = false
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then
        pcall(function() hum:UnequipTools() end)
    end
end)

RunService.Heartbeat:Connect(function()
    if not droneMode or crashed then return end
    local char = LocalPlayer.Character
    if not char then return end

    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        if hum.WalkSpeed ~= 0 then hum.WalkSpeed = 0 end
        if hum.JumpPower ~= 0 then hum.JumpPower = 0 end
    end

    if riddenWreck and droneCFrame then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.Anchored = true
            hrp.CanCollide = false
            local basePos = droneCFrame.Position + Vector3.new(0, getSitOffset(), 0)
            hrp.CFrame = CFrame.lookAt(basePos, basePos + droneCFrame.LookVector)
        end
    end
end)

RunService.RenderStepped:Connect(function(dt)
    fpsFrames = fpsFrames + 1
    fpsTime = fpsTime + dt
    if fpsTime >= 0.5 then
        fps = math.floor(fpsFrames / fpsTime)
        fpsFrames, fpsTime = 0, 0
        if droneMode then fpsLbl.Text = "FPS: " .. fps end
    end

    if droneMode and not crashed and droneObject and droneCFrame then
        battery = math.max(0, battery - BATTERY_DRAIN * dt)
        if battery <= 0 then crash() return end

        local camLook = Camera.CFrame.LookVector
        if camLook.X ~= camLook.X or camLook.Magnitude < 0.1 then camLook = Vector3.new(0, 0, -1) end
        local flatLook = Vector3.new(camLook.X, camLook.Y * 0.3, camLook.Z)
        if flatLook.Magnitude < 0.01 then flatLook = Vector3.new(0, 0, -1) end
        flatLook = flatLook.Unit

        local speed = BASE_SPEED
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then speed = BOOST_SPEED end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then speed = BASE_SPEED * 0.3 end
        if ultraBoost then speed = ULTRA_SPEED end
        if frozen then speed = 0 end

        local targetCF = CFrame.lookAt(droneCFrame.Position, droneCFrame.Position + flatLook)
        droneCFrame = droneCFrame:Lerp(targetCF, math.min(1, dt * 5))
        if not frozen then
            droneCFrame = droneCFrame + flatLook * speed * dt
        end

        forcePlaceModel(droneObject, droneCFrame)

        if riddenWreck then
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then
                hrp.Anchored = true
                hrp.CanCollide = false
                local basePos = droneCFrame.Position + Vector3.new(0, getSitOffset(), 0)
                hrp.CFrame = CFrame.lookAt(basePos, basePos + droneCFrame.LookVector)
            end
        elseif camSubject then
            if firstPerson then
                camSubject.CFrame = droneCFrame * CFrame.new(0, 0, -4)
            else
                camSubject.CFrame = droneCFrame
            end
        end

        if not noclip and not frozen and os.clock() > noCrashUntil then
            rayParams.FilterDescendantsInstances = {droneObject, camSubject, LocalPlayer.Character}
            local hit = workspace:Raycast(droneCFrame.Position, flatLook * CRASH_DIST, rayParams)
            if hit then
                crash()
                return
            end
        end

        batteryLbl.Text = string.format("BATTERY: %d%%", math.floor(battery))
        local mode = frozen and "HOLD" or (ultraBoost and "ULTRA" or "AUTO")
        if noclip then mode = mode .. " | NOCLIP" end
        speedLbl.Text = string.format("%s | SPEED: %d | ALT: %d | FPS: %d", mode, math.floor(speed * 1.4), math.floor(droneCFrame.Position.Y), fps)
    end

    if not droneMode and not repairing and not crashed then
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then
            local nearestUnrepaired, nearestRepaired
            for _, w in ipairs(wrecks) do
                if w.model and w.model.Parent then
                    local primary = w.model.PrimaryPart or w.model:FindFirstChildWhichIsA("BasePart")
                    if primary then
                        local d = (hrp.Position - primary.Position).Magnitude
                        if d < WRECK_RANGE then
                            if w.repaired and w.rideable then
                                nearestRepaired = w
                            elseif not w.repaired then
                                nearestUnrepaired = w
                            end
                        end
                    end
                end
            end
            repairBtn.Visible = nearestUnrepaired ~= nil
            rideBtn.Visible = nearestRepaired ~= nil
        else
            repairBtn.Visible = false
            rideBtn.Visible = false
        end
    elseif not repairing then
        repairBtn.Visible = false
        rideBtn.Visible = false
    end
end)

boostBtn.MouseButton1Click:Connect(function()
    ultraBoost = not ultraBoost
    boostBtn.Text = ultraBoost and "ULTRA!" or "BOOST"
    boostBtn.BackgroundColor3 = ultraBoost and Color3.fromRGB(255, 140, 30) or Color3.fromRGB(200, 100, 20)
end)

fovBtn.MouseButton1Click:Connect(function()
    firstPerson = not firstPerson
    fovBtn.Text = firstPerson and "3RD" or "1ST"
    fovBtn.BackgroundColor3 = firstPerson and Color3.fromRGB(200, 50, 150) or Color3.fromRGB(40, 80, 180)
    if firstPerson then
        pcall(function() LocalPlayer.CameraMinZoomDistance = 0.5 end)
        pcall(function() LocalPlayer.CameraMaxZoomDistance = 3 end)
    else
        pcall(function() LocalPlayer.CameraMinZoomDistance = 8 end)
        pcall(function() LocalPlayer.CameraMaxZoomDistance = 16 end)
    end
end)

freezeBtn.MouseButton1Click:Connect(function()
    frozen = not frozen
    freezeBtn.Text = frozen and "GO" or "HOLD"
    freezeBtn.BackgroundColor3 = frozen and Color3.fromRGB(100, 200, 100) or Color3.fromRGB(80, 80, 80)
end)

noclipBtn.MouseButton1Click:Connect(function()
    noclip = not noclip
    noclipBtn.Text = noclip and "NOCLIP ON" or "NOCLIP"
    noclipBtn.BackgroundColor3 = noclip and Color3.fromRGB(0, 200, 100) or Color3.fromRGB(60, 60, 100)
end)

rocketBtn.MouseButton1Click:Connect(fireRocket)

stopBtn.MouseButton1Click:Connect(function()
    if not droneMode then return end
    if riddenWreck then
        jumpOff()
    else
        safeRestore()
    end
end)

repairBtn.MouseButton1Click:Connect(function()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local nearest, nearestDist = nil, WRECK_RANGE
    for _, w in ipairs(wrecks) do
        if not w.repaired and w.model and w.model.Parent then
            local primary = w.model.PrimaryPart or w.model:FindFirstChildWhichIsA("BasePart")
            if primary then
                local d = (hrp.Position - primary.Position).Magnitude
                if d < nearestDist then nearest, nearestDist = w, d end
            end
        end
    end
    if nearest then startRepair(nearest) end
end)

rideBtn.MouseButton1Click:Connect(function()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local nearest, nearestDist = nil, WRECK_RANGE
    for _, w in ipairs(wrecks) do
        if w.repaired and w.rideable and w.model and w.model.Parent then
            local primary = w.model.PrimaryPart or w.model:FindFirstChildWhichIsA("BasePart")
            if primary then
                local d = (hrp.Position - primary.Position).Magnitude
                if d < nearestDist then nearest, nearestDist = w, d end
            end
        end
    end
    if nearest and mountWreck then mountWreck(nearest) end
end)

local function buildAndWire()
    local ok, tool = pcall(buildTool)
    if ok and tool then wireTool(tool); return tool end
    return nil
end

local function installToolWatchdog()
    local function watch(container)
        if not container then return end
        container.ChildRemoved:Connect(function(child)
            if not child:IsA("Tool") then return end
            if child.Name ~= "Shahed Controller" then return end
            if not userHoldingController then return end
            if droneMode or repairing or crashed then return end

            task.wait(0.1)

            if not userHoldingController then return end

            local char = LocalPlayer.Character
            local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
            local stillExists = false
            if char then
                for _, t in ipairs(char:GetChildren()) do
                    if t:IsA("Tool") and t.Name == "Shahed Controller" then stillExists = true break end
                end
            end
            if backpack then
                for _, t in ipairs(backpack:GetChildren()) do
                    if t:IsA("Tool") and t.Name == "Shahed Controller" then stillExists = true break end
                end
            end

            if stillExists then return end

            local now = os.clock()
            if now - rebuildCooldown < 0.5 then return end
            rebuildCooldown = now

            task.delay(0.05, function()
                if not userHoldingController then return end
                if droneMode or repairing or crashed then return end
                local ok, tool = pcall(buildTool)
                if ok and tool then
                    wireTool(tool)
                    local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                    if hum then
                        task.wait(0.1)
                        if userHoldingController then
                            pcall(function() hum:EquipTool(tool) end)
                        end
                    end
                end
            end)
        end)
    end

    if LocalPlayer:FindFirstChildOfClass("Backpack") then
        watch(LocalPlayer:FindFirstChildOfClass("Backpack"))
    end
    LocalPlayer.ChildAdded:Connect(function(child)
        if child:IsA("Backpack") then watch(child) end
    end)

    if LocalPlayer.Character then watch(LocalPlayer.Character) end
    LocalPlayer.CharacterAdded:Connect(function(c) if c then watch(c) end end)
end

pcall(buildAndWire)
local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
if bp then
    for _, t in ipairs(bp:GetChildren()) do
        if t:IsA("Tool") and t.Name == "Shahed Controller" then wireTool(t) end
    end
end
LocalPlayer.ChildAdded:Connect(function(t)
    if t.Name == "Backpack" then
        t.ChildAdded:Connect(function(child)
            if child:IsA("Tool") and child.Name == "Shahed Controller" then wireTool(child) end
        end)
    end
end)

installToolWatchdog()

task.spawn(function()
    while screen.Parent do
        task.wait(0.3)
        if userHoldingController and not droneMode and not repairing and not crashed then
            local char = LocalPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum and currentController then
                local inHand = char:FindFirstChildOfClass("Tool")
                if inHand ~= currentController then
                    if inHand then
                        userHoldingController = false
                        launchBtn.Visible = false
                        putAwayBtn.Visible = false
                    elseif currentController.Parent then
                        pcall(function() hum:EquipTool(currentController) end)
                    else
                        local ok, tool = pcall(buildTool)
                        if ok and tool then
                            wireTool(tool)
                            task.wait(0.1)
                            if userHoldingController then
                                pcall(function() hum:EquipTool(tool) end)
                            end
                        end
                    end
                end
            end
        end
    end
end)

LocalPlayer.CharacterAdded:Connect(function(char)
    if droneMode or crashed then safeRestore() end
    repairBtn.Visible, rideBtn.Visible = false, false
    repairGui.Visible = false
    repairing = false
    noclip = false
    userHoldingController = false
    putAwayBtn.Visible = false

    task.wait(1)
    pcall(buildAndWire)
    task.wait(0.2)
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.Died:Connect(function()
            if droneMode then crash() end
        end)
    end
end)

task.spawn(function()
    task.wait(2)
    while screen.Parent do
        task.wait(3)
        if not droneMode and not crashed and not repairing then
            local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
            local hasT = false
            if backpack then
                for _, t in ipairs(backpack:GetChildren()) do
                    if t:IsA("Tool") and t.Name == "Shahed Controller" then hasT = true break end
                end
            end
            local char = LocalPlayer.Character
            if char then
                for _, t in ipairs(char:GetChildren()) do
                    if t:IsA("Tool") and t.Name == "Shahed Controller" then hasT = true break end
                end
            end
            if not hasT then pcall(buildAndWire) end
        end
    end
end)

launchBtn.MouseButton1Click:Connect(function()
    if droneMode or repairing then return end
    launchBtn.Visible = false
    local ok, result = pcall(launchDrone)
    if not ok or result == false then
        task.wait(0.1)
        safeRestore()
    end
end)

if LocalPlayer.Character then
    local hum = LocalPlayer.Character:FindFirstChild("Humanoid")
    if hum then
        hum.Died:Connect(function()
            if droneMode then crash() end
        end)
    end
end

-- Finish loading
task.spawn(function()
    task.wait(3.2)

    local ok, m = pcall(function() return loadAsset(DRONE_ASSET_ID) end)
    if ok and m then pcall(function() m:Destroy() end) end
    local ok2, r = pcall(function() return loadAsset(REMOTE_ASSET_ID) end)
    if ok2 and r then pcall(function() r:Destroy() end) end

    setProgress(100)

    task.wait(0.3)

    local fade = Instance.new("Frame")
    fade.Size = UDim2.fromScale(1, 1)
    fade.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    fade.BorderSizePixel = 0
    fade.ZIndex = 10050
    fade.Parent = screen
    TweenService:Create(fade, TweenInfo.new(0.6), {BackgroundTransparency = 1}):Play()
    TweenService:Create(loadingOverlay, TweenInfo.new(0.6), {BackgroundTransparency = 1}):Play()
    TweenService:Create(gifHolder, TweenInfo.new(0.6), {BackgroundTransparency = 1}):Play()
    TweenService:Create(progressBg, TweenInfo.new(0.6), {BackgroundTransparency = 1}):Play()
    TweenService:Create(progressFill, TweenInfo.new(0.6), {BackgroundTransparency = 1}):Play()
    TweenService:Create(progressLabel, TweenInfo.new(0.6), {TextTransparency = 1}):Play()
    TweenService:Create(statusLabel, TweenInfo.new(0.6), {TextTransparency = 1}):Play()

    task.wait(0.7)

    pcall(function() loadingOverlay:Destroy() end)
    pcall(function() fade:Destroy() end)

    uiRoot.Visible = true
    launchBtn.Visible = true
end)
