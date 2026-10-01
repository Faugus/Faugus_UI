local _, ns = ...

local ICON_INSET = 2.5
local GAP = 1
local AURA_SIZE = 30

local function SkinAura(button)
    if button.isAuraAnchor or not (button.Icon and button.Icon:IsObjectType("Texture")) then return end
    local rect = CreateFrame("Frame", nil, button)
    rect:SetPoint("CENTER", button.Icon)
    local skin = ns.CreateSkin(button, rect, nil, true)
    if not skin then return end
    button.faugusRect, button.faugusSkin = rect, skin
    button.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    button.TempEnchantBorder:SetAlpha(0)
    button.DebuffBorder:ClearAllPoints()
    button.DebuffBorder:SetAllPoints(rect)
end

local function LayoutAuras(container, auras)
    local size = AURA_SIZE + (container.iconPadding or 5) - GAP
    for _, button in ipairs(auras) do
        local rect = button.faugusRect
        if rect then
            rect:SetSize(size, size)
            button.Icon:SetSize(size - 2 * ICON_INSET, size - 2 * ICON_INSET)
            local duration = button.Duration
            duration:ClearAllPoints()
            if not container.isHorizontal then
                if container.addIconsToRight then
                    duration:SetPoint("LEFT", rect, "RIGHT", GAP, 0)
                else
                    duration:SetPoint("RIGHT", rect, "LEFT", -GAP, 0)
                end
            elseif container.addIconsToTop then
                duration:SetPoint("BOTTOM", rect, "TOP", 0, GAP)
            else
                duration:SetPoint("TOP", rect, "BOTTOM", 0, -GAP)
            end
        end
    end
end

local function SkinShown(button)
    if button.faugusSkin or not button:IsShown() then return end
    SkinAura(button)
    if button.faugusSkin then LayoutAuras(button:GetParent(), { button }) end
end

local function SkinAll()
    for _, frame in ipairs({ BuffFrame, DebuffFrame }) do
        for _, button in ipairs(frame.auraFrames) do
            if not button.faugusShowHooked then
                button.faugusShowHooked = true
                button:HookScript("OnShow", SkinShown)
            end
            SkinShown(button)
        end
    end
end

local function ShownRects(frame)
    return function()
        local rects = {}
        for _, button in ipairs(frame.auraFrames) do
            if button.faugusRect and button:IsShown() then rects[#rects + 1] = button.faugusRect end
        end
        return rects
    end
end

ns.Module("Auras", "Auras", function()
    ns.WhenLoaded("BuffFrame", "Blizzard_BuffFrame", function()
        for _, frame in ipairs({ BuffFrame, DebuffFrame }) do
            hooksecurefunc(frame.AuraContainer, "UpdateGridLayout", LayoutAuras)
        end
        local f = CreateFrame("Frame")
        f:RegisterEvent("PLAYER_ENTERING_WORLD")
        f:SetScript("OnEvent", function(self)
            self:UnregisterAllEvents()
            SkinAll()
            C_Timer.After(1, SkinAll)
            for _, frame in ipairs({ BuffFrame, DebuffFrame }) do
                local fit = ns.KeepOffScreenEdge(frame, ShownRects(frame))
                if fit then
                    local function FitLater() C_Timer.After(0, fit) end
                    frame.Selection:HookScript("OnShow", FitLater)
                    hooksecurefunc(frame.AuraContainer, "UpdateGridLayout", function()
                        if frame.Selection:IsShown() then FitLater() end
                    end)
                end
            end
        end)
    end)
end)
