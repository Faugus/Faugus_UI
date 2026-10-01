local _, ns = ...

local BAR_INSET = 2.5
local BAR_SHRINK = 2

local function HideDividers(container)
    local pool = container.HorizontalDividersPool
    if not pool then return end
    for divider in pool:EnumerateActive() do divider:Hide() end
end

local function GetSizeScale(container)
    local setting = Enum.EditModeStatusTrackingBarSetting.Size
    if not (container.HasSetting and container:HasSetting(setting)) then return 1 end
    return container:GetSettingValue(setting) / 100
end

local function LayoutBars(container)
    local main, first, last = MainStatusTrackingBarContainer, ActionButton1, ActionButton12
    local left, right = first:GetLeft(), last:GetRight()
    if not (left and right) then return end
    local width = (right - left) * first:GetEffectiveScale() / main:GetEffectiveScale() * GetSizeScale(main)
    local height = container:GetHeight()
    local side = BAR_INSET - PixelUtil.GetNearestPixelSize(1, container:GetEffectiveScale(), 1)
    container:SetWidth(width)
    local barWidth, barHeight = width - STATUS_BAR_SIZE_ADJUSTMENT - 2 * side, height - STATUS_BAR_SIZE_ADJUSTMENT - BAR_SHRINK
    for _, bar in ipairs(container.bars) do
        bar:ClearAllPoints()
        bar:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", 1 + side, STATUS_BAR_SIZE_ADJUSTMENT - 1 + BAR_SHRINK / 2)
        bar:SetSize(barWidth, barHeight)
        bar.StatusBar:SetSize(barWidth, barHeight)
        local fill = bar.ExhaustionLevelFillBar
        if fill and fill:IsShown() then fill:SetWidth(select(5, fill:GetTexCoord()) * barWidth) end
    end
end

local FILL = "UI-HUD-ExperienceBar-Fill-"
local BAR_COLORS = {
    [FILL .. "Experience"] = { 0.58, 0, 0.55 },
    [FILL .. "Rested"] = { 0, 0.39, 0.88 },
    [FILL .. "Reputation-Faction-Red"] = { 0.8, 0.3, 0.22 },
    [FILL .. "Reputation-Faction-Orange"] = { 0.75, 0.27, 0 },
    [FILL .. "Reputation-Faction-Yellow"] = { 0.9, 0.7, 0 },
    [FILL .. "Reputation-Faction-Green"] = { 0, 0.6, 0.1 },
    [FILL .. "Reputation-Faction-Blue"] = { 0, 0.39, 0.88 },
}

local PREDICTION_COLOR = BAR_COLORS[FILL .. "Rested"]
local PREDICTION_ALPHA = 0.4

local function ColorBar(statusBar)
    local tex, fill = statusBar.faugusTexture, statusBar:GetStatusBarTexture()
    if not tex then return end
    local color = BAR_COLORS[fill:GetAtlas() or ""]
    tex:SetShown(color ~= nil)
    fill:SetAlpha(color and 0 or 1)
    if color then tex:SetVertexColor(color[1], color[2], color[3]) end
end

local function StylePrediction(bar)
    local fill, statusBar = bar.ExhaustionLevelFillBar, bar.StatusBar
    if not fill then return end
    local source = statusBar.faugusTexture
    local tex = statusBar:CreateTexture(nil, "ARTWORK")
    tex:SetTexture(source:GetTexture())
    tex:SetTexCoord(source:GetTexCoord())
    tex:SetDesaturated(true)
    tex:SetVertexColor(PREDICTION_COLOR[1], PREDICTION_COLOR[2], PREDICTION_COLOR[3])
    tex:SetAlpha(PREDICTION_ALPHA)
    tex:SetPoint("TOPLEFT", statusBar)
    tex:SetPoint("BOTTOMLEFT", statusBar)
    tex:SetPoint("RIGHT", fill)
    local function Sync() tex:SetShown(fill:IsShown()) end
    hooksecurefunc(fill, "Show", Sync)
    hooksecurefunc(fill, "Hide", Sync)
    hooksecurefunc(fill, "SetShown", Sync)
    Sync()
    fill:SetAlpha(0)
end

local function StyleBar(bar)
    local statusBar = bar.StatusBar
    if not statusBar or statusBar.faugusTexture then return end
    ns.OverlayBarTexture(statusBar, "none")
    if not statusBar.faugusTexture then return end
    hooksecurefunc(statusBar, "SetStatusBarTexture", ColorBar)
    ColorBar(statusBar)
    local rect = CreateFrame("Frame", nil, statusBar)
    rect:SetPoint("TOPLEFT", statusBar, "TOPLEFT", -BAR_INSET, BAR_INSET)
    rect:SetPoint("BOTTOMRIGHT", statusBar, "BOTTOMRIGHT", BAR_INSET, -BAR_INSET)
    if ns.CreateSkin(statusBar, rect, rect, nil, true) and statusBar.Background then statusBar.Background:SetAlpha(0) end
    local text = bar.OverlayFrame and bar.OverlayFrame.Text
    if text then
        text:ClearAllPoints()
        text:SetPoint("CENTER", bar.OverlayFrame, "CENTER")
    end
    StylePrediction(bar)
    local tick = bar.ExhaustionTick
    if tick then
        tick:SetAlpha(0)
        tick:EnableMouse(false)
    end
end

local showSecondary = false

local function ApplyShownBar()
    local main, second = MainStatusTrackingBarContainer, SecondaryStatusTrackingBarContainer
    local useSecond = showSecondary and second:IsShown()
    for container, visible in pairs({ [main] = not useSecond, [second] = useSecond }) do
        for _, bar in pairs(container.bars) do
            bar:SetAlpha(visible and 1 or 0)
            bar:EnableMouse(visible)
        end
    end
end

local function ToggleBar(_, button)
    if button ~= "LeftButton" then return end
    showSecondary = not showSecondary
    ApplyShownBar()
end

local function OverlapBars()
    local second = SecondaryStatusTrackingBarContainer
    second:ClearAllPointsBase()
    second:SetPointBase("CENTER", MainStatusTrackingBarContainer, "CENTER")
end

ns.Module("StatusBars", "Status Bars", function()
    ns.WhenLoaded("MainStatusTrackingBarContainer", "Blizzard_StatusTrackingBar", function()
        local containers = { MainStatusTrackingBarContainer, SecondaryStatusTrackingBarContainer }
        local function MatchAll()
            for _, container in ipairs(containers) do LayoutBars(container) end
        end
        for _, container in ipairs(containers) do
            container.BarFrameTexture:SetAlpha(0)
            hooksecurefunc(container, "UpdateDividers", HideDividers)
            HideDividers(container)
            for _, bar in pairs(container.bars) do
                bar:HookScript("OnMouseUp", ToggleBar)
                if bar:IsShown() then StyleBar(bar) else bar:HookScript("OnShow", StyleBar) end
            end
        end
        local second = SecondaryStatusTrackingBarContainer
        hooksecurefunc(second, "SetPoint", OverlapBars)
        if second.Selection then second.Selection:EnableMouse(false) end
        second:HookScript("OnShow", ApplyShownBar)
        second:HookScript("OnHide", ApplyShownBar)
        OverlapBars()
        ApplyShownBar()
        hooksecurefunc(StatusTrackingBarManager, "CheckForLayoutChange", MatchAll)
        MainStatusTrackingBarContainer:HookScript("OnSizeChanged", MatchAll)
        ActionButton1:GetParent():HookScript("OnSizeChanged", MatchAll)
        local f = CreateFrame("Frame")
        f:RegisterEvent("PLAYER_ENTERING_WORLD")
        f:SetScript("OnEvent", MatchAll)
    end)
end)
