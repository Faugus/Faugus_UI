local _, ns = ...

local WIDTH = 215
local SIDE_WIDTH = 46
local INSET = 2
local TRACKING_NUDGE = 1

local function LayoutHeader()
    local cluster = MinimapCluster
    local top = cluster.BorderTop
    top:SetWidth(WIDTH)
    cluster.Tracking:ClearAllPoints()
    cluster.Tracking:SetPoint("LEFT", top, "LEFT", INSET, 0)
    GameTimeFrame:ClearAllPoints()
    GameTimeFrame:SetPoint("LEFT", cluster.Tracking, "RIGHT", 1, -1)
    cluster.ZoneTextButton:ClearAllPoints()
    cluster.ZoneTextButton:SetPoint("CENTER", top, "CENTER")
    cluster.ZoneTextButton:SetWidth(WIDTH - 2 * SIDE_WIDTH)
    MinimapZoneText:SetWidth(WIDTH - 2 * SIDE_WIDTH)
    MinimapZoneText:SetJustifyH("CENTER")
end

local function LayoutClock()
    TimeManagerClockButton:ClearAllPoints()
    TimeManagerClockButton:SetPoint("RIGHT", MinimapCluster.BorderTop, "RIGHT", -INSET, 0)
end

local function MatchTrackingGap()
    local cluster = MinimapCluster
    local top, tracking = cluster.BorderTop, cluster.Tracking
    local ticker, icon = TimeManagerClockTicker, tracking.Button
    if not (ticker and ticker:GetRight() and icon:GetLeft() and tracking:GetLeft()) then return end
    local offset = top:GetRight() - ticker:GetRight() - (icon:GetLeft() - tracking:GetLeft()) + TRACKING_NUDGE
    tracking:ClearAllPoints()
    tracking:SetPoint("LEFT", top, "LEFT", offset, 0)
end

local headerRect
local headerUnderneath = false
local DIFFICULTY_TUCK = 2

local function AnchorDifficulty()
    local cluster = MinimapCluster
    local difficulty = cluster.InstanceDifficulty
    if not (headerRect and difficulty) then return end
    difficulty:ClearAllPoints()
    if headerUnderneath then
        difficulty:SetPoint("BOTTOMRIGHT", headerRect, "TOPRIGHT", 0, -DIFFICULTY_TUCK)
    else
        difficulty:SetPoint("TOPRIGHT", headerRect, "BOTTOMRIGHT", 0, DIFFICULTY_TUCK)
    end
end

local function SkinHeader()
    local cluster = MinimapCluster
    local top = cluster.BorderTop
    local rect = CreateFrame("Frame", nil, cluster)
    rect:SetFrameLevel(cluster:GetFrameLevel())
    rect:SetPoint("LEFT", top, "LEFT")
    rect:SetPoint("RIGHT", top, "RIGHT")
    rect:SetHeight(math.max(top:GetHeight(), ns.GetSkinMinSize(rect) or 0))
    ns.CreateSkin(rect, rect)
    headerRect = rect
    AnchorDifficulty()
    ns.KeepOffScreenEdge(cluster, function() return { rect, Minimap } end)
    MatchTrackingGap()
end

ns.Module("Minimap", "Minimap", function()
    ns.WhenLoaded("MinimapCluster", "Blizzard_Minimap", function()
        hooksecurefunc(MinimapCluster, "SetHeaderUnderneath", function(_, underneath)
            headerUnderneath = underneath
            AnchorDifficulty()
        end)
        ns.HideRegionTextures(MinimapCluster.BorderTop, {})
        ns.HideForever(MinimapCluster.Tracking.Background)
        ns.HideForever(AddonCompartmentFrame)
        LayoutHeader()
        local f = CreateFrame("Frame")
        f:RegisterEvent("PLAYER_ENTERING_WORLD")
        f:SetScript("OnEvent", function(self)
            self:UnregisterAllEvents()
            C_Timer.After(1, SkinHeader)
        end)
    end)

    ns.WhenLoaded("TimeManagerClockButton", "Blizzard_TimeManager", LayoutClock)
end)
