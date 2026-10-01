local _, ns = ...

function ns.WhenLoaded(global, addon, func)
    if _G[global] then
        func()
        return
    end
    local f = CreateFrame("Frame")
    f:RegisterEvent("ADDON_LOADED")
    f:SetScript("OnEvent", function(self, _, name)
        if name ~= addon then return end
        self:UnregisterAllEvents()
        func()
    end)
end

function ns.HideForever(region)
    if not region or region.faugusHidden then return end
    region.faugusHidden = true
    region:Hide()
    hooksecurefunc(region, "Show", region.Hide)
    hooksecurefunc(region, "SetShown", function(self, shown)
        if shown then self:Hide() end
    end)
end

function ns.HideRegionTextures(frame, keep)
    for _, region in ipairs({ frame:GetRegions() }) do
        if region:IsObjectType("Texture") and not keep[region] then ns.HideForever(region) end
    end
end

local function GetButtonTexture(tex, ref)
    local btn = ActionButton1
    local info = tex and tex:GetLeft() and C_Texture.GetAtlasInfo(tex:GetAtlas() or "")
    if not info then return end
    local ratio = tex:GetEffectiveScale() / ref:GetEffectiveScale()
    return {
        file = info.file,
        l = info.leftTexCoord, r = info.rightTexCoord,
        t = info.topTexCoord, b = info.bottomTexCoord,
        w = info.width, h = info.height,
        scale = tex:GetWidth() * ratio / info.width,
        left = (btn:GetLeft() - tex:GetLeft()) * ratio,
        top = (tex:GetTop() - btn:GetTop()) * ratio,
    }
end

local function GetCornerSlice(info)
    return math.floor(math.min(info.w, info.h) * 0.3)
end

local function GetCornerBase(info)
    return GetCornerSlice(info) * info.scale
end

local function SliceTexture(owner, rect, info, layer, sublevel, withCenter, list, shrinkBase, fullThickness)
    local anchor = CreateFrame("Frame", nil, rect)
    local m = GetCornerSlice(info)
    local base = m * info.scale
    local mu, mv = (info.r - info.l) * m / info.w, (info.b - info.t) * m / info.h
    local us = { info.l, info.l + mu, info.r - mu }
    local vs = { info.t, info.t + mv, info.b - mv }
    local pieces = {}
    for row = 1, 3 do
        for col = 1, 3 do
            local x = col == 1 and "LEFT" or col == 3 and "RIGHT" or ""
            local y = row == 1 and "TOP" or row == 3 and "BOTTOM" or ""
            if x ~= "" or y ~= "" or withCenter then
                local tex = owner:CreateTexture(nil, layer, nil, sublevel)
                tex:SetTexture(info.file)
                pieces[#pieces + 1] = { tex = tex, x = x, y = y, col = col, row = row }
                list[#list + 1] = tex
            end
        end
    end

    local function Coords(list, index, fraction)
        if index == 2 then return list[2], list[3] end
        local inner = list[1] + (list[2] - list[1]) * fraction
        if index == 1 then return list[1], inner end
        return inner, list[1]
    end

    local k, sw, sh = 1, base, base
    local function Layout()
        local w, h = rect:GetSize()
        local valid = not (issecretvalue(w) or issecretvalue(h)) and w > 0 and h > 0
        if fullThickness then
            if valid then
                sw = math.min(base, (w + 2 * info.left) / 2)
                sh = math.min(base, (h + 2 * info.top) / 2)
            end
        else
            if valid then k = math.min(1, w / (2 * (shrinkBase + 1)), h / (2 * (shrinkBase + 1))) end
            sw, sh = base * k, base * k
        end
        local fx, fy = fullThickness and sw / base or 1, fullThickness and sh / base or 1
        anchor:ClearAllPoints()
        anchor:SetPoint("TOPLEFT", rect, "TOPLEFT", -info.left * k, info.top * k)
        anchor:SetPoint("BOTTOMRIGHT", rect, "BOTTOMRIGHT", info.left * k, -info.top * k)
        for _, p in ipairs(pieces) do
            local tex, x, y = p.tex, p.x, p.y
            local u1, u2 = Coords(us, p.col, fx)
            local v1, v2 = Coords(vs, p.row, fy)
            tex:SetTexCoord(u1, u2, v1, v2)
            tex:ClearAllPoints()
            if x ~= "" and y ~= "" then
                tex:SetSize(sw, sh)
                tex:SetPoint(y .. x, anchor)
            elseif y ~= "" then
                tex:SetHeight(sh)
                tex:SetPoint(y .. "LEFT", anchor, y .. "LEFT", sw, 0)
                tex:SetPoint(y .. "RIGHT", anchor, y .. "RIGHT", -sw, 0)
            elseif x ~= "" then
                tex:SetWidth(sw)
                tex:SetPoint("TOP" .. x, anchor, "TOP" .. x, 0, -sh)
                tex:SetPoint("BOTTOM" .. x, anchor, "BOTTOM" .. x, 0, sh)
            else
                tex:SetPoint("TOPLEFT", anchor, "TOPLEFT", sw, -sh)
                tex:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", -sw, sh)
            end
        end
    end
    rect:HookScript("OnSizeChanged", Layout)
    Layout()
end

function ns.CreateSkin(owner, rect, borderOwner, borderOnly, fullThickness)
    local frame = GetButtonTexture(ActionButton1:GetNormalTexture(), owner)
    local slot = GetButtonTexture(ActionButton1.SlotBackground, owner)
    if not (frame and slot) then return end
    local textures = {}
    local shrinkBase = GetCornerBase(frame)
    if not borderOnly then
        SliceTexture(owner, rect, slot, "BACKGROUND", -8, true, textures, shrinkBase, fullThickness)
        local first = #textures + 1
        SliceTexture(owner, rect, slot, "BACKGROUND", -7, true, textures, shrinkBase, fullThickness)
        for i = first, #textures do textures[i]:SetVertexColor(0, 0, 0) end
    end
    SliceTexture(borderOwner or owner, rect, frame, "BORDER", -8, false, textures, shrinkBase, fullThickness)
    local skin = {}
    for _, tex in ipairs(textures) do skin[tex] = true end
    return skin
end

function ns.CreateHighlight(owner, rect)
    local frame = GetButtonTexture(ActionButton1:GetNormalTexture(), owner)
    local checked = GetButtonTexture(ActionButton1:GetCheckedTexture(), owner)
    if not (frame and checked) then return end
    local textures = {}
    SliceTexture(owner, rect, checked, "OVERLAY", 7, false, textures, GetCornerBase(frame))
    local skin = {}
    for _, tex in ipairs(textures) do skin[tex] = true end
    return skin
end

function ns.SetSkinAlpha(skin, alpha)
    for tex in pairs(skin) do tex:SetAlpha(alpha) end
end

function ns.GetSkinMinSize(owner)
    local frame = GetButtonTexture(ActionButton1:GetNormalTexture(), owner)
    return frame and 2 * (GetCornerBase(frame) + 1)
end

local ICON_BRIGHTNESS = 0.6
local ICON_HOVER_BRIGHTNESS = 1

function ns.SetGoldIcon(texture, atlas, owner, hover)
    local glow = owner.faugusGlow
    if not glow then
        glow = owner:CreateTexture(nil, "OVERLAY", nil, 7)
        glow:SetAllPoints(texture)
        glow:SetBlendMode("ADD")
        owner.faugusGlow = glow
    end
    for _, tex in ipairs({ texture, glow }) do
        tex:SetAtlas(atlas, tex == texture)
        tex:SetDesaturated(true)
        tex:SetVertexColor(NORMAL_FONT_COLOR:GetRGB())
    end
    glow:SetAlpha(hover and ICON_HOVER_BRIGHTNESS or ICON_BRIGHTNESS)
end

local BAR_CROP_X, BAR_CROP_Y = 0.02, 0.1

local function CopyBarColor(bar)
    local tex = bar and bar.faugusTexture
    if not tex then return end
    local r, g, b = bar:GetStatusBarColor()
    tex:SetVertexColor(r, g, b)
end

local unitColorHooked

local function HookUnitBarColors()
    if unitColorHooked then return end
    unitColorHooked = true
    hooksecurefunc("CompactUnitFrame_UpdateHealthColor", function(frame) CopyBarColor(frame.healthBar) end)
    hooksecurefunc("CompactUnitFrame_UpdatePowerColor", function(frame) CopyBarColor(frame.powerBar) end)
end

function ns.OverlayBarTexture(bar, colorMode)
    if bar.faugusTexture then return end
    local info = C_Texture.GetAtlasInfo(PlayerFrame.healthbar:GetStatusBarTexture():GetAtlas() or "")
    if not info then return end
    local fill = bar:GetStatusBarTexture()
    local width = info.rightTexCoord - info.leftTexCoord
    local tex = bar:CreateTexture(nil, "ARTWORK", nil, 1)
    tex:SetTexture(info.file)
    local left = width * BAR_CROP_X
    local top = (info.bottomTexCoord - info.topTexCoord) * BAR_CROP_Y
    tex:SetTexCoord(info.leftTexCoord + left, info.rightTexCoord - left, info.topTexCoord + top, info.bottomTexCoord - top)
    tex:SetDesaturated(true)
    tex:SetPoint("TOPLEFT", fill)
    tex:SetPoint("BOTTOMRIGHT", fill)
    tex:SetVertexColor(fill:GetVertexColor())
    if colorMode == "unit" then
        HookUnitBarColors()
    elseif colorMode ~= "none" then
        hooksecurefunc(fill, "SetVertexColor", function(_, r, g, b) tex:SetVertexColor(r, g, b) end)
        hooksecurefunc(bar, "SetStatusBarColor", function(_, r, g, b) tex:SetVertexColor(r, g, b) end)
    end
    fill:SetAlpha(0)
    bar.faugusTexture = tex
end

function ns.HideScrollArrows(scrollBar)
    if not scrollBar or scrollBar.faugusArrowsHidden then return end
    scrollBar.faugusArrowsHidden = true
    for _, button in ipairs({ scrollBar.Back, scrollBar.Forward }) do
        button:SetAlpha(0)
        button:EnableMouse(false)
    end
    scrollBar.Track:ClearAllPoints()
    scrollBar.Track:SetPoint("TOP")
    scrollBar.Track:SetPoint("BOTTOM")
end

ns.SCREEN_MARGIN = 2
local SNAP_DISTANCE = 6

function ns.GetVisuals(parent)
    if type(parent) == "function" then return parent() end
    local list = {}
    for _, child in ipairs({ parent:GetChildren() }) do
        if child:IsShown() and child:IsMouseEnabled() then
            list[#list + 1] = child.Background or (child.GetNormalTexture and child:GetNormalTexture()) or child
        end
    end
    return list
end

local function GetRect(region)
    local l, r, t, b = region:GetLeft(), region:GetRight(), region:GetTop(), region:GetBottom()
    if not l or issecretvalue(l) or issecretvalue(r) or issecretvalue(t) or issecretvalue(b) then return end
    return l, r, t, b
end

local function GetChildBounds(frame, parent, inset)
    local fl, fr, ft, fb = GetRect(frame)
    if not fl then return end
    local l, r, t, b
    for _, visual in ipairs(ns.GetVisuals(parent)) do
        local vl, vr, vt, vb = GetRect(visual)
        if vl then
            local k = visual:GetEffectiveScale() / frame:GetEffectiveScale()
            l = math.min(l or vl * k, vl * k)
            r = math.max(r or vr * k, vr * k)
            t = math.max(t or vt * k, vt * k)
            b = math.min(b or vb * k, vb * k)
        end
    end
    if not l then return end
    inset = inset or {}
    return l - fl + (inset.left or 0), r - fr - (inset.right or 0),
        t - ft - (inset.top or 0), b - fb + (inset.bottom or 0)
end

function ns.KeepOffScreenEdge(frame, parent, inset)
    local m = ns.SCREEN_MARGIN
    local function Apply(self)
        if self.faugusClamping then return end
        local l, r, t, b = GetChildBounds(self, parent, inset)
        if not l then return end
        self.faugusClamping = true
        self:SetClampRectInsets(l - m, r + m, t + m, b - m)
        self.faugusClamping = nil
        local key = l .. "," .. r .. "," .. t .. "," .. b
        if key ~= self.faugusClampKey and self:IsClampedToScreen() then
            self.faugusClampKey = key
            self:SetClampedToScreen(false)
            self:SetClampedToScreen(true)
            local point, relativeTo, relativePoint, x, y = self:GetPoint(1)
            if point then (self.SetPointBase or self.SetPoint)(self, point, relativeTo, relativePoint, x, y) end
        end
    end
    local function Snap(self)
        if self.faugusSnapping then return end
        local l, r, t, b = GetChildBounds(self, parent, inset)
        local left, right, top, bottom = GetRect(self)
        if not (l and left) then return end
        local ratio = UIParent:GetEffectiveScale() / self:GetEffectiveScale()
        local screenWidth, screenHeight = UIParent:GetWidth() * ratio, UIParent:GetHeight() * ratio
        local gaps = {
            left = left + l, right = screenWidth - (right + r),
            bottom = bottom + b, top = screenHeight - (top + t),
        }
        local dx, dy = 0, 0
        if gaps.left < m + SNAP_DISTANCE then dx = m - gaps.left
        elseif gaps.right < m + SNAP_DISTANCE then dx = gaps.right - m end
        if gaps.bottom < m + SNAP_DISTANCE then dy = m - gaps.bottom
        elseif gaps.top < m + SNAP_DISTANCE then dy = gaps.top - m end
        if math.abs(dx) < 0.05 and math.abs(dy) < 0.05 then return end
        local point, relativeTo, relativePoint, x, y = self:GetPoint(1)
        if not point then return end
        self.faugusSnapping = true
        ;(self.ClearAllPointsBase or self.ClearAllPoints)(self)
        ;(self.SetPointBase or self.SetPoint)(self, point, relativeTo, relativePoint, x + dx, y + dy)
        self.faugusSnapping = nil
    end
    hooksecurefunc(frame, "SetClampRectInsets", Apply)
    hooksecurefunc(frame, "SetPoint", Snap)
    Apply(frame)
    C_Timer.After(1, function()
        Apply(frame)
        Snap(frame)
    end)
    local selection = frame.Selection
    if not selection then return end
    local function FitSelection()
        if not selection:IsShown() then return end
        local l, r, t, b = GetChildBounds(frame, parent, inset)
        if not l then return end
        selection:ClearAllPoints()
        selection:SetPoint("TOPLEFT", frame, "TOPLEFT", l, t)
        selection:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", r, b)
        Apply(frame)
    end
    selection:HookScript("OnShow", FitSelection)
    return FitSelection
end

local modules = {}
local loaded = {}
local dialog

function ns.Module(key, name, init)
    modules[#modules + 1] = { key = key, name = name, init = init }
end

local function IsEnabled(key)
    return FaugusUIDB[key] ~= false
end

local function CreateButton(parent, text, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(110, 22)
    button:SetText(text)
    button:SetScript("OnClick", onClick)
    return button
end

local function ShowReloadDialog()
    if not dialog then
        dialog = CreateFrame("Frame", nil, UIParent)
        dialog:SetSize(300, 80)
        dialog:SetPoint("CENTER", 0, 150)
        dialog:SetFrameStrata("DIALOG")
        dialog:EnableMouse(true)
        ns.CreateSkin(dialog, dialog)
        local text = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        text:SetPoint("TOP", 0, -16)
        text:SetText("Faugus UI changes require reloading the UI.")
        local reload = CreateButton(dialog, RELOADUI, ReloadUI)
        reload:SetPoint("BOTTOMRIGHT", dialog, "BOTTOM", -4, 14)
        local later = CreateButton(dialog, "Later", function() dialog:Hide() end)
        later:SetPoint("BOTTOMLEFT", dialog, "BOTTOM", 4, 14)
    end
    dialog:Show()
end

local function CheckPending()
    for _, module in ipairs(modules) do
        if IsEnabled(module.key) ~= loaded[module.key] then
            ShowReloadDialog()
            return
        end
    end
end

local function CreateOptions()
    local category = Settings.RegisterVerticalLayoutCategory("Faugus UI")
    for _, module in ipairs(modules) do
        local setting = Settings.RegisterAddOnSetting(category, "FaugusUI_" .. module.key, module.key, FaugusUIDB, type(true), module.name, true)
        Settings.CreateCheckbox(category, setting, "Requires reloading the UI.")
    end
    Settings.RegisterAddOnCategory(category)
    ns.WhenLoaded("SettingsPanel", "Blizzard_Settings", function()
        SettingsPanel:HookScript("OnHide", CheckPending)
        local defaults = SettingsPanel:GetSettingsList().Header.DefaultsButton
        local function HideDefaults()
            if SettingsPanel:GetCurrentCategory() == category then defaults:Hide() end
        end
        defaults:HookScript("OnShow", HideDefaults)
        EventRegistry:RegisterCallback("Settings.CategoryChanged", function()
            defaults:Show()
            HideDefaults()
        end, defaults)
    end)
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, _, name)
    if name ~= "Faugus_UI" then return end
    self:UnregisterAllEvents()
    FaugusUIDB = FaugusUIDB or {}
    for _, module in ipairs(modules) do
        loaded[module.key] = IsEnabled(module.key)
        if loaded[module.key] then module.init() end
    end
    CreateOptions()
end)
