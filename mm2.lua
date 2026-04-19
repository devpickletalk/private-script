-- LocalScript: StarterPlayerScripts

if _G.__MurderHUD_Running then return end
_G.__MurderHUD_Running = true

local WALK_LEAD        = 4.5
local KNIFE_LEAD       = 1
local KNIFE_STAB_DIST  = 6
local KNIFE_THROW_DIST = 7

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace  = game:GetService("Workspace")
local UIS        = game:GetService("UserInputService")

local lp = Players.LocalPlayer

-- ── State ─────────────────────────────────────────────────────────────────────
local roles             = {}
local stickyRoles       = {}
local visuals           = {}
local lpVisuals         = {}
local murderer          = nil
local isLpMurd          = false
local gunDropHighlights = {}

local ROLE_COLOR = {
    murder  = Color3.fromRGB(255,   0,   0),
    sheriff = Color3.fromRGB(  0, 100, 255),
}
local LP_COLOR = {
    norole  = Color3.fromRGB(0, 255,  80),
    sheriff = Color3.fromRGB(0, 100, 255),
}

local rayParams      = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local HIDE_POS      = Vector3.new(0, -9999, 0)
local REAL_HRP_SIZE = Vector3.new(20, 5, 20)
local FAKE_HRP_SIZE = Vector3.new(2, 2, 1)

local fakeHRPs  = {}
local charParts = {}

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
        txt.ZIndex                 = 10
        txt.Text                   = "Gun"
        txt.BackgroundTransparency = 1
        txt.Position               = UDim2.new(0, 0, 0, -35)
        txt.Size                   = UDim2.new(1, 0, 10, 0)
        txt.Font                   = Enum.Font.ArialBold
        txt.TextSize               = 12
        txt.TextStrokeTransparency = 0.5
        txt.TextColor3             = color
        gunDropHighlights[part]    = bb
        part.AncestryChanged:Connect(function(_, parent)
            if parent then return end
            if bb and bb.Parent then bb:Destroy() end
            gunDropHighlights[part] = nil
        end)
    end)
    if not ok then warn("[MurderHUD] GunDrop highlight: " .. tostring(err)) end
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
        bb.Name          = "LpEspTracker"
        bb.Adornee       = head
        bb.AlwaysOnTop   = true
        bb.ExtentsOffset = Vector3.new(0, 1, 0)
        bb.Size          = UDim2.new(0, 5, 0, 5)
        bb.StudsOffset   = Vector3.new(0, 1, 0)
        bb.Parent        = lp.PlayerGui
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
        bb.Name          = "tracker"
        bb.Adornee       = head
        bb.AlwaysOnTop   = true
        bb.ExtentsOffset = Vector3.new(0, 1, 0)
        bb.Size          = UDim2.new(0, 5, 0, 5)
        bb.StudsOffset   = Vector3.new(0, 1, 0)
        bb.Parent        = lp.PlayerGui
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

-- ── LP visual for one player ──────────────────────────────────────────────────
local function updateLpVisualFor(p)
    if not isLpMurd then removeLpVisual(p) return end
    local pChar = p.Character
    if not pChar then removeLpVisual(p) return end
    local role = roles[p]
    local lpColor
    if role == "sheriff" then
        lpColor = LP_COLOR.sheriff
    elseif role ~= "murder" then
        lpColor = LP_COLOR.norole
    end
    if lpColor then
        local lv = lpVisuals[p]
        if not lv or lv.color ~= lpColor then
            attachLpVisual(p, pChar, lpColor)
        end
    else
        removeLpVisual(p)
    end
end

-- ── Apply role state for a player ─────────────────────────────────────────────
local function applyRole(p)
    local role  = getRole(p)
    local pChar = p.Character
    local old   = roles[p]
    roles[p] = role
    if role == "murder" then
        murderer = p
    elseif old == "murder" and murderer == p then
        murderer = nil
    end
    if role and pChar then
        local v = visuals[p]
        if not v or not v.bb or not v.bb.Parent or old ~= role then
            attachVisuals(p, pChar, role)
        end
    else
        removeVisuals(p)
    end
    if old ~= role then
        updateLpVisualFor(p)
    end
end

-- ── LP murderer state ─────────────────────────────────────────────────────────
local function refreshLpMurd()
    local char = lp.Character
    local bp   = lp:FindFirstChild("Backpack")
    local prev = isLpMurd
    isLpMurd = (char and char:FindFirstChild("Knife") ~= nil)
            or (bp   and bp:FindFirstChild("Knife")   ~= nil)
    if prev == isLpMurd then return end
    if not isLpMurd then
        clearAllLpVisuals()
    else
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= lp then updateLpVisualFor(p) end
        end
    end
end

-- ── Watch container for tool events ──────────────────────────────────────────
local function watchContainer(p, container, forLp)
    if forLp then
        container.ChildAdded:Connect(function(child)
            if child.Name == "Knife" then refreshLpMurd() end
        end)
        container.ChildRemoved:Connect(function(child)
            if child.Name == "Knife" then refreshLpMurd() end
        end)
    else
        container.ChildAdded:Connect(function(child)
            if child.Name == "Knife" or child.Name == "Gun" then applyRole(p) end
        end)
        container.ChildRemoved:Connect(function(child)
            if child.Name == "Knife" or child.Name == "Gun" then applyRole(p) end
        end)
    end
end

-- ── Watch character for removal ───────────────────────────────────────────────
local function watchChar(p, char)
    char.AncestryChanged:Connect(function(_, parent)
        if parent ~= nil then return end
        roles[p]       = nil
        stickyRoles[p] = nil
        removeLpVisual(p)
        removeVisuals(p)
        if murderer == p then murderer = nil end
    end)
end

-- ── FakeHRP helpers ───────────────────────────────────────────────────────────
local function rebuildCharParts(p)
    local char = p.Character
    if not char then charParts[p] = nil return end
    local list = {}
    for _, v in ipairs(char:GetDescendants()) do
        if v:IsA("BasePart") then list[#list + 1] = v end
    end
    charParts[p] = list
    char.DescendantAdded:Connect(function(v)
        if v:IsA("BasePart") then
            local l = charParts[p]
            if l then l[#l + 1] = v end
        end
    end)
end

local function expandRealHRP(p)
    local char = p.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if hrp then
        hrp.Size       = REAL_HRP_SIZE
        hrp.CanCollide = false
    end
end

local function ensureFakeHRP(p)
    if fakeHRPs[p] and fakeHRPs[p].Parent then return end
    local ok, err = pcall(function()
        local part = Instance.new("Part")
        part.Name         = "FakeHRP_" .. p.Name
        part.Anchored     = true
        part.CanCollide   = true
        part.CanQuery     = false
        part.CanTouch     = false
        part.Transparency = 1
        part.CastShadow   = false
        part.Size         = FAKE_HRP_SIZE
        part.CFrame       = CFrame.new(HIDE_POS)
        part.Parent       = Workspace
        fakeHRPs[p]       = part
    end)
    if not ok then warn("[MurderHUD] FakeHRP create: " .. tostring(err)) end
end

-- ── Per-player setup ──────────────────────────────────────────────────────────
local function setupPlayer(p)
    ensureFakeHRP(p)
    -- Watch persistent Backpack once
    local bp = p:FindFirstChild("Backpack")
    if bp then
        watchContainer(p, bp, false)
    else
        p.ChildAdded:Connect(function(child)
            if child.Name == "Backpack" then watchContainer(p, child, false) end
        end)
    end
    -- Watch current character
    if p.Character then
        watchChar(p, p.Character)
        watchContainer(p, p.Character, false)
        expandRealHRP(p)
        rebuildCharParts(p)
        applyRole(p)
    end
    -- Watch future characters (new char = new round, clear sticky)
    p.CharacterAdded:Connect(function(char)
        stickyRoles[p] = nil
        removeLpVisual(p)
        removeVisuals(p)
        watchChar(p, char)
        watchContainer(p, char, false)
        local bp2 = p:FindFirstChild("Backpack")
        if bp2 then watchContainer(p, bp2, false) end
        expandRealHRP(p)
        rebuildCharParts(p)
        applyRole(p)
        task.delay(1, function() if p.Character == char then applyRole(p) end end)
        task.delay(3, function() if p.Character == char then applyRole(p) end end)
    end)
end

-- ── LP setup ──────────────────────────────────────────────────────────────────
local function setupLp()
    local char = lp.Character
    if char then
        setWalkSpeed(char)
        setJumpPower(char)
        watchContainer(lp, char, true)
    end
    local bp = lp:FindFirstChild("Backpack")
    if bp then
        watchContainer(lp, bp, true)
    else
        lp.ChildAdded:Connect(function(child)
            if child.Name == "Backpack" then watchContainer(lp, child, true) end
        end)
    end
    refreshLpMurd()
end

lp.CharacterAdded:Connect(function(char)
    clearAllLpVisuals()
    isLpMurd = false
    setWalkSpeed(char)
    setJumpPower(char)
    watchContainer(lp, char, true)
    refreshLpMurd()
end)

setupLp()

for _, p in ipairs(Players:GetPlayers()) do
    if p ~= lp then setupPlayer(p) end
end

Players.PlayerAdded:Connect(function(p)
    if p == lp then return end
    setupPlayer(p)
end)

Players.PlayerRemoving:Connect(function(p)
    roles[p]       = nil
    stickyRoles[p] = nil
    removeLpVisual(p)
    removeVisuals(p)
    if murderer == p then murderer = nil lbl.Text = "" end
    local fake = fakeHRPs[p]
    if fake and fake.Parent then fake:Destroy() end
    fakeHRPs[p]  = nil
    charParts[p] = nil
end)

-- ── GunDrop: event-driven ─────────────────────────────────────────────────────
Workspace.DescendantAdded:Connect(function(desc)
    if desc.Name ~= "GunDrop" then return end
    local ok, err = pcall(attachGunDropHighlight, desc)
    if not ok then warn("[MurderHUD] GunDrop DescendantAdded: " .. tostring(err)) end
end)

-- Catch any drops already in workspace at startup
for _, desc in ipairs(Workspace:GetDescendants()) do
    if desc.Name == "GunDrop" then
        local ok, err = pcall(attachGunDropHighlight, desc)
        if not ok then warn("[MurderHUD] GunDrop startup: " .. tostring(err)) end
    end
end

-- ── FakeHRP sync: Heartbeat (positional, must remain per-frame) ───────────────
RunService.Heartbeat:Connect(function()
    for p, fakePart in pairs(fakeHRPs) do
        local char = p.Character
        local hrp  = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then
            fakePart.CFrame = hrp.CFrame
            if hrp.Size ~= REAL_HRP_SIZE then
                hrp.Size       = REAL_HRP_SIZE
                hrp.CanCollide = false
            end
            local list = charParts[p]
            if list then
                for i = 1, #list do
                    local v = list[i]
                    if v and v.Parent and v.CanCollide then
                        v.CanCollide = false
                    end
                end
            end
        else
            fakePart.CFrame = CFrame.new(HIDE_POS)
        end
    end
end)

-- ── Aim: gun (targets murderer) ───────────────────────────────────────────────
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

-- ── Aim: knife (nearest living player) ───────────────────────────────────────
local function getNearestPlayerAndDist()
    local myChar = lp.Character
    local myHRP  = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myHRP then return nil, math.huge end
    local myPos  = myHRP.Position
    local nearest, nearestDist = nil, math.huge
    local charFilter = {}
    for _, op in ipairs(Players:GetPlayers()) do
        if op.Character then charFilter[#charFilter + 1] = op.Character end
    end
    rayParams.FilterDescendantsInstances = charFilter
    for _, p in ipairs(Players:GetPlayers()) do
        if p == lp then continue end
        local fake = fakeHRPs[p]
        if not fake or not fake.Parent then continue end
        local char = p.Character
        if not char then continue end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then continue end
        local fakePos = fake.Position
        local dist    = (fakePos - myPos).Magnitude
        if dist >= nearestDist then continue end
        local dir    = fakePos - myPos
        local result = Workspace:Raycast(myPos, dir, rayParams)
        if result then continue end
        nearestDist = dist
        nearest     = p
    end
    return nearest, nearestDist
end

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

-- ── Input ─────────────────────────────────────────────────────────────────────
UIS.InputBegan:Connect(function(input, processed)
    if processed then return end
    local isFire = input.UserInputType == Enum.UserInputType.MouseButton1
               or  input.UserInputType == Enum.UserInputType.Touch
    if not isFire then return end
    local myChar = lp.Character
    local myHRP  = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myHRP then return end
    local knifeRemote = getKnifeRemote()
    if knifeRemote then
        local target, dist = getNearestPlayerAndDist()
        if dist <= KNIFE_STAB_DIST  then return end
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
    if not murderer then return end
    local aimPos = getAimPosition()
    if not aimPos then return end
    local remote = getShootRemote()
    local ok, err = pcall(function()
        remote:FireServer(CFrame.new(myHRP.Position, aimPos), CFrame.new(aimPos))
    end)
    if not ok then warn("[MurderHUD] Gun FireServer: " .. tostring(err)) end
end)
