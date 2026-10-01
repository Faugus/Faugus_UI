local _, ns = ...

local SCREEN_MARGIN = ns.SCREEN_MARGIN
local TAB_GAP = 2
local EDITBOX_GAP = 2
local HideForever, HideRegionTextures = ns.HideForever, ns.HideRegionTextures
local CreateSkin, SetSkinAlpha = ns.CreateSkin, ns.SetSkinAlpha

local ready = false
local SetupChat

local buttons = {
    "QuickJoinToastButton",
    "FriendsMicroButton",
    "ChatFrameChannelButton",
    "ChatFrameToggleVoiceDeafenButton",
    "ChatFrameToggleVoiceMuteButton",
    "ChatFrameMenuButton",
}

local function GetVisualBounds(chat)
    local cLeft, cRight, cTop, cBottom = chat:GetLeft(), chat:GetRight(), chat:GetTop(), chat:GetBottom()
    if not cLeft then return end
    local l, r, t, b = cLeft, cRight, cTop, cBottom
    local tab = _G[chat:GetName() .. "Tab"]
    local edit = chat.editBox or _G[chat:GetName() .. "EditBox"]
    local regions = { chat.faugusBorder, tab and tab.faugusRect, edit and edit.faugusRect }
    for i = 1, 3 do
        local region = regions[i]
        if not (region and region:GetLeft()) then return end
        l = math.min(l, region:GetLeft())
        r = math.max(r, region:GetRight())
        t = math.max(t, region:GetTop())
        b = math.min(b, region:GetBottom())
    end
    return l - cLeft, r - cRight, t - cTop, b - cBottom
end

local function FixClamp(chat)
    local l, r, t, b = GetVisualBounds(chat)
    local m = SCREEN_MARGIN
    if l then
        l, r, t, b = l - m, r + m, t + m, b - m
    else
        l, r, t, b = 0, 0, 0, 0
    end
    chat.faugusClamping = true
    chat:SetClampRectInsets(l, r, t, b)
    chat.faugusClamping = nil
    local insets = l .. "," .. r .. "," .. t .. "," .. b
    if insets ~= chat.faugusInsets and chat:IsClampedToScreen() then
        chat.faugusInsets = insets
        chat:SetClampedToScreen(false)
        chat:SetClampedToScreen(true)
        local point, relativeTo, relativePoint, x, y = chat:GetPoint(1)
        if point then (chat.SetPointBase or chat.SetPoint)(chat, point, relativeTo, relativePoint, x, y) end
    end
end

local function HookClamp(chat)
    if chat.faugusClampHooked then return end
    chat.faugusClampHooked = true
    hooksecurefunc(chat, "SetClampRectInsets", function(self)
        if not self.faugusClamping then FixClamp(self) end
    end)
    FixClamp(chat)
end

local function FixSelection(sel)
    local chat = sel:GetParent()
    local l, r, t, b = GetVisualBounds(chat)
    if not l then return end
    sel:ClearAllPoints()
    sel:SetPoint("TOPLEFT", chat, "TOPLEFT", l, t)
    sel:SetPoint("BOTTOMRIGHT", chat, "BOTTOMRIGHT", r, b)
end

local function SkinBorder(b)
    b.skin = b.skin or CreateSkin(b, b)
    return b.skin ~= nil
end

local function UpdateChatSkin(chat)
    local b = chat.faugusBorder
    if not b then
        for _, part in ipairs(CHAT_FRAME_TEXTURES) do
            local tex = _G[chat:GetName() .. part]
            if tex and tex:IsObjectType("Texture") then HideForever(tex) end
        end
        b = CreateFrame("Frame", nil, UIParent)
        chat:HookScript("OnShow", function()
            b:Show()
            SkinBorder(b)
        end)
        chat:HookScript("OnHide", function() b:Hide() end)
        b:SetShown(chat:IsShown())
        b:SetFrameStrata(chat:GetFrameStrata())
        b:SetFrameLevel(math.max(0, chat:GetFrameLevel() - 1))
        chat.faugusBorder = b
        b:SetPoint("TOPLEFT", _G[chat:GetName() .. "TopLeftTexture"], "TOPLEFT")
        b:SetPoint("BOTTOMRIGHT", _G[chat:GetName() .. "BottomRightTexture"], "BOTTOMRIGHT")
        HookClamp(chat)
        if chat.Selection then chat.Selection:HookScript("OnShow", FixSelection) end
    end
    return not chat:IsShown() or SkinBorder(b)
end

local tabMetrics

local function MeasureTabs()
    if tabMetrics then return tabMetrics end
    local tab = ChatFrame1Tab
    local text = tab.Text or tab:GetFontString()
    local textBottom, tabBottom, dockBottom = text:GetBottom(), tab:GetBottom(), GeneralDockManager:GetBottom()
    if not (textBottom and tabBottom and dockBottom) then return end
    local pushed = 0
    if tab:GetButtonState() == "PUSHED" then
        pushed = select(2, tab:GetPushedTextOffset())
    end
    textBottom = textBottom - pushed - 6
    tabMetrics = {
        tab = textBottom - tabBottom,
        dock = textBottom - dockBottom,
        height = text:GetStringHeight() + 12,
    }
    return tabMetrics
end

local function AnchorTabRect(tab, chat)
    local m = MeasureTabs()
    if not m then return false end
    local ref, y = tab, m.tab
    if chat.isDocked then ref, y = GeneralDockManager, m.dock end
    local rect = tab.faugusRect
    rect:ClearAllPoints()
    rect:SetPoint("LEFT", tab, "LEFT", 2, 0)
    rect:SetPoint("RIGHT", tab, "RIGHT", -2, 0)
    rect:SetPoint("BOTTOM", ref, "BOTTOM", 0, y)
    rect:SetPoint("TOP", ref, "BOTTOM", 0, y + m.height)
    return true
end

local function GetTabTextWidth(tab, text)
    local width, space = text:GetStringWidth(), tab.faugusRect:GetWidth() - 8
    return space > 0 and math.min(width, space) or width
end

local function CenterTabText(tab, text)
    local _, relativeTo = text:GetPoint(1)
    local width = GetTabTextWidth(tab, text)
    if text:GetNumPoints() == 1 and relativeTo == tab.faugusRect
            and math.abs(text:GetWidth() - width) <= 0.5 then
        return
    end
    text.faugusPlacing = true
    text:SetWidth(width)
    text:ClearAllPoints()
    text:SetPoint("CENTER", tab.faugusRect, "CENTER")
    text.faugusPlacing = nil
end

local function UpdateTabSkin(chat)
    local tab = _G[chat:GetName() .. "Tab"]
    local text = tab and (tab.Text or tab:GetFontString())
    if not text then return false end
    if not tab.faugusSkin and not tab:IsShown() then
        if not tab.faugusShowHooked then
            tab.faugusShowHooked = true
            tab:HookScript("OnShow", function() SetupChat(chat) end)
        end
        return true
    end
    if not tab.faugusSkin then
        tab.faugusRect = tab.faugusRect or CreateFrame("Frame", nil, tab)
        local skin = CreateSkin(tab, tab.faugusRect)
        if not skin then return false end
        local keep = setmetatable({}, { __index = skin })
        local glow = tab.glow
        if glow then
            keep[glow] = true
            local points = {}
            for i = 1, glow:GetNumPoints() do points[i] = { glow:GetPoint(i) } end
            glow:ClearAllPoints()
            for _, p in ipairs(points) do
                glow:SetPoint(p[1], p[2], p[3], p[4], p[5] + 2)
            end
        end
        HideRegionTextures(tab, keep)
        tab.faugusSkin = skin
    end
    if not AnchorTabRect(tab, chat) then return false end
    if not text.faugusCentered then
        text.faugusCentered = true
        tab:SetPushedTextOffset(0, 0)
        local function Recenter()
            if not text.faugusPlacing then CenterTabText(tab, text) end
        end
        hooksecurefunc(text, "SetPoint", Recenter)
        hooksecurefunc(text, "SetWidth", Recenter)
        hooksecurefunc(text, "SetText", Recenter)
        hooksecurefunc(tab, "SetText", Recenter)
        CenterTabText(tab, text)
    end
    return true
end

local function UpdateTabAlpha(chat, force)
    local tab = _G[chat:GetName() .. "Tab"]
    if not (tab and tab.faugusSkin) then return end
    local selected = not chat.isDocked or FCFDock_GetSelectedWindow(GENERAL_CHAT_DOCK) == chat
    if force or tab.faugusSelected ~= selected then
        tab.faugusSelected = selected
        SetSkinAlpha(tab.faugusSkin, selected and 1 or 0.5)
    end
end

local function PlaceTabs(chat)
    local b = chat.faugusBorder
    local tab = _G[chat:GetName() .. "Tab"]
    local rect = tab and tab.faugusRect
    if not (rect and rect:GetBottom()) then return end
    local target = tab
    if chat.isDocked then
        if GENERAL_CHAT_DOCK.primary ~= chat then return end
        target = GeneralDockManager
    end
    if not target:GetBottom() then return end
    if not target.faugusPlaceHooked then
        target.faugusPlaceHooked = true
        hooksecurefunc(target, "SetPoint", function(self)
            if not self.faugusPlacing then PlaceTabs(chat) end
        end)
    end
    local dx = rect:GetLeft() - target:GetLeft()
    local dy = rect:GetBottom() - target:GetBottom()
    target.faugusPlacing = true
    target:ClearAllPoints()
    target:SetPoint("BOTTOMLEFT", b, "TOPLEFT", -dx, TAB_GAP - dy)
    if target ~= tab then
        target:SetPoint("BOTTOMRIGHT", b, "TOPRIGHT", 0, TAB_GAP - dy)
    end
    target.faugusPlacing = nil
end

local OVERFLOW_ARROW = "common-dropdown-c-button-hover-arrow"

local function RefreshArrow(button)
    button:SetAlpha(1)
    ns.SetGoldIcon(button:GetNormalTexture(), OVERFLOW_ARROW, button, button:IsMouseOver())
end

local function UpdateOverflowButton()
    local button = GENERAL_CHAT_DOCK.overflowButton or GeneralDockManagerOverflowButton
    local rect = _G[GENERAL_CHAT_DOCK.primary:GetName() .. "Tab"].faugusRect
    if not (button and rect and rect:GetTop() and GeneralDockManager:GetTop()) then return end
    local size = rect:GetHeight()
    local dy = rect:GetTop() - GeneralDockManager:GetTop()
    if not button.faugusSkin then
        button.faugusRect = CreateFrame("Frame", nil, button)
        button.faugusRect:SetPoint("TOPRIGHT")
        button.faugusRect:SetPoint("BOTTOMRIGHT")
        button.faugusSkin = CreateSkin(button, button.faugusRect)
        if not button.faugusSkin then return end
        hooksecurefunc(button, "SetPoint", function(self)
            if not self.faugusPlacing then UpdateOverflowButton() end
        end)
        button:HookScript("OnEnter", RefreshArrow)
        button:HookScript("OnLeave", RefreshArrow)
        button:GetHighlightTexture():SetTexture(nil)
        for _, tex in ipairs({ button:GetPushedTexture(), button:GetDisabledTexture() }) do
            tex:SetAlpha(0)
        end
    end
    button.faugusPlacing = true
    button:ClearAllPoints()
    button:SetPoint("TOPRIGHT", GeneralDockManager, "TOPRIGHT", 0, dy)
    button.faugusPlacing = nil
    button.faugusRect:SetWidth(size)
    button:SetSize(size, size)
    local arrow = button:GetNormalTexture()
    arrow:ClearAllPoints()
    arrow:SetPoint("CENTER", button.faugusRect)
    RefreshArrow(button)
    return true
end

local function PlaceEditBox(edit, chat)
    edit.faugusPlacing = true
    edit:ClearAllPoints()
    edit:SetPoint("TOPLEFT", chat.faugusBorder, "BOTTOMLEFT", 0, 2 - EDITBOX_GAP)
    edit:SetPoint("TOPRIGHT", chat.faugusBorder, "BOTTOMRIGHT", 0, 2 - EDITBOX_GAP)
    edit.faugusPlacing = nil
end

local function SkinEditBox(edit)
    if edit.faugusSkin then return true end
    local skin = CreateSkin(edit, edit.faugusRect)
    if not skin then return false end
    HideRegionTextures(edit, skin)
    edit.faugusSkin = skin
    return true
end

local function UpdateEditBoxSkin(chat)
    local edit = chat.editBox or _G[chat:GetName() .. "EditBox"]
    if not edit then return true end
    if not edit.faugusRect then
        hooksecurefunc(edit, "SetPoint", function(self)
            if not self.faugusPlacing then PlaceEditBox(self, chat) end
        end)
        edit.faugusRect = CreateFrame("Frame", nil, edit)
        edit.faugusRect:SetPoint("TOPLEFT", edit, "TOPLEFT", 0, -2)
        edit.faugusRect:SetPoint("BOTTOMRIGHT", edit, "BOTTOMRIGHT", 0, 2)
        edit:HookScript("OnShow", SkinEditBox)
        PlaceEditBox(edit, chat)
    end
    return not edit:IsShown() or SkinEditBox(edit)
end

local function FormatMessage(msg)
    if type(msg) ~= "string" or issecretvalue(msg) then return msg end
    msg = msg:gsub("|Hchannel:(.-)|h%[(.-)%]|h", function(link, name)
        name = name:gsub("^%d+%.%s*", ""):gsub("%s+%-%s+.*$", "")
        return "|Hchannel:" .. link .. "|h[" .. name .. "]|h"
    end)
    msg = msg:gsub("|H(B?N?player[^|]*)|h%[(.-)%]|h", "|H%1|h%2|h")
    return msg
end

local function HookMessages(chat)
    if chat.faugusFormatted or chat == COMBATLOG then return end
    chat.faugusFormatted = true
    local addMessage = chat.AddMessage
    chat.AddMessage = function(self, msg, ...)
        return addMessage(self, FormatMessage(msg), ...)
    end
end

local function PlaceScrollButton(chat)
    local button, border = chat.ScrollToBottomButton, chat.faugusBorder
    local background = _G[chat:GetName() .. "Background"]
    local backgroundBottom = background and background:GetBottom()
    if not (button and backgroundBottom and border and border:GetTop() and chat:GetTop()) then return end
    local gap = border:GetTop() - chat:GetTop()
    button:ClearAllPoints()
    button:SetPoint("BOTTOMRIGHT", background, "BOTTOMRIGHT", -2.5, border:GetBottom() + gap - backgroundBottom)
end

function SetupChat(chat)
    HideForever(_G[chat:GetName() .. "ButtonFrame"])
    HookMessages(chat)
    ns.HideScrollArrows(chat.ScrollBar)
    local done = UpdateChatSkin(chat)
    PlaceScrollButton(chat)
    done = UpdateTabSkin(chat) and done
    PlaceTabs(chat)
    done = UpdateEditBoxSkin(chat) and done
    FixClamp(chat)
    UpdateTabAlpha(chat, true)
    chat.faugusSetup = done
end

local overflowDone
local combatLogBars = { "CombatLogQuickButtonFrame_Custom", "CombatLogQuickButtonFrame" }

local function SetupAll()
    for _, name in ipairs(buttons) do
        HideForever(_G[name])
    end
    for _, name in ipairs(CHAT_FRAMES) do
        local chat = _G[name]
        if chat and not chat.faugusSetup then SetupChat(chat) end
    end
    overflowDone = overflowDone or UpdateOverflowButton()
    for _, name in ipairs(combatLogBars) do
        local frame = _G[name]
        if frame and not frame.faugusStripped then
            frame.faugusStripped = true
            HideRegionTextures(frame, {})
        end
    end
end

local function ForEachChat(func)
    for _, name in ipairs(CHAT_FRAMES) do
        local chat = _G[name]
        if chat and chat.faugusBorder then func(chat) end
    end
end

local function OnDockChanged(chat)
    local tab = _G[chat:GetName() .. "Tab"]
    if tab and tab.faugusRect then AnchorTabRect(tab, chat) end
    PlaceTabs(chat)
    UpdateTabAlpha(chat)
end

ns.Module("Chat", "Chat", function()
    for i = 1, NUM_CHAT_WINDOWS do
        local chat = _G["ChatFrame" .. i]
        if chat then HookClamp(chat) end
    end
    hooksecurefunc("FCF_OpenTemporaryWindow", function()
        if ready then SetupAll() end
    end)
    hooksecurefunc("FCFDock_SelectWindow", function()
        if ready then ForEachChat(UpdateTabAlpha) end
    end)
    hooksecurefunc("FCF_DockFrame", function(chat) if ready then OnDockChanged(chat) end end)
    hooksecurefunc("FCF_UnDockFrame", function(chat) if ready then OnDockChanged(chat) end end)

    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_LOGIN")
    f:RegisterEvent("UPDATE_CHAT_WINDOWS")
    f:SetScript("OnEvent", function()
        ready = true
        SetupAll()
        C_Timer.After(1, function()
            SetupAll()
            ForEachChat(function(chat)
                OnDockChanged(chat)
                FixClamp(chat)
            end)
        end)
    end)
end)
