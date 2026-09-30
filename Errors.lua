local _, ns = ...

local HOLY, FIRE, NATURE, FROST, SHADOW = 569772, 569773, 569774, 569775, 569776
local FIZZLE_SOUNDS = { HOLY, FIRE, NATURE, FROST, SHADOW }
local CLASS_FIZZLE = {
    PALADIN = HOLY, PRIEST = HOLY, MAGE = FROST, WARLOCK = SHADOW,
    DRUID = NATURE, SHAMAN = NATURE, HUNTER = NATURE,
}
local REPLAY_WINDOW = 1.5

local function MuteFizzles()
    for _, sound in ipairs(FIZZLE_SOUNDS) do MuteSoundFile(sound) end
end

ns.Module("Errors", "Error Messages", function()
    UIErrorsFrame:UnregisterEvent("UI_ERROR_MESSAGE")
    MuteFizzles()
    local sound = CLASS_FIZZLE[select(2, UnitClass("player"))] or HOLY
    local lastReplay = 0
    local f = CreateFrame("Frame")
    f:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", "player")
    f:SetScript("OnEvent", function()
        local now = GetTime()
        if now - lastReplay < REPLAY_WINDOW then return end
        lastReplay = now
        UnmuteSoundFile(sound)
        PlaySoundFile(sound, "SFX")
        C_Timer.After(REPLAY_WINDOW, MuteFizzles)
    end)
end)
