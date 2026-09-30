local _, ns = ...

local function HideDividers(bar)
    for _, pool in ipairs({ bar.HorizontalDividersPool, bar.VerticalDividersPool }) do
        for divider in pool:EnumerateActive() do divider:Hide() end
    end
end

ns.Module("MicroMenu", "Micro Menu and Bags Bar", function()
    ns.WhenLoaded("MicroMenu", "Blizzard_MicroMenu", function()
        ns.HideForever(MicroMenu.BorderArt)
        ns.HideForever(MicroMenu.BackgroundArt)
        ns.HideForever(MainMenuMicroButton.MainMenuBarPerformanceBar)
        ns.KeepOffScreenEdge(MicroMenuContainer, MicroMenu, { left = 2.3, right = 2.3, top = 5.3, bottom = 3.7 })
    end)

    ns.WhenLoaded("BagsBar", "Blizzard_MainMenuBarBagButtons", function()
        ns.HideForever(BagsBar.BorderArt)
        hooksecurefunc(BagsBar, "UpdateDividers", HideDividers)
        if BagsBar.HorizontalDividersPool then HideDividers(BagsBar) end
        ns.KeepOffScreenEdge(BagsBar, BagsBar, { left = 0.5, right = 1.33 })
    end)
end)
