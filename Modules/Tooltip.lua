local _, ns = ...

ns.Module("Tooltip", "Tooltip", function()
    local bar = GameTooltip.StatusBar
    bar:ClearAllPoints()
    bar:SetPoint("BOTTOMLEFT", GameTooltip, "TOPLEFT", 2, 1)
    bar:SetPoint("BOTTOMRIGHT", GameTooltip, "TOPRIGHT", -2, 1)
end)
