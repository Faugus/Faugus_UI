local _, ns = ...

local BAR_INSET = 2.5
local CC_SCALE = 1.4
local CAST_GAP = 0
local CAST_INSET = 1
local IMPORTANT_PULL = 10
local NAME_SHRINK = 2

local function LayoutCastBar(unitFrame, setup)
    if setup.useClassicCastBar then return end
    local container = unitFrame.HealthBarsContainer
    local castBar = unitFrame.CastBarsContainer.castBar
    local gap = 2 * BAR_INSET + CAST_GAP
    castBar:ClearAllPoints()
    castBar:SetPoint("TOPLEFT", container, "BOTTOMLEFT", CAST_INSET, -gap)
    castBar:SetPoint("TOPRIGHT", container, "BOTTOMRIGHT", -CAST_INSET, -gap)
    if not setup.spellNameInsideCastBar then
        castBar.Icon:ClearAllPoints()
        castBar.Icon:SetPoint("TOPLEFT", castBar, "BOTTOMLEFT", 0, -(BAR_INSET + ns.SCREEN_MARGIN))
    end
    local important = castBar.ImportantCastIndicator
    if important then
        local small = CVarCallbackRegistry:GetCVarNumberOrDefault(NamePlateConstants.SIZE_CVAR) < 2
        important:ClearAllPoints()
        important:SetPoint("TOPLEFT", castBar, "TOPLEFT", (small and -20 or -26) + IMPORTANT_PULL, 3)
        important:SetPoint("BOTTOMRIGHT", castBar, "BOTTOMRIGHT", (small and 20 or 25) - IMPORTANT_PULL, -3)
    end
end

local function ApplyLayout(unitFrame)
    local container = unitFrame.HealthBarsContainer
    local level = unitFrame.PlayerLevelDiffFrame
    if level then
        level.playerLevelDiffText:ClearAllPoints()
        level.playerLevelDiffText:SetPoint("LEFT", unitFrame.faugusRect, "RIGHT", ns.SCREEN_MARGIN, 0)
    end
    local setup = NamePlateSetupOptions
    unitFrame.name:SetFontHeight(setup.healthBarFontHeight - NAME_SHRINK)
    LayoutCastBar(unitFrame, setup)
    local auras = unitFrame.AurasFrame
    local onlyName = unitFrame:IsShowOnlyName()
    if not onlyName then
        unitFrame.RaidTargetFrame:ClearAllPoints()
        unitFrame.RaidTargetFrame:SetPoint("RIGHT", unitFrame.faugusRect, "LEFT", -ns.SCREEN_MARGIN, 0)
    end
    if auras then
        auras.BuffListFrame:ClearAllPoints()
        auras.BuffListFrame:SetPoint("RIGHT", unitFrame.ClassificationFrame, "LEFT")
        for _, frame in ipairs({ auras.CrowdControlListFrame, auras.LossOfControlFrame }) do
            frame:SetScale(CC_SCALE)
            frame:SetFrameLevel(level:GetFrameLevel() + 10)
            frame:ClearAllPoints()
            frame:SetPoint("LEFT", unitFrame.faugusRect, "RIGHT", ns.SCREEN_MARGIN / CC_SCALE, 0)
        end
    end
    if onlyName or setup.unitNameAnchorStyle == NamePlateConstants.NAME_ANCHOR_STYLES.InsideHealthBar then return end
    local name = unitFrame.name
    name:ClearAllPoints()
    name:SetPoint("BOTTOMLEFT", container, "TOPLEFT", 0, setup.healthBarToNameAboveSpacing)
    name:SetPoint("BOTTOMRIGHT", container, "TOPRIGHT", 0, setup.healthBarToNameAboveSpacing)
    name:SetJustifyH("CENTER")
end

local function UpdateSelection(bar)
    local selected = bar:ShouldUseSelectedBorder() and (bar:IsTarget() or bar:IsFocus())
    local color = not bar:IsTarget() and NAMEPLATE_BORDER_FOCUS_TARGET_COLOR or WHITE_FONT_COLOR
    for tex in pairs(bar.faugusHighlight) do
        tex:SetAlpha(selected and 1 or 0)
        tex:SetVertexColor(color.r, color.g, color.b)
    end
end

local function SkinPlate(unitFrame)
    local container = unitFrame and unitFrame.HealthBarsContainer
    local bar = container and container.healthBar
    if not bar or unitFrame.faugusSkin then return end
    local rect = CreateFrame("Frame", nil, bar)
    rect:SetPoint("TOPLEFT", bar, "TOPLEFT", -BAR_INSET, BAR_INSET)
    rect:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", BAR_INSET, -BAR_INSET)
    unitFrame.faugusSkin = ns.CreateSkin(bar, rect)
    if not unitFrame.faugusSkin then return end
    unitFrame.faugusRect = rect
    bar.bgTexture:SetAlpha(0)
    bar.selectedBorder:SetAlpha(0)
    bar.faugusHighlight = ns.CreateHighlight(bar, rect) or {}
    hooksecurefunc(bar, "UpdateSelectionBorder", UpdateSelection)
    UpdateSelection(bar)
    ns.OverlayBarTexture(bar)
    local level = unitFrame.PlayerLevelDiffFrame
    if level then
        level.playerLevelDiffIcon:SetAlpha(0)
        level.selectedBorder:SetAlpha(0)
    end
    local castBar = unitFrame.CastBarsContainer.castBar
    local castRect = CreateFrame("Frame", nil, castBar)
    castRect:SetPoint("TOPLEFT", castBar, "TOPLEFT", -BAR_INSET, BAR_INSET)
    castRect:SetPoint("BOTTOMRIGHT", castBar, "BOTTOMRIGHT", BAR_INSET, -BAR_INSET)
    if ns.CreateSkin(castBar, castRect) then castBar.Background:SetAlpha(0) end
    hooksecurefunc(unitFrame, "UpdateAnchors", ApplyLayout)
    ApplyLayout(unitFrame)
end

ns.Module("Nameplates", "Nameplates", function()
    ns.WhenLoaded("NamePlateDriverFrame", "Blizzard_NamePlates", function()
        hooksecurefunc(NamePlateDriverFrame, "OnNamePlateAdded", function(driver, unit)
            local plate = driver:GetNamePlateForUnit(unit)
            if plate and not plate:IsForbidden() then SkinPlate(plate.UnitFrame) end
        end)
    end)
end)

