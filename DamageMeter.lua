local _, ns = ...

local BAR_SIDE_INSET = 5
local BAR_TOP_GAP = 2
local BORDER_THICKNESS = 2.5
local BODY_GAP = 2
local LIST_BOTTOM = 6
local SCROLL_INSET = 4
local SIDE = BAR_SIDE_INSET - BORDER_THICKNESS
local BODY_TOP = BORDER_THICKNESS - BAR_TOP_GAP
local HEADER_BOTTOM = BODY_TOP + BODY_GAP

local measure = UIParent:CreateFontString(nil, "OVERLAY")
measure:Hide()

local function LayoutName(entry)
    local bar, name, value = entry:GetStatusBar(), entry:GetName(), entry:GetValue()
    local clip = entry.faugusClip
    if not clip then
        clip = CreateFrame("Frame", nil, bar)
        clip:SetClipsChildren(true)
        local inner = CreateFrame("Frame", nil, clip)
        inner:SetAllPoints()
        name:SetParent(inner)
        entry.faugusClip = clip
    end
    clip:ClearAllPoints()
    clip:SetPoint("TOP", bar, "TOP")
    clip:SetPoint("BOTTOM", bar, "BOTTOM")
    clip:SetPoint("LEFT", bar, "LEFT", 5, 0)
    clip:SetPoint("RIGHT", value, "LEFT", -10, 0)
    name:ClearAllPoints()
    name:SetPoint("LEFT", clip, "LEFT", -(entry.faugusPrefix or 0), 0)
    name:SetPoint("RIGHT", clip, "RIGHT")
end

local function HideBackground(entry)
    for _, region in ipairs(entry:GetBackgroundRegions()) do region:SetAlpha(0) end
end

local function Restyle(entry)
    HideBackground(entry)
    if entry:GetStyle() == Enum.DamageMeterStyle.Thin then return end
    local bar = entry:GetStatusBar()
    entry:SetClipsChildren(false)
    bar:ClearAllPoints()
    bar:SetPoint(entry:GetIconAttachmentAnchor())
    local spacing = DamageMeter:GetBarSpacing()
    local target = entry:GetParent()
    local box = target and target:GetParent()
    local up = box and box.faugusAtEnd and spacing or 0
    bar:SetPoint("TOP", 0, up)
    bar:SetPoint("BOTTOMRIGHT", -4, up - spacing)
    entry:SetHitRectInsets(0, 0, -up, up - spacing)
    ns.OverlayBarTexture(bar, PlayerFrame.healthbar)
    LayoutName(entry)
end

local function UpdatePrefix(entry)
    local name = entry:GetName()
    local numbered = entry.index and (entry.deathRecapID or 0) == 0
    local key = numbered and (entry.index .. ":" .. name:GetTextScale()) or "none"
    if key == entry.faugusPrefixKey then return end
    entry.faugusPrefixKey = key
    local prefix = 0
    if numbered then
        measure:SetFont(name:GetFont())
        measure:SetTextScale(name:GetTextScale())
        measure:SetText(DAMAGE_METER_SOURCE_NAME:format(entry.index, ""))
        prefix = math.max(measure:GetStringWidth() - 2, 0)
    end
    entry.faugusPrefix = prefix
    Restyle(entry)
end

local function IsHovered(window)
    local header = window.faugusHeaderRect
    local sourceWindow = window:GetSourceWindow()
    local details = sourceWindow:IsShown() and sourceWindow.faugusRect
    return window:IsMouseOver()
        or (header and header:IsMouseOver(window.faugusHeaderBelow and BODY_GAP or 0, 0, 0, 0))
        or (details and details:IsMouseOver(BODY_GAP, -BODY_GAP, 0, 0))
end

local function UpdateHeader(window)
    local editing = EditModeManagerFrame:IsEditModeActive()
    local hovered = IsHovered(window)
    local alpha = hovered and not editing and 1 or 0
    window:GetSourceWindow():SetAlpha(editing and 0 or 1)
    if window.faugusHeaderSkin then ns.SetSkinAlpha(window.faugusHeaderSkin, alpha) end
    for _, region in ipairs({ window.DamageMeterTypeDropdown, window.SessionTimer, window.SettingsDropdown, window.SessionDropdown }) do
        region:SetAlpha(alpha)
    end
    if hovered and not window.faugusHoverTicker then
        window.faugusHoverTicker = C_Timer.NewTicker(0.2, function(ticker)
            if IsHovered(window) then return end
            ticker:Cancel()
            window.faugusHoverTicker = nil
            UpdateHeader(window)
        end)
    end
end

local function UpdateHeaders()
    DamageMeter:ForEachSessionWindow(UpdateHeader)
end

local function UpdateHeadersLater()
    C_Timer.After(0, UpdateHeaders)
end

local function HookHover(frame)
    frame:HookScript("OnEnter", UpdateHeaders)
    frame:HookScript("OnLeave", UpdateHeadersLater)
end

local function HookToggle(entry, window)
    local sourceWindow = window:GetSourceWindow()
    entry:HookScript("PreClick", function(self)
        self.faugusWasOpen = sourceWindow:IsShown() and sourceWindow.faugusIndex == self.index
    end)
    entry:HookScript("PostClick", function(self)
        if self.faugusWasOpen then
            sourceWindow:Hide()
        elseif sourceWindow:IsShown() then
            sourceWindow.faugusIndex = self.index
            sourceWindow:SetSticky(true)
        end
    end)
end

local function HookEntry(entry, window)
    if entry.faugusHooked then return end
    entry.faugusHooked = true
    if window then HookToggle(entry, window) end
    HookHover(entry)
    hooksecurefunc(entry, "UpdateStyle", Restyle)
    hooksecurefunc(entry, "UpdateBackground", HideBackground)
    if entry.Init == DamageMeterSourceEntryMixin.Init then
        hooksecurefunc(entry, "Init", UpdatePrefix)
        UpdatePrefix(entry)
    else
        Restyle(entry)
    end
end

local function HookScrollBox(scrollBox, window)
    if scrollBox.faugusHooked then return end
    scrollBox.faugusHooked = true
    ScrollUtil.AddAcquiredFrameCallback(scrollBox, function(_, entry) HookEntry(entry, window) end, scrollBox)
    scrollBox:ForEachFrame(function(entry) HookEntry(entry, window) end)
    scrollBox:RegisterCallback(BaseScrollBoxEvents.OnScroll, function()
        local atEnd = scrollBox:HasScrollableExtent() and scrollBox:GetScrollPercentage() > 0.999
        if atEnd == (scrollBox.faugusAtEnd or false) then return end
        scrollBox.faugusAtEnd = atEnd
        scrollBox:ForEachFrame(Restyle)
    end, scrollBox)
end

local ICON_GAP = 6

local function GetVisual(window, button)
    if button == window.SettingsDropdown then return button.Icon, button.Icon:GetWidth() end
    if button == window.DamageMeterTypeDropdown then return button.Arrow, button.Arrow:GetWidth() end
    return button.SessionName, button.SessionName:GetStringWidth()
end

local function LayoutButtons(window)
    local header = window.faugusHeaderRect
    local buttons = { window.SettingsDropdown, window.DamageMeterTypeDropdown, window.SessionDropdown }
    local _, centerY = header:GetCenter()
    local top = header:GetTop()
    if not (centerY and top) then return end
    local offsets = {}
    for i, button in ipairs(buttons) do
        local bx, by = button:GetCenter()
        local visual, width = GetVisual(window, button)
        local vx, vy = visual:GetCenter()
        if not (bx and vx) then return end
        offsets[i] = { vx - bx, vy - by, width }
    end
    local x, y = -ICON_GAP, centerY - top
    for i, button in ipairs(buttons) do
        local dx, dy, width = unpack(offsets[i])
        local centerX = x - width / 2
        button:ClearAllPoints()
        button:SetPoint("CENTER", header, "TOPRIGHT", centerX - dx, y - dy)
        x = centerX - width / 2 - ICON_GAP
    end
end

local function LayoutHeader(window)
    local settings, typeDropdown, session = window.SettingsDropdown, window.DamageMeterTypeDropdown, window.SessionDropdown
    window.MinimizeButton:Hide()
    session.Background:SetAlpha(0)
    session.Arrow:SetAlpha(0)
    settings.Icon:ClearAllPoints()
    settings.Icon:SetPoint("CENTER")
    local function SettingsIcon()
        ns.SetGoldIcon(settings.Icon, "questlog-icon-setting", settings, settings:IsOver())
    end
    local function ArrowIcon()
        ns.SetGoldIcon(typeDropdown.Arrow, "common-dropdown-c-button-hover-arrow", typeDropdown, typeDropdown:IsOver())
    end
    hooksecurefunc(settings, "OnButtonStateChanged", SettingsIcon)
    hooksecurefunc(typeDropdown, "OnButtonStateChanged", ArrowIcon)
    SettingsIcon()
    ArrowIcon()
    typeDropdown.TypeName:ClearAllPoints()
    typeDropdown.TypeName:SetPoint("LEFT", window.faugusHeaderRect, "LEFT", ICON_GAP, 0)
    window.SessionTimer:ClearAllPoints()
    window.SessionTimer:SetPoint("TOPLEFT", typeDropdown.TypeName, "TOPRIGHT", 4, 0)
    LayoutButtons(window)
    session:HookScript("OnSizeChanged", function() LayoutButtons(window) end)
end

local function AnchorHeader(window)
    local header, body = window.faugusHeaderRect, window.faugusBodyRect
    local sourceWindow = window:GetSourceWindow()
    local below = window.faugusHeaderBelow
    local details = sourceWindow:IsShown() and sourceWindow.faugusRect
    if details and window.faugusDetailsBelow ~= below then details = nil end
    header:ClearAllPoints()
    if below then
        local ref = details or body
        header:SetPoint("TOPLEFT", ref, "BOTTOMLEFT", 0, -BODY_GAP)
        header:SetPoint("TOPRIGHT", ref, "BOTTOMRIGHT", 0, -BODY_GAP)
    else
        local ref = details or body
        header:SetPoint("BOTTOMLEFT", ref, "TOPLEFT", 0, BODY_GAP)
        header:SetPoint("BOTTOMRIGHT", ref, "TOPRIGHT", 0, BODY_GAP)
    end
    LayoutButtons(window)
end

local function UpdateHeaderSide(window)
    local header, body = window.faugusHeaderRect, window.faugusBodyRect
    local bodyTop, windowTop = body:GetTop(), window:GetTop()
    local bodyBottom, windowBottom = body:GetBottom(), window:GetBottom()
    if not (bodyTop and windowTop and bodyBottom and windowBottom) then return end
    local screenTop = UIParent:GetTop() * UIParent:GetEffectiveScale() / window:GetEffectiveScale()
    local needed = header:GetHeight() + BODY_GAP
    local below = screenTop - bodyTop < needed - 0.5
    if below ~= window.faugusHeaderBelow then
        window.faugusHeaderBelow = below
        AnchorHeader(window)
    end
    window:SetClampRectInsets(0, 0, bodyTop - windowTop, bodyBottom - windowBottom - (below and needed or 0))
end

local PlaceSourceWindow, FixMeterClamp

local function FitBody(window)
    local body, scrollBox, header = window.faugusBodyRect, window:GetScrollBox(), window:GetHeader()
    local headerBottom, windowBottom = header:GetBottom(), window:GetBottom()
    if not (body and headerBottom and windowBottom) or issecretvalue(headerBottom) or issecretvalue(windowBottom) then return end
    local stride = window:GetBarHeight() + window:GetBarSpacing()
    local available = headerBottom - BAR_TOP_GAP - windowBottom - LIST_BOTTOM
    if stride <= 0 or available <= 0 then return end
    local rows = math.max(math.floor(available / stride), 1)
    local leftover = available - rows * stride
    local anchor = DamageMeter:GetPoint(1)
    local trimTop = anchor and anchor:find("BOTTOM") ~= nil
    local offsets = {
        TOPLEFT = -BAR_TOP_GAP - (trimTop and leftover or 0),
        BOTTOMRIGHT = LIST_BOTTOM + (trimTop and 0 or leftover),
    }
    window.faugusFitting = true
    for i = 1, scrollBox:GetNumPoints() do
        local point, relativeTo, relativePoint, x = scrollBox:GetPoint(i)
        if offsets[point] then scrollBox:SetPoint(point, relativeTo, relativePoint, x, offsets[point]) end
    end
    window.faugusFitting = nil
    body:SetPoint("TOPLEFT", header, "BOTTOMLEFT", SIDE, BODY_TOP - (trimTop and leftover or 0))
    body:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -SIDE, offsets.BOTTOMRIGHT - BORDER_THICKNESS)
    local scrollBar = window:GetScrollBar()
    scrollBar:ClearAllPoints()
    scrollBar:SetPoint("TOPLEFT", scrollBox, "TOPRIGHT", 0, -SCROLL_INSET)
    scrollBar:SetPoint("BOTTOMLEFT", scrollBox, "BOTTOMRIGHT", 0, SCROLL_INSET)
    local sourceWindow = window:GetSourceWindow()
    if sourceWindow:IsShown() and sourceWindow.faugusRect then PlaceSourceWindow(sourceWindow, window) end
end

local function SkinWindow(window)
    local container = window:GetMinimizeContainer()
    if not window.faugusHeaderRect then
        ns.HideForever(window.Header)
        ns.HideForever(container.Background)
        local bodyRect = CreateFrame("Frame", nil, container)
        bodyRect:SetPoint("TOPLEFT", window.Header, "BOTTOMLEFT", SIDE, BODY_TOP)
        bodyRect:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -SIDE, 0)
        local bodyBorder = CreateFrame("Frame", nil, container)
        bodyBorder:SetAllPoints(bodyRect)
        bodyBorder:SetFrameLevel(container:GetFrameLevel() + 10)
        window.faugusHeaderRect = CreateFrame("Frame", nil, window)
        window.faugusBodyRect, window.faugusBodyBorder = bodyRect, bodyBorder
        bodyRect:SetScript("OnSizeChanged", function()
            UpdateHeaderSide(window)
            if window == DamageMeter:GetPrimarySessionWindow() then FixMeterClamp() end
        end)
        AnchorHeader(window)
    end
    local headerHeight = window.Header:GetHeight() - HEADER_BOTTOM
    window.faugusHeaderRect:SetHeight(math.max(headerHeight, ns.GetSkinMinSize(window) or headerHeight))
    window.faugusHeaderSkin = window.faugusHeaderSkin or ns.CreateSkin(window, window.faugusHeaderRect)
    window.faugusBodySkin = window.faugusBodySkin or ns.CreateSkin(container, window.faugusBodyRect, window.faugusBodyBorder)
    LayoutButtons(window)
    FitBody(window)
    UpdateHeaderSide(window)
    UpdateHeader(window)
end

local SOURCE_LEFT = 20 - BORDER_THICKNESS
local SOURCE_RIGHT = 26 - BORDER_THICKNESS
local SOURCE_TOP = 15 - BORDER_THICKNESS
local SOURCE_BOTTOM = 17 - BORDER_THICKNESS

local function SkinSourceWindow(sourceWindow)
    if not sourceWindow.faugusRect then
        ns.HideForever(sourceWindow.Background)
        sourceWindow:SetFrameStrata(DamageMeter:GetFrameStrata())
        ns.HideForever(sourceWindow:GetResizeButton())
        ns.HideForever(sourceWindow:GetCloseButton())
        local scrollBox = sourceWindow:GetScrollBox()
        local rect = CreateFrame("Frame", nil, sourceWindow)
        rect:SetPoint("TOPLEFT", scrollBox, "TOPLEFT", -BORDER_THICKNESS, BORDER_THICKNESS)
        rect:SetPoint("TOPRIGHT", sourceWindow, "TOPRIGHT", -SOURCE_RIGHT, -SOURCE_TOP)
        local border = CreateFrame("Frame", nil, sourceWindow)
        border:SetAllPoints(rect)
        border:SetFrameLevel(sourceWindow:GetFrameLevel() + 10)
        sourceWindow.faugusRect, sourceWindow.faugusBorder = rect, border
        sourceWindow:SetHitRectInsets(SOURCE_LEFT, SOURCE_RIGHT, SOURCE_TOP, SOURCE_BOTTOM)
    end
    sourceWindow.faugusSkin = sourceWindow.faugusSkin
        or ns.CreateSkin(sourceWindow, sourceWindow.faugusRect, sourceWindow.faugusBorder)
end

function PlaceSourceWindow(sourceWindow, window)
    SkinSourceWindow(sourceWindow)
    local header, body = window.faugusHeaderRect, window.faugusBodyRect
    local visualHeight = body:GetHeight()
    if issecretvalue(visualHeight) then visualHeight = sourceWindow:GetHeight() - SOURCE_TOP - SOURCE_BOTTOM end
    sourceWindow.faugusRect:SetHeight(visualHeight)
    local screenTop = UIParent:GetTop() * UIParent:GetEffectiveScale() / body:GetEffectiveScale()
    local needed = visualHeight + BODY_GAP + header:GetHeight() + BODY_GAP
    local below = window.faugusHeaderBelow or (body:GetTop() or 0) + needed > screenTop
    window.faugusDetailsBelow = below
    sourceWindow:ClearAllPoints()
    if below then
        local y = SOURCE_TOP - BODY_GAP
        sourceWindow:SetPoint("TOPLEFT", body, "BOTTOMLEFT", -SOURCE_LEFT, y)
        sourceWindow:SetPoint("TOPRIGHT", body, "BOTTOMRIGHT", SOURCE_RIGHT, y)
    else
        local y = BODY_GAP - SOURCE_BOTTOM
        sourceWindow:SetPoint("BOTTOMLEFT", body, "TOPLEFT", -SOURCE_LEFT, y)
        sourceWindow:SetPoint("BOTTOMRIGHT", body, "TOPRIGHT", SOURCE_RIGHT, y)
    end
    sourceWindow:SetHeight(visualHeight + SOURCE_TOP + SOURCE_BOTTOM)
    AnchorHeader(window)
end

local function HookWindow(window)
    if window.faugusHooked then return end
    window.faugusHooked = true
    local sourceWindow = window:GetSourceWindow()
    hooksecurefunc(sourceWindow, "AnchorToSessionWindow", PlaceSourceWindow)
    sourceWindow:HookScript("OnShow", function()
        AnchorHeader(window)
        UpdateHeader(window)
    end)
    sourceWindow:HookScript("OnHide", function()
        AnchorHeader(window)
        UpdateHeader(window)
    end)
    SkinWindow(window)
    window:HookScript("OnShow", SkinWindow)
    window:HookScript("OnDragStop", UpdateHeaderSide)
    window:HookScript("OnSizeChanged", function()
        FitBody(window)
        UpdateHeaderSide(window)
    end)
    C_Timer.After(1, function() SkinWindow(window) end)
    LayoutHeader(window)
    HookEntry(window:GetMinimizeContainer().LocalPlayerEntry, window)
    local hoverArea = CreateFrame("Frame", nil, window)
    hoverArea:SetAllPoints(window.faugusHeaderRect)
    hoverArea:SetMouseMotionEnabled(true)
    hoverArea:SetMouseClickEnabled(false)
    for _, frame in ipairs({ window, hoverArea, window.SettingsDropdown, window.DamageMeterTypeDropdown, window.SessionDropdown }) do
        HookHover(frame)
    end
    HookScrollBox(window:GetScrollBox(), window)
    HookScrollBox(sourceWindow:GetScrollBox())
    ns.HideScrollArrows(window:GetScrollBar())
    ns.HideScrollArrows(sourceWindow.ScrollBar)
    hooksecurefunc(window:GetScrollBox(), "SetPoint", function()
        if not window.faugusFitting then FitBody(window) end
    end)
    hooksecurefunc(window, "SetBarHeight", FitBody)
end

local function UpdateAllHeaderSides()
    DamageMeter:ForEachSessionWindow(function(window)
        if window.faugusHeaderRect then UpdateHeaderSide(window) end
    end)
end

local function GetMeterOffsets()
    local window = DamageMeter:GetPrimarySessionWindow()
    local body = window and window.faugusBodyRect
    local bodyTop, meterTop = body and body:GetTop(), DamageMeter:GetTop()
    local bodyBottom, meterBottom = body and body:GetBottom(), DamageMeter:GetBottom()
    if not (bodyTop and meterTop and bodyBottom and meterBottom) then return end
    return bodyTop - meterTop, bodyBottom - meterBottom
end

local SNAP_DISTANCE = 6

local function SnapMeter()
    local window = DamageMeter:GetPrimarySessionWindow()
    local body = window and window.faugusBodyRect
    local bottom = body and body:GetBottom()
    local point, relativeTo, relativePoint, x, y = DamageMeter:GetPoint(1)
    if DamageMeter.faugusSnapping or not (bottom and point) then return end
    local m = ns.SCREEN_MARGIN
    local gap = bottom * body:GetEffectiveScale() / UIParent:GetEffectiveScale()
    if gap >= m + SNAP_DISTANCE or math.abs(gap - m) < 0.05 then return end
    local dy = (m - gap) * UIParent:GetEffectiveScale() / DamageMeter:GetEffectiveScale()
    DamageMeter.faugusSnapping = true
    ;(DamageMeter.ClearAllPointsBase or DamageMeter.ClearAllPoints)(DamageMeter)
    ;(DamageMeter.SetPointBase or DamageMeter.SetPoint)(DamageMeter, point, relativeTo, relativePoint, x, y + dy)
    DamageMeter.faugusSnapping = nil
end

function FixMeterClamp()
    local offset, bottom = GetMeterOffsets()
    if not offset then return end
    local left, right = DamageMeter:GetClampRectInsets()
    bottom = bottom - ns.SCREEN_MARGIN
    DamageMeter.faugusClamping = true
    DamageMeter:SetClampRectInsets(left, right, offset, bottom)
    DamageMeter.faugusClamping = nil
    local key = offset .. "," .. bottom
    if key ~= DamageMeter.faugusClampOffset and DamageMeter:IsClampedToScreen() then
        DamageMeter.faugusClampOffset = key
        DamageMeter:SetClampedToScreen(false)
        DamageMeter:SetClampedToScreen(true)
        local point, relativeTo, relativePoint, x, y = DamageMeter:GetPoint(1)
        if point then (DamageMeter.SetPointBase or DamageMeter.SetPoint)(DamageMeter, point, relativeTo, relativePoint, x, y) end
        UpdateAllHeaderSides()
    end
    SnapMeter()
end

local function FixMeterSelection()
    local offset, bottom = GetMeterOffsets()
    if not offset then return end
    local selection = DamageMeter.Selection
    selection:ClearAllPoints()
    selection:SetPoint("TOPLEFT", DamageMeter, "TOPLEFT", 0, offset)
    selection:SetPoint("BOTTOMRIGHT", DamageMeter, "BOTTOMRIGHT", 0, bottom)
    FixMeterClamp()
end

ns.Module("DamageMeter", "Damage Meter", function()
    ns.WhenLoaded("DamageMeter", "Blizzard_DamageMeter", function()
        hooksecurefunc(DamageMeter, "SetClampRectInsets", function(self)
            if not self.faugusClamping then FixMeterClamp() end
        end)
        DamageMeter.Selection:HookScript("OnShow", FixMeterSelection)
        if DamageMeter.windowDataList then DamageMeter:ForEachSessionWindow(HookWindow) end
        hooksecurefunc(DamageMeter, "SetBarSpacing", function()
            DamageMeter:ForEachSessionWindow(function(window)
                window:GetScrollBox():ForEachFrame(Restyle)
                window:GetSourceWindow():GetScrollBox():ForEachFrame(Restyle)
                FitBody(window)
            end)
        end)
        DamageMeter:HookScript("OnDragStop", UpdateAllHeaderSides)
        hooksecurefunc(DamageMeter, "SetPoint", function()
            SnapMeter()
            UpdateAllHeaderSides()
        end)
        C_Timer.After(1, function()
            FixMeterClamp()
            UpdateAllHeaderSides()
        end)
        local function FitLater()
            C_Timer.After(0, function()
                DamageMeter:ForEachSessionWindow(function(window)
                    if window.faugusBodyRect then FitBody(window) end
                end)
            end)
        end
        for _, method in ipairs({ "EnterEditMode", "ExitEditMode" }) do
            hooksecurefunc(EditModeManagerFrame, method, UpdateHeaders)
            hooksecurefunc(EditModeManagerFrame, method, FitLater)
        end
        hooksecurefunc(DamageMeter, "SetupSessionWindow", function(_, _, windowData)
            if windowData.sessionWindow then HookWindow(windowData.sessionWindow) end
        end)
    end)
end)



