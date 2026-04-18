-- LocalScript: StarterPlayerScripts

local WALK_LEAD = 3
local SCAN_RATE = 0.1

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
local roles       = {}
local stickyRoles = {}
local visuals     = {}
local lpVisuals   = {}
local murderer    = nil

local sheriffGunPart = nil
local sheriffGunPos  = nil

local ROLE_COLOR = {
    murder  = Color3.fromRGB(255, 0,   0),
    sheriff = Color3.fromRGB(0,   100, 255),
}

local rayParams            = RaycastParams.new()
rayParams.FilterType       = Enum.RaycastFilterType.Exclude

-- ── Sheriff gun drop ──────────────────────────────────────────────────────────
local function clearSheriffGun()
    if sheriffGunPart and sheriffGunPart.Parent then sheriffGunPart:Destroy() end
    sheriffGunPart = nil
    sheriffGunPos  = nil
end

local function placeSheriffGun(pos)
    clearSheriffGun()
    sheriffGunPos       = pos
    local part          = Instance.new("Part")
    part.Size           = Vector3.new(1, 1, 1)
    part.Position       = pos
    part.Anchored       = true
    part.CanCollide     = false
    part.Transparency   = 1
    part.Parent         = Workspace
    local hl               = Instance.new("Highlight")
    hl.Adornee             = part
    hl.DepthMode           = Enum.HighlightDepthMode.AlwaysOnTop
    hl.FillColor           = Color3.fromRGB(0, 255, 80)
    hl.FillTransparency    = 0.5
    hl.OutlineColor        = Color3.fromRGB(0, 255, 80)
    hl.OutlineTransparency = 0
    hl.Parent              = part
    sheriffGunPart = part
end

-- ── LP murderer ESP ───────────────────────────────────────────────────────────
local function removeLpVisual(p)
    local hl = lpVisuals[p]
    if hl and hl.Parent then hl:Destroy() end
    lpVisuals[p] = nil
end

local function clearAllLpVisuals()
    for p in pairs(lpVisuals) do removeLpVisual(p) end
end

local function attachLpVisual(p, char)
    removeLpVisual(p)
    local hl               = Instance.new("Highlight")
    hl.Name                = "LpEspHighlight"
    hl.Adornee             = char
    hl.DepthMode           = Enum.HighlightDepthMode.AlwaysOnTop
    hl.FillTransparency    = 1
    hl.OutlineColor        = Color3.fromRGB(255, 200, 0)
    hl.OutlineTransparency = 0
    hl.Parent              = char
    lpVisuals[p]           = hl
end

-- ── Role visuals (adorn full character Model) ─────────────────────────────────
local function removeVisuals(p)
    local v = visuals[p]
    if not v then return end
    if v.highlight and v.highlight.Parent then v.highlight:Destroy() end
    visuals[p] = nil
end

local function attachVisuals(p, char, role)
    removeVisuals(p)
    local hl               = Instance.new("Highlight")
    hl.Name                = "RoleHighlight"
    hl.Adornee             = char
    hl.DepthMode           = Enum.HighlightDepthMode.AlwaysOnTop
    hl.FillTransparency    = 1
    hl.OutlineColor        = ROLE_COLOR[role]
    hl.OutlineTransparency = 0.7
    hl.Parent              = char
    visuals[p]             = { highlight = hl }
end

-- ── Role detection: Character + Backpack ─────────────────────────────────────
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
        if stickyRoles[p] == "sheriff" then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then placeSheriffGun(hrp.Position) end
        end
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

lp.CharacterAdded:Connect(clearAllLpVisuals)

-- ── Aim ───────────────────────────────────────────────────────────────────────
local function getAimPosition()
    if not murderer then return nil end
    local char = murderer.Character
    if not char then return nil end

    local hrp   = char:FindFirstChild("HumanoidRootPart")
    local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
    local head  = char:FindFirstChild("Head")
    if not hrp then return nil end

    local target = torso or hrp

    -- Wall check: if torso is blocked, fall back to head
    local myChar = lp.Character
    local myHRP  = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if myHRP and head then
        rayParams.FilterDescendantsInstances = { myChar, char }
        local dir    = target.Position - myHRP.Position
        local result = Workspace:Raycast(myHRP.Position, dir, rayParams)
        if result then
            target = head
        end
    end

    -- Movement: speed > 3 studs/s → lead by 2 studs; otherwise shoot directly
    local vel    = hrp.AssemblyLinearVelocity
    local hVel   = Vector3.new(vel.X, 0, vel.Z)
    if hVel.Magnitude > 2 then
        return target.Position + hVel.Unit * WALK_LEAD
    end

    return target.Position
end

local function getShootRemote()
    local char = lp.Character
    if not char then return nil end
    local gun = char:FindFirstChild("Gun")
    if not gun then return nil end
    local r = gun:FindFirstChild("Shoot")
    return (r and r:IsA("RemoteEvent")) and r or nil
end

-- ── Scan loop ─────────────────────────────────────────────────────────────────
local scanAccum = 0
RunService.Heartbeat:Connect(function(dt)
    scanAccum += dt
    if scanAccum < SCAN_RATE then return end
    scanAccum = 0

    local ok, err = pcall(function()
        local myChar      = lp.Character
        local isLpMurd    = myChar and myChar:FindFirstChild("Knife") ~= nil
        local newMurderer = nil

        for _, p in ipairs(Players:GetPlayers()) do
            if p == lp then continue end

            local role    = getRole(p)
            local oldRole = roles[p]
            local char    = p.Character

            if role ~= oldRole then
                roles[p] = role
                if role and char then
                    attachVisuals(p, char, role)
                else
                    removeVisuals(p)
                end
            elseif role and char then
                local v = visuals[p]
                if not v or not v.highlight or not v.highlight.Parent then
                    attachVisuals(p, char, role)
                end
            end

            if role == "murder" and char then newMurderer = p end

            if isLpMurd and char then
                if not lpVisuals[p] or not lpVisuals[p].Parent then
                    attachLpVisual(p, char)
                end
            elseif lpVisuals[p] then
                removeLpVisual(p)
            end
        end

        murderer = newMurderer
        lbl.Text = murderer and ("⚠ " .. murderer.Name) or ""

        if sheriffGunPos and sheriffGunPart and sheriffGunPart.Parent then
            for _, p in ipairs(Players:GetPlayers()) do
                if p == murderer then continue end
                local char = p.Character
                if not char then continue end
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if hrp and (hrp.Position - sheriffGunPos).Magnitude <= 2 then
                    clearSheriffGun()
                    break
                end
            end
        end
    end)
    if not ok then warn("[SilentAim] Scan: " .. tostring(err)) end
end)

-- ── Click / Touch intercept ───────────────────────────────────────────────────
UIS.InputBegan:Connect(function(input, processed)
    if processed then return end
    local isFire = input.UserInputType == Enum.UserInputType.MouseButton1
               or  input.UserInputType == Enum.UserInputType.Touch
    if not isFire then return end
    if not murderer then return end

    local aimPos = getAimPosition()
    if not aimPos then return end

    local remote = getShootRemote()
    if not remote then warn("[SilentAim] Gun/Shoot remote not found.") return end

    local myChar = lp.Character
    local myHRP  = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myHRP then return end

    local ok, err = pcall(function()
        remote:FireServer(CFrame.new(myHRP.Position, aimPos), CFrame.new(aimPos))
    end)
    if not ok then warn("[SilentAim] FireServer: " .. tostring(err)) end
end)
