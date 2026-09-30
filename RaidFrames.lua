local _, ns = ...

local THREAT_ALPHA = 1
local NAME_RAISE = 1
local ROLE_LEFT = 1
local ROLE_TOP = 2
local GRADIENT = "Interface\\AddOns\\Faugus_UI\\gradient"

local function OnePixel(frame)
    return PixelUtil.GetNearestPixelSize(1, frame:GetEffectiveScale(), 1)
end

local function IsRaidFrame(frame)
    if frame:IsForbidden() then return false end
    local name = frame:GetName()
    return name ~= nil and name:find("^Compact") ~= nil
end

local function CreateThreatGlow(frame)
    if frame.faugusThreat or not frame.aggroHighlight then return end
    local glow = frame:CreateTexture(nil, "ARTWORK", nil, -8)
    glow:SetPoint("TOPLEFT", frame.healthBar, "TOPLEFT")
    glow:SetPoint("BOTTOMRIGHT", frame.healthBar, "BOTTOMRIGHT")
    glow:SetTexture(GRADIENT)
    glow:SetAlpha(0)
    frame.faugusThreat = glow
    frame.aggroHighlight:SetAlpha(0)
end

local function UpdateThreatGlow(frame)
    local glow = frame.faugusThreat
    if not glow then return end
    local source = frame.aggroHighlight
    local shown = source:IsShown()
    local r, g, b = source:GetVertexColor()
    glow:SetVertexColor(r, g, b)
    if issecretvalue(shown) then
        glow:SetAlphaFromBoolean(shown, THREAT_ALPHA, 0)
    else
        glow:SetAlpha(shown and THREAT_ALPHA or 0)
    end
end

local function RaiseSelection(frame)
    local selection = frame.selectionHighlight
    if frame.faugusSelection or not selection then return end
    local holder = CreateFrame("Frame", nil, frame)
    holder:SetAllPoints()
    holder:SetFrameLevel(frame:GetFrameLevel() + 1)
    selection:SetParent(holder)
    frame.faugusSelection = holder
end

local function AnchorHealthRight(frame)
    frame.healthBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -OnePixel(frame), frame.powerBarUsedHeight or 0)
end

local function HookHealthLoss(frame)
    local loss = frame.TempMaxHealthLoss
    if not loss or loss.faugusHooked then return end
    loss.faugusHooked = true
    hooksecurefunc(loss, "Update_MaxHealthLoss", function(_, fillPercent)
        if not issecretvalue(fillPercent) and fillPercent == 0 then AnchorHealthRight(frame) end
    end)
end

local function StyleBars(frame)
    for _, bar in ipairs({ frame.healthBar, frame.powerBar }) do
        ns.OverlayBarTexture(bar, PlayerFrame.healthbar, ns.UNIT_BAR_CROP)
        if bar.faugusTexture then bar.faugusTexture:SetDrawLayer("BORDER", 7) end
    end
    local power, health = frame.powerBar, frame.healthBar
    local pixel = OnePixel(frame)
    health:SetPoint("TOPLEFT", frame, "TOPLEFT", pixel, 0)
    AnchorHealthRight(frame)
    if frame.background then frame.background:SetIgnoreParentAlpha(true) end
    if not power then return end
    if power.background then power.background:SetAlpha(0) end
    power:SetFrameLevel(frame:GetFrameLevel())
    power:SetPoint("TOPLEFT", health, "BOTTOMLEFT")
    power:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -pixel, 0)
end

local function LayoutRoleAndName(frame)
    local name, role = frame.name, frame.roleIcon
    if not (name and role) then return end
    local _, anchor = name:GetPoint(1)
    local point, height = role:GetPoint(1), role:GetHeight()
    if issecretvalue(anchor) or issecretvalue(point) or issecretvalue(height) then return end
    if anchor ~= role or point ~= "TOPLEFT" then return end
    role:ClearAllPoints()
    role:SetPoint("TOPLEFT", frame.healthBar, "TOPLEFT", ROLE_LEFT, -ROLE_TOP)
    name:ClearAllPoints()
    name:SetPoint("LEFT", role, "RIGHT", 0, NAME_RAISE)
    name:SetPoint("RIGHT", frame, "TOPRIGHT", -3, NAME_RAISE - ROLE_TOP - height / 2)
end

local function CreateEdge(holder, pixel)
    local line = holder:CreateTexture(nil, "OVERLAY")
    line:SetColorTexture(0, 0, 0)
    line:SetHeight(pixel)
    return line
end

local function AnchorPartyEdges()
    local party = CompactPartyFrame
    local edges = party and party.faugusEdges
    if not edges then return end
    local first, last = _G["CompactPartyFrameMember1"]
    for _, kind in ipairs({ "Member", "Pet" }) do
        for i = 1, MEMBERS_PER_RAID_GROUP or 5 do
            local member = _G["CompactPartyFrame" .. kind .. i]
            if member and member:IsShown() then last = member end
        end
    end
    if not (first and last) then return end
    edges.top:ClearAllPoints()
    edges.top:SetPoint("TOPLEFT", first, "TOPLEFT")
    edges.top:SetPoint("TOPRIGHT", first, "TOPRIGHT")
    edges.bottom:ClearAllPoints()
    edges.bottom:SetPoint("BOTTOMLEFT", last, "BOTTOMLEFT")
    edges.bottom:SetPoint("BOTTOMRIGHT", last, "BOTTOMRIGHT")
end

local function StylePartyFrame()
    local party = CompactPartyFrame
    if not party then return end
    if party.title then party.title:SetAlpha(0) end
    if not party.faugusEdges then
        local holder = CreateFrame("Frame", nil, party)
        holder:SetAllPoints()
        holder:SetFrameLevel(party:GetFrameLevel() + 20)
        local pixel = OnePixel(party)
        holder.top, holder.bottom = CreateEdge(holder, pixel), CreateEdge(holder, pixel)
        party.faugusEdges = holder
        hooksecurefunc(party, "RefreshMembers", AnchorPartyEdges)
    end
    AnchorPartyEdges()
end

local function StyleFrame(frame)
    if not IsRaidFrame(frame) then return end
    StyleBars(frame)
    LayoutRoleAndName(frame)
    HookHealthLoss(frame)
    CreateThreatGlow(frame)
    UpdateThreatGlow(frame)
    RaiseSelection(frame)
end

ns.Module("RaidFrames", "Raid Frames", function()
    hooksecurefunc("DefaultCompactUnitFrameSetup", StyleFrame)
    hooksecurefunc("DefaultCompactMiniFrameSetup", StyleFrame)
    hooksecurefunc("CompactUnitFrame_UpdateAggroHighlight", UpdateThreatGlow)
    hooksecurefunc("CompactPartyFrame_Generate", StylePartyFrame)
    StylePartyFrame()
end)

