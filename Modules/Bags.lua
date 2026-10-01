local _, ns = ...

local SEARCH_TOP = -27
local BAGS_BAR_NUDGE = 2
local SetFrameAlpha = getmetatable(UIParent).__index.SetAlpha
local spacers = {}

local function HideExtendedSlots(frame)
    for _, button in frame:EnumerateValidItems() do
        if button:IsExtended() ~= (button.faugusExtended or false) then
            button.faugusExtended = button:IsExtended()
            SetFrameAlpha(button, button.faugusExtended and 0 or 1)
            if button.extendedFrame then button.extendedFrame:EnableMouse(not button.faugusExtended) end
        end
    end
end

local function SortBottomRight(a, b)
    local bagA, bagB = a:GetBagID(), b:GetBagID()
    if bagA ~= bagB then return bagA > bagB end
    return a:GetID() > b:GetID()
end

local function AlignSearch(frame)
    local search, sort = BagItemSearchBox, BagItemAutoSortButton
    if search.anchorBag ~= frame or InputUtil.IsGamepadUIEnabled() or not frame:GetTop() then return end
    local left, right, top
    for _, button in frame:EnumerateValidItems() do
        if not button:IsExtended() and button:GetLeft() then
            left = math.min(left or button:GetLeft(), button:GetLeft())
            right = math.max(right or button:GetRight(), button:GetRight())
            top = math.max(top or button:GetTop(), button:GetTop())
        end
    end
    if not (left and search:GetLeft() and search.Left:GetLeft() and search.Right:GetRight()) then return end
    local m = ns.SCREEN_MARGIN
    local leftExtent = search:GetLeft() - search.Left:GetLeft()
    local rightExtent = search.Right:GetRight() - search:GetRight()
    sort:ClearAllPoints()
    sort:SetPoint("TOPRIGHT", frame, "TOPLEFT", right - frame:GetLeft(), SEARCH_TOP)
    search:ClearAllPoints()
    search:SetPoint("RIGHT", sort, "LEFT", -(m + rightExtent), 0)
    search:SetWidth((right - left) / 2 - sort:GetWidth() - m - rightExtent - leftExtent)
    local shrink = frame:GetTop() - top - (-SEARCH_TOP + sort:GetHeight() + m)
    if math.abs(shrink) > 0.1 then
        frame.faugusShrink = (frame.faugusShrink or 0) + shrink
        frame:SetHeight(frame:GetHeight() - shrink)
    end
end

local function ApplyShrink(frame)
    if frame.faugusShrink then frame:SetHeight(frame:GetHeight() - frame.faugusShrink) end
end

local function LayoutItems(frame)
    if InputUtil.IsGamepadUIEnabled() then return end
    local items = {}
    for _, button in frame:EnumerateValidItems() do
        if not button:IsExtended() then
            if InCombatLockdown() and button:IsProtected() then return end
            items[#items + 1] = button
        end
    end
    if #items == 0 then return end
    table.sort(items, SortBottomRight)
    local columns = frame:GetColumns()
    local missing = (columns - #items % columns) % columns
    for i = 1, missing do
        local spacer = spacers[i] or CreateFrame("Frame")
        spacers[i] = spacer
        spacer:SetSize(items[1]:GetSize())
        table.insert(items, 1, spacer)
    end
    AnchorUtil.GridLayout(items, frame:GetInitialItemAnchor(), frame:GetAnchorLayout())
    AlignSearch(frame)
end

local function GetBagsBarTop()
    if not BagsBar:IsShown() then return 0 end
    local top
    for _, visual in ipairs(ns.GetVisuals(BagsBar)) do
        if visual:GetTop() then
            local y = visual:GetTop() * visual:GetEffectiveScale() / UIParent:GetEffectiveScale()
            top = math.max(top or y, y)
        end
    end
    return top or 0
end

local function AnchorBags()
    local frame = ContainerFrameSettingsManager:GetBagsShown()[1]
    if not frame then return end
    local ratio = UIParent:GetEffectiveScale() / frame:GetEffectiveScale()
    local m = ns.SCREEN_MARGIN
    frame:ClearAllPoints()
    frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -m * ratio, (GetBagsBarTop() + m + BAGS_BAR_NUDGE) * ratio)
end

local function HideAddSlots(frame)
    ns.HideForever(frame.AddSlotsButton)
end

ns.Module("Bags", "Bags", function()
    ns.WhenLoaded("ContainerFrameCombinedBags", "Blizzard_UIPanels_Game", function()
        hooksecurefunc("UpdateContainerFrameAnchors", AnchorBags)
        for _, frame in ipairs({ ContainerFrameCombinedBags, ContainerFrame1 }) do
            hooksecurefunc(frame, "UpdateItems", HideExtendedSlots)
            hooksecurefunc(frame, "UpdateAddSlots", HideAddSlots)
            hooksecurefunc(frame, "UpdateItemLayout", LayoutItems)
            hooksecurefunc(frame, "UpdateSearchBox", AlignSearch)
            hooksecurefunc(frame, "UpdateFrameSize", ApplyShrink)
            HideAddSlots(frame)
        end
    end)
end)
