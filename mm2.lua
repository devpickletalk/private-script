-- LocalScript: StarterPlayerScripts

if _G.__MurderHUD_Running then return end
_G.__MurderHUD_Running = true

local WALK_LEAD  = 4.5
local KNIFE_LEAD = 1.5
local SCAN_RATE  = 0.2
local KNIFE_STAB_DIST  = 3.5
local KNIFE_THROW_DIST = 4.5

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace  = game:GetService("Workspace")
local UIS        = game:GetService("UserInputService")

local lp = Players.LocalPlayer

-- ── HUD label ────────────────────────────────────────────────────────────────
local gui = Instance.new("ScreenGui")
gui.Name         = "MurderHUD"
gui.ResetOnSpawn = false
gui.Parent       = lp.PlayerGui

local lbl = Instance.new("TextLabel", gui)
lbl.Size                   = UDim2.new(0, 200, 0, 14)
lbl.Position               = UDim2.new(1, -205, 1, -18)
lbl.BackgroundTransparency = 1
lbl.TextColor3             = Color3.fromRGB(255, 55, 55)
lbl.TextSize               = 9
lbl.Font                   = Enum.Font.Code
lbl.TextXAlignment         = Enum.TextXAlignment.Right
lbl.Text                   = ""

-- ── State ────────────────────────────────────────────────────────────────────
local roles             = {}
local stickyRoles       = {}
local visuals           = {}
local lpVisuals         = {}
local murderer          = nil
local gunDropHighlights = {}

local ROLE_COLOR = {
    murder  = Color3.fromRGB(255, 0,   0),
    sheriff = Color3.fromRGB(0,   100, 255),
}
local LP_COLOR = {
    norole  = Color3.fromRGB(0, 255, 80),
    sheriff = Color3.fromRGB(0, 100, 255),
}

local rayParams      = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local HIDE_POS = Vector3.new(0, -9999, 0)

-- ── Gun drop ESP ──────────────────────────────────────────────────────────────
local function attachGunDropHighlight(part)
    if gunDropHighlights[part] then return end
    local ok, err = pcall(function()
        local color = Color3.fromRGB(0, 255, 80)
        local bb = Instance.new("BillboardGui")
        bb.Name        = "GunDropTracker"
        bb.Adornee     = part
        bb.AlwaysOnTop = true
        bb.Size        = UDim2.new(0, 5, 0, 5)
        bb.StudsOffset = Vector3.new(0, 1, 0)
        bb.Parent      = lp.PlayerGui
        local frame = Instance.new("Frame", bb)
        frame.ZIndex               = 10
        frame.BackgroundTransparency = 0.3
        frame.BackgroundColor3     = color
        frame.Size                 = UDim2.new(1, 0, 1, 0)
        local txt = Instance.new("TextLabel", bb)
        txt.ZIndex                  = 10
        txt.Text                    = "Gun"
        txt.BackgroundTransparency  = 1
        txt.Position                = UDim2.new(0, 0, 0, -35)
        txt.Size                    = UDim2.new(1, 0, 10, 0)
        txt.Font                    = Enum.Font.ArialBold
        txt.TextSize                = 12
        txt.TextStrokeTransparency  = 0.5
        txt.TextColor3              = color
        gunDropHighlights[part] = bb
    end)
    if not ok then warn("[MurderHUD] GunDrop highlight: " .. tostring(err)) end
end

local function scanGunDrops()
    local playerNames = {}
    for _, p in ipairs(Players:GetPlayers()) do playerNames[p.Name] = true end

    for part, bb in pairs(gunDropHighlights) do
        if not part.Parent then
            if bb and bb.Parent then bb:Destroy() end
            gunDropHighlights[part] = nil
        end
    end

    for _, child in ipairs(Workspace:GetChildren()) do
        if playerNames[child.Name] then continue end
        if child.Name == "GunDrop" then attachGunDropHighlight(child) end
        local ok, err = pcall(function()
            for _, desc in ipairs(child:GetDescendants()) do
                if desc.Name == "GunDrop" then attachGunDropHighlight(desc) end
            end
        end)
        if not ok then warn("[MurderHUD] GunDrop scan: " .. tostring(err)) end
    end
end

-- ── Walk / Jump ───────────────────────────────────────────────────────────────
local function setWalkSpeed(char)
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.WalkSpeed = 19
    else
        char.ChildAdded:Connect(function(child)
            if child:IsA("Humanoid") then child.WalkSpeed = 19 end
        end)
    end
end

local function setJumpPower(char)
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.JumpPower = 56
    else
        char.ChildAdded:Connect(function(child)
            if child:IsA("Humanoid") then child.JumpPower = 56 end
        end)
    end
end

-- ── LP murderer ESP ───────────────────────────────────────────────────────────
local function removeLpVisual(p)
    local lv = lpVisuals[p]
    if lv and lv.bb and lv.bb.Parent then lv.bb:Destroy() end
    lpVisuals[p] = nil
end

local function clearAllLpVisuals()
    for p in pairs(lpVisuals) do removeLpVisual(p) end
end

local function attachLpVisual(p, char, color)
    removeLpVisual(p)
    local head = char:FindFirstChild("Head")
    if not head then return end
    local ok, err = pcall(function()
        local bb = Instance.new("BillboardGui")
        bb.Name        = "LpEspTracker"
        bb.Adornee     = head
        bb.AlwaysOnTop = true
        bb.ExtentsOffset = Vector3.new(0, 1, 0)
        bb.Size        = UDim2.new(0, 5, 0, 5)
        bb.StudsOffset = Vector3.new(0, 1, 0)
        bb.Parent      = lp.PlayerGui
        local frame = Instance.new("Frame", bb)
        frame.ZIndex               = 10
        frame.BackgroundTransparency = 0.3
        frame.BackgroundColor3     = color
        frame.Size                 = UDim2.new(1, 0, 1, 0)
        local txt = Instance.new("TextLabel", bb)
        txt.ZIndex                 = 10
        txt.Text                   = p.Name
        txt.BackgroundTransparency = 1
        txt.Position               = UDim2.new(0, 0, 0, -35)
        txt.Size                   = UDim2.new(1, 0, 10, 0)
        txt.Font                   = Enum.Font.ArialBold
        txt.TextSize               = 12
        txt.TextStrokeTransparency = 0.5
        txt.TextColor3             = color
        lpVisuals[p] = { bb = bb, color = color }
    end)
    if not ok then warn("[MurderHUD] LpVisual: " .. tostring(err)) end
end

-- ── Role visuals ──────────────────────────────────────────────────────────────
local function removeVisuals(p)
    local v = visuals[p]
    if not v then return end
    if v.bb and v.bb.Parent then v.bb:Destroy() end
    visuals[p] = nil
end

local function attachVisuals(p, char, role)
    removeVisuals(p)
    local head = char:FindFirstChild("Head")
    if not head then return end
    local ok, err = pcall(function()
        local color = ROLE_COLOR[role]
        local bb = Instance.new("BillboardGui")
        bb.Name        = "tracker"
        bb.Adornee     = head
        bb.AlwaysOnTop = true
        bb.ExtentsOffset = Vector3.new(0, 1, 0)
        bb.Size        = UDim2.new(0, 5, 0, 5)
        bb.StudsOffset = Vector3.new(0, 1, 0)
        bb.Parent      = lp.PlayerGui
        local frame = Instance.new("Frame", bb)
        frame.ZIndex               = 10
        frame.BackgroundTransparency = 0.3
        frame.BackgroundColor3     = color
        frame.Size                 = UDim2.new(1, 0, 1, 0)
        local txt = Instance.new("TextLabel", bb)
        txt.ZIndex                 = 10
        txt.Text                   = p.Name
        txt.BackgroundTransparency = 1
        txt.Position               = UDim2.new(0, 0, 0, -35)
        txt.Size                   = UDim2.new(1, 0, 10, 0)
        txt.Font                   = Enum.Font.ArialBold
        txt.TextSize               = 12
        txt.TextStrokeTransparency = 0.5
        txt.TextColor3             = color
        visuals[p] = { bb = bb }
    end)
    if not ok then warn("[MurderHUD] RoleVisual: " .. tostring(err)) end
end

-- ── Role detection ────────────────────────────────────────────────────────────
local function getRole(p)
    local char = p.Character
    local bp   = p:FindFirstChild("Backpack")
    if not char then return stickyRoles[p] end
    if char:FindFirstChild("Knife") or (bp and bp:FindFirstChild("Knife")) then
        stickyRoles[p] = "murder"
        return "murder"
    end
    if char:FindFirstChild("Gun") or (bp and bp:FindFirstChild("Gun")) then
        stickyRoles[p] = "sheriff"
        return "sheriff"
    end
    return stickyRoles[p]
end

-- ── Watch character ───────────────────────────────────────────────────────────
local function watchChar(p, char)
    char.AncestryChanged:Connect(function(_, parent)
        if parent ~= nil then return end
        roles[p]       = nil
        stickyRoles[p] = nil
        removeLpVisual(p)
        removeVisuals(p)
        if murderer == p then murderer = nil lbl.Text = "" end
    end)
end

local function watchPlayer(p)
    if p == lp then return end
    if p.Character then watchChar(p, p.Character) end
    p.CharacterAdded:Connect(function(char)
        stickyRoles[p] = nil
        removeLpVisual(p)
        watchChar(p, char)
    end)
end

for _, p in ipairs(Players:GetPlayers()) do watchPlayer(p) end
Players.PlayerAdded:Connect(watchPlayer)
Players.PlayerRemoving:Connect(function(p)
    roles[p]       = nil
    stickyRoles[p] = nil
    removeLpVisual(p)
    removeVisuals(p)
    if murderer == p then murderer = nil lbl.Text = "" end
end)

lp.CharacterAdded:Connect(function(char)
    clearAllLpVisuals()
    setWalkSpeed(char)
    setJumpPower(char)
end)
if lp.Character then setWalkSpeed(lp.Character) end
if lp.Character then setJumpPower(lp.Character) end

-- ── Gun aim position (targets murderer) ──────────────────────────────────────
local function getAimPosition()
    if not murderer then return nil end
    local char = murderer.Character
    if not char then return nil end

    local hrp   = char:FindFirstChild("HumanoidRootPart")
    local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
    local head  = char:FindFirstChild("Head")
    local hum   = char:FindFirstChildOfClass("Humanoid")
    if not hrp then return nil end

    local isAir      = hum and hum.FloorMaterial == Enum.Material.Air
    local isClimbing = hum and hum:GetState() == Enum.HumanoidStateType.Climbing
    if isAir and not isClimbing then
        return hrp.Position - Vector3.new(0, 2, 0)
    end

    local target = torso or hrp
    local myChar = lp.Character
    local myHRP  = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if myHRP and head then
        rayParams.FilterDescendantsInstances = { myChar, char }
        local dir    = target.Position - myHRP.Position
        local result = Workspace:Raycast(myHRP.Position, dir, rayParams)
        if result then target = head end
    end

    local vel  = hrp.AssemblyLinearVelocity
    local hVel = Vector3.new(vel.X, 0, vel.Z)
    if hVel.Magnitude >= 15.8 then
        return target.Position + hVel.Unit * WALK_LEAD
    end

    return target.Position
end

-- ── Knife: nearest living player + distance ───────────────────────────────────
local function getNearestPlayerAndDist()
    local myChar = lp.Character
    local myHRP  = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myHRP then return nil, math.huge end

    local nearest, nearestDist = nil, math.huge
    for _, p in ipairs(Players:GetPlayers()) do
        if p == lp then continue end
        local char = p.Character
        if not char then continue end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum then continue end
        if hum.Health <= 0 then continue end
        local dist = (hrp.Position - myHRP.Position).Magnitude
        if dist < nearestDist then
            nearestDist = dist
            nearest     = p
        end
    end
    return nearest, nearestDist
end

-- ── Knife aim position for a given player ────────────────────────────────────
local function getKnifeAimPosition(p)
    if not p then return nil end
    local char = p.Character
    if not char then return nil end

    local hrp   = char:FindFirstChild("HumanoidRootPart")
    local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
    local hum   = char:FindFirstChildOfClass("Humanoid")
    if not hrp then return nil end

    local isAir      = hum and hum.FloorMaterial == Enum.Material.Air
    local isClimbing = hum and hum:GetState() == Enum.HumanoidStateType.Climbing
    if isAir and not isClimbing then
        return hrp.Position - Vector3.new(0, 2, 0)
    end

    local target = torso or hrp
    local vel    = hrp.AssemblyLinearVelocity
    local hVel   = Vector3.new(vel.X, 0, vel.Z)
    if hVel.Magnitude >= 15.8 then
        return target.Position + hVel.Unit * KNIFE_LEAD
    end

    return target.Position
end

-- ── Remote getters ────────────────────────────────────────────────────────────
local function getShootRemote()
    local char = lp.Character
    if not char then return nil end
    local gun = char:FindFirstChild("Gun")
    if not gun then return nil end
    local r = gun:FindFirstChild("Shoot")
    return (r and r:IsA("RemoteEvent")) and r or nil
end

local function getKnifeRemote()
    local char = lp.Character
    if not char then return nil end
    local knife = char:FindFirstChild("Knife")
    if not knife then return nil end
    local events = knife:FindFirstChild("Events")
    if not events then return nil end
    local r = events:FindFirstChild("KnifeThrown")
    return (r and r:IsA("RemoteEvent")) and r or nil
end

-- ── Scan loop ─────────────────────────────────────────────────────────────────
local scanAccum   = 0
local sphereAccum = 0
RunService.Heartbeat:Connect(function(dt)
    scanAccum += dt
    if scanAccum < SCAN_RATE then return end
    scanAccum = 0

    local ok, err = pcall(function()
        local char     = lp.Character
        local bp       = lp:FindFirstChild("Backpack")
        local isLpMurd = (char and char:FindFirstChild("Knife") ~= nil)
                      or (bp   and bp:FindFirstChild("Knife")   ~= nil)
        local newMurderer = nil

        for _, p in ipairs(Players:GetPlayers()) do
            if p == lp then continue end

            local role    = getRole(p)
            local oldRole = roles[p]
            local pChar   = p.Character

            if role ~= oldRole then
                roles[p] = role
                if role and pChar then
                    attachVisuals(p, pChar, role)
                else
                    removeVisuals(p)
                end
            elseif role and pChar then
                local v = visuals[p]
                if not v or not v.highlight or not v.highlight.Parent then
                    attachVisuals(p, pChar, role)
                end
            end

            if role == "murder" and pChar then newMurderer = p end

            if isLpMurd and pChar then
                local lpColor
                if role == "sheriff" then
                    lpColor = LP_COLOR.sheriff
                elseif role ~= "murder" then
                    lpColor = LP_COLOR.norole
                end
                if lpColor then
                    local lv = lpVisuals[p]
                    if not lv or not lv.hl or not lv.hl.Parent or lv.color ~= lpColor then
                        attachLpVisual(p, pChar, lpColor)
                    end
                else
                    removeLpVisual(p)
                end
            end
        end

        murderer = newMurderer
        lbl.Text = murderer and ("⚠ " .. murderer.Name) or ""

        scanGunDrops()
    end)
    if not ok then warn("[MurderHUD] Scan: " .. tostring(err)) end
end)

-- ── Click / Touch intercept ───────────────────────────────────────────────────
UIS.InputBegan:Connect(function(input, processed)
    if processed then return end
    local isFire = input.UserInputType == Enum.UserInputType.MouseButton1
               or  input.UserInputType == Enum.UserInputType.Touch
    if not isFire then return end

    local myChar = lp.Character
    local myHRP  = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myHRP then return end

    -- LP is murderer: knife silent aim
    local knifeRemote = getKnifeRemote()
    if knifeRemote then
        local target, dist = getNearestPlayerAndDist()

        -- nearest player is within stab range: do not throw
        if dist <= KNIFE_STAB_DIST then return end

        -- nearest player is not far enough to warrant a throw
        if dist <= KNIFE_THROW_DIST then return end

        if not target then warn("[MurderHUD] Knife: no valid target.") return end
        local aimPos = getKnifeAimPosition(target)
        if not aimPos then warn("[MurderHUD] Knife: no aim position.") return end

        local ok, err = pcall(function()
            knifeRemote:FireServer(
                CFrame.new(myHRP.Position, aimPos),
                CFrame.new(aimPos)
            )
        end)
        if not ok then warn("[MurderHUD] Knife FireServer: " .. tostring(err)) end
        return
    end

    -- LP has gun (sheriff): gun silent aim at murderer
    if not murderer then return end
    local aimPos = getAimPosition()
    if not aimPos then return end
    local remote = getShootRemote()

    local ok, err = pcall(function()
        remote:FireServer(CFrame.new(myHRP.Position, aimPos), CFrame.new(aimPos))
    end)
    if not ok then warn("[MurderHUD] Gun FireServer: " .. tostring(err)) end
end)
