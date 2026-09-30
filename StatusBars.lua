local _, ns = ...

local function HideDividers(container)
    local pool = container.HorizontalDividersPool
    if not pool then return end
    for divider in pool:EnumerateActive() do divider:Hide() end
end

local function MatchActionBarWidth(container)
    local first, last = ActionButton1, ActionButton12
    local left, right = first:GetLeft(), last:GetRight()
    if not (left and right) then return end
    local width = (right - left) * first:GetEffectiveScale() / container:GetEffectiveScale()
    local height = container:GetHeight()
    container:SetWidth(width)
    local barWidth, barHeight = width - STATUS_BAR_SIZE_ADJUSTMENT, height - STATUS_BAR_SIZE_ADJUSTMENT
    for _, bar in ipairs(container.bars or {}) do
        bar:SetSize(barWidth, barHeight)
        bar.StatusBar:SetSize(barWidth, barHeight)
        local fill, tick = bar.ExhaustionLevelFillBar, bar.ExhaustionTick
        if fill and fill:IsShown() then
            local ratio = select(5, fill:GetTexCoord())
            fill:SetWidth(ratio * barWidth)
            if tick then
                tick:ClearAllPoints()
                tick:SetPoint("CENTER", bar, "LEFT", ratio * barWidth, EXHAUSTION_TICK_OFFSET_Y or 0)
            end
        end
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
            if bar.ExhaustionTick then bar.ExhaustionTick:EnableMouse(visible) end
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
            for _, container in ipairs(containers) do MatchActionBarWidth(container) end
        end
        for _, container in ipairs(containers) do
            hooksecurefunc(container, "UpdateDividers", HideDividers)
            HideDividers(container)
        end
        for _, container in ipairs(containers) do
            for _, bar in pairs(container.bars) do bar:HookScript("OnMouseUp", ToggleBar) end
        end
        local second = SecondaryStatusTrackingBarContainer
        hooksecurefunc(second, "SetPoint", OverlapBars)
        second:HookScript("OnShow", ApplyShownBar)
        second:HookScript("OnHide", ApplyShownBar)
        OverlapBars()
        ApplyShownBar()
        hooksecurefunc(StatusTrackingBarManager, "CheckForLayoutChange", MatchAll)
        ActionButton1:GetParent():HookScript("OnSizeChanged", MatchAll)
        local f = CreateFrame("Frame")
        f:RegisterEvent("PLAYER_ENTERING_WORLD")
        f:SetScript("OnEvent", MatchAll)
    end)
end)
