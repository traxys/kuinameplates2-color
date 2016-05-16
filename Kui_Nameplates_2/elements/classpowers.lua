-- class powers on nameplates (combo points, shards, etc)
local addon = KuiNameplates
local ele = addon:NewElement('classpowers')
local class, power_type, power_type_tag, cpf
-- power types by class/spec
local powers = {
    DEATHKNIGHT = SPELL_POWER_RUNES,
    DRUID       = { [2] = SPELL_POWER_COMBO_POINTS },
    PALADIN     = { [3] = SPELL_POWER_HOLY_POWER },
    ROGUE       = SPELL_POWER_COMBO_POINTS,
    MAGE        = { [1] = SPELL_POWER_ARCANE_CHARGES },
    MONK        = { [3] = SPELL_POWER_CHI },
    WARLOCK     = SPELL_POWER_SOUL_SHARDS,
}
-- tags returned by the UNIT_POWER and UNIT_MAXPOWER events
-- i think i see a pattern
local power_tags = {
    [SPELL_POWER_RUNES]          = 'RUNES',
    [SPELL_POWER_COMBO_POINTS]   = 'COMBO_POINTS',
    [SPELL_POWER_HOLY_POWER]     = 'HOLY_POWER',
    [SPELL_POWER_ARCANE_CHARGES] = 'ARCANE_CHARGES',
    [SPELL_POWER_CHI]            = 'CHI',
    [SPELL_POWER_SOUL_SHARDS]    = 'SOUL_SHARDS'

}
-- TODO etc
local ICON_SIZE = 10
local ICON_TEXTURE = 'interface/addons/kui_nameplates/media/combopoint-round'
local CD_TEXTURE = 'interface/playerframe/classoverlay-runecooldown'
-- local functions #############################################################
local function PositionIcons()
    -- position icons in the powers container frame
    local pv
    local full_size = (ICON_SIZE * #cpf.icons) + (1 * (#cpf.icons - 1))

    for i,icon in ipairs(cpf.icons) do
        icon:ClearAllPoints()

        if i == 1 then
            icon:SetPoint('CENTER',-(full_size / 2),0)
        elseif i > 1 then
            icon:SetPoint('LEFT',pv,'RIGHT',1,0)
        end

        pv = icon
    end
end
local function CreateIcon()
    local icon = cpf:CreateTexture(nil,'BACKGROUND')
    icon:SetTexture(ICON_TEXTURE)
    icon:SetSize(ICON_SIZE,ICON_SIZE)

    if class == 'DEATHKNIGHT' then
        -- also create a cooldown frame for runes
        local cd = CreateFrame('Cooldown',nil,cpf,'CooldownFrameTemplate')
        cd:SetSwipeTexture(CD_TEXTURE)
        cd:SetAllPoints(icon)
        cd:SetDrawEdge(false)
        cd:SetHideCountdownNumbers(true)
        icon.cd = cd
    else
        icon.Active = function(self)
            self:SetAlpha(1)
        end
        icon.Inactive = function(self)
            self:SetAlpha(.3)
        end
    end

    return icon
end
local function CreateIcons()
    -- create icons in ClassPowers frame
    local powermax = UnitPowerMax('player',power_type)

    if cpf.icons then
        if #cpf.icons > powermax then
            -- destroy overflowing icons if powermax has decreased
            for i,icon in ipairs(cpf.icons) do
                if i > powermax then
                    icon:Hide()
                    cpf.icons[i] = nil
                end
            end
        elseif #cpf.icons < powermax then
            -- create new icons
            for i=#cpf.icons+1,powermax do
                cpf.icons[i] = CreateIcon()
            end
        end
    else
        -- create initial icons
        cpf.icons = {}
        for i=1,powermax do
            cpf.icons[i] = CreateIcon()
        end
    end

    PositionIcons()

    addon:DispatchMessage('ClassPowersIconsCreated')
end
local function PowerUpdate()
    local cur = UnitPower('player',power_type)
    for i,icon in ipairs(cpf.icons) do
        if cur > i then
            icon:Active()
        else
            icon:Inactive()
        end
    end
end
-- prototype additions #########################################################
-- messages ####################################################################
function ele.Initialised()
    ele:PowerInit()

    -- icon frame container TODO floats on the target nameplate
    cpf = CreateFrame('Frame')
    cpf:SetSize(100,100)
    cpf:SetPoint('CENTER')

    -- create icon textures
    CreateIcons()

    ele:RegisterEvent('PLAYER_SPECIALIZATION_CHANGED','PowerInit')
    ele:RegisterEvent('PLAYER_TARGET_CHANGED','TargetUpdate')

    addon.ClassPowersFrame = cpf
end
-- events ######################################################################
function ele:PLAYER_ENTERING_WORLD()
    PowerUpdate()
end
function ele:PowerInit()
    if type(powers[class]) == 'table' then
        local spec = GetSpecialization()
        power_type = powers[class][spec]
    else
        power_type = powers[class]
    end

    power_type_tag = power_tags[power_type]

    if power_type then
        if class == 'DEATHKNIGHT' then
            ele:RegisterEvent('RUNE_POWER_UPDATE','RuneUpdate')
        else
            ele:RegisterEvent('PLAYER_ENTERING_WORLD')
            ele:RegisterEvent('UNIT_MAXPOWER','PowerEvent')
            ele:RegisterEvent('UNIT_POWER','PowerEvent')
        end
    else
        ele:UnregisterEvent('UNIT_MAXPOWER')
        ele:UnregisterEvent('UNIT_POWER')
    end
end
function ele:RuneUpdate(event,rune_id)
    local startTime, duration, charged = GetRuneCooldown(rune_id)
    local cd = cpf.icons[rune_id].cd

    cd:SetCooldown(startTime, duration)
    cd:Show()
end
function ele:PowerEvent(event,f,unit,power_type_rcv)
    if unit ~= 'player' then return end
    if power_type_rcv ~= power_type_tag then return end

    if event == 'UNIT_MAXPOWER' then
        -- create/destroy icons as needed
        CreateIcons()
    end

    PowerUpdate()
end
-- register ####################################################################
function ele:Initialise()
    class = select(2,UnitClass('player'))
    if not powers[class] then return end

    self:RegisterMessage('Initialised')
end
