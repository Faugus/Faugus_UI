local _, ns = ...

local HEADER_HEIGHT = 26
local LIST_LEFT = 10
local PAD = 7

local function SkinHeader(header)
    if header.faugusSkin or not header:IsVisible() or not header.Background:GetLeft() then return end
    local rect = CreateFrame("Frame", nil, header)
    rect:SetPoint("TOPLEFT", header, "TOPLEFT", -LIST_LEFT, 0)
    rect:SetPoint("TOPRIGHT", header, "TOPRIGHT")
    rect:SetHeight(HEADER_HEIGHT)
    header.faugusSkin = ns.CreateSkin(header, rect)
    if not header.faugusSkin then return end
    ns.HideForever(header.Background)
    header.Text:ClearAllPoints()
    header.Text:SetPoint("LEFT", rect, "LEFT", PAD, 0)
    header.MinimizeButton:ClearAllPoints()
    header.MinimizeButton:SetPoint("RIGHT", rect, "RIGHT", -PAD, 0)
end

local function HookHeader(header)
    if not header or header.faugusHooked then return end
    header.faugusHooked = true
    header:HookScript("OnShow", SkinHeader)
    header:GetParent():HookScript("OnShow", function() SkinHeader(header) end)
    SkinHeader(header)
end

local function SkinAll()
    for _, module in ipairs(ObjectiveTrackerFrame.modules) do HookHeader(module.Header) end
end

ns.Module("ObjectiveTracker", "Quest Tracker", function()
    ns.WhenLoaded("ObjectiveTrackerFrame", "Blizzard_ObjectiveTracker", function()
        local tracker = ObjectiveTrackerFrame
        ns.HideForever(tracker.Header)
        hooksecurefunc(tracker, "AddModule", function(_, module) HookHeader(module.Header) end)
        local f = CreateFrame("Frame")
        f:RegisterEvent("PLAYER_ENTERING_WORLD")
        f:SetScript("OnEvent", function(self)
            self:UnregisterAllEvents()
            C_Timer.After(1, SkinAll)
        end)
    end)
end)
