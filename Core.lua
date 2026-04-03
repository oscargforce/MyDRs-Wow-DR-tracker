local addonName, addon = ...
local createImmuneAlertFrame = addon.CreateImmuneAlertFrame
local immuneAlertResetVisuals = addon.ResetImmuneAlertVisuals
local createImmuneBorder = addon.CreateImmuneBorder
local ProfileManager = addon.ProfileManager
local C_LossOfControl = _G.C_LossOfControl
local pcall = pcall
local GetTime = GetTime
local LibStub = LibStub
local Masque = LibStub and LibStub("Masque", true)

MyDRs = LibStub("AceAddon-3.0"):NewAddon("MyDRs", "AceEvent-3.0", "AceConsole-3.0")

local drIconTextures = {
    stun = "Interface\\Icons\\Ability_Rogue_KidneyShot",
    disorient =  "Interface\\Icons\\Spell_Shadow_Possession",
    incapacitate = "Interface\\Icons\\Spell_Nature_Polymorph",
    root = "Interface\\Icons\\Spell_Nature_StrangleVines",
    silence = "Interface\\Icons\\Spell_Shadow_SoulLeech_3",
    knockback = "Interface\\Icons\\Spell_Nature_CallStorm",
    disarm = "Interface\\Icons\\Ability_Warrior_Disarm",
}

addon.drIconTextures = drIconTextures

local BASE_ICON_SIZE = 50
addon.BASE_ICON_SIZE = BASE_ICON_SIZE

local DEFAULT_CONFIG = {
    profile = {
        enableTestMode = false, 
        containerPosition = { point = "CENTER", relativePoint = "CENTER", x = 0, y = 0 },
        iconPadding = 4, 
        iconSize = 50,
        orientation = "HORIZONTAL",
        growIconsFromLeft = false, 
        growDirectionVertical = "DOWN", 
        enableCooldownReverse = true, 
        showCountdownText = true, 
        showDRStateText = true,
        enableImmuneAlertGlow = true,
        enableImmuneBorder = true,
        fontSize = 16, 
        cooldownSwipeAlpha = 1, 
        enableInArena = true,
        enableInBattleground = true,
        enableInWorld = true,
        trackDR_stun = true,
        trackDR_disorient = true,
        trackDR_incapacitate = true,
        trackDR_root = true,
        trackDR_silence = true,
        trackDR_knockback = true,
        trackDR_disarm = true,
        drTexture_stun = drIconTextures.stun,
        drTexture_disorient = drIconTextures.disorient,
        drTexture_incapacitate = drIconTextures.incapacitate,
        drTexture_root = drIconTextures.root,
        drTexture_silence = drIconTextures.silence,
        drTexture_knockback = drIconTextures.knockback,
        drTexture_disarm = drIconTextures.disarm,
    },
}

local DR_WINDOW_DURATION = 16
addon.DR_WINDOW_DURATION = DR_WINDOW_DURATION

local drCategories = { "stun", "disorient", "incapacitate", "root", "silence", "knockback", "disarm" }
addon.drCategories = drCategories


local locTypeToDRCategory = {
    STUN="incapacitate",
    STUN_MECHANIC="stun",
    FEAR="disorient",
    FEAR_MECHANIC="disorient",
    CHARM="disorient",
    CYCLONE="disorient",
    POSSESS="disorient",
    CONFUSE="incapacitate",
    ROOT="root",
    DISARM="disarm",
    SILENCE="silence",
}

-- Spell-specific overrides for cases where LoC type does not match DR category.
local spellIdToDRCategoryOverrides = {
    [31661] = "disorient", -- Dragon's Breath reports CONFUSE but shares disorient DR.
    [2094] = "disorient", -- Blind reports CONFUSE but shares disorient DR.
    [105421] = "disorient", -- Blinding Light reports CONFUSE but shares disorient DR.
    [207167] = "disorient", -- Blinding Sleet (Dks) reports CONFUSE but shares disorient DR.
    [33786] = "disorient", -- Cyclone reports STUN but shares disorient DR.
    [198909] = "disorient", -- Song of Chi-Ji reports STUN but shares disorient DR.
    [51514] = "incapacitate", -- Hex reports NONE but shares incapacitate DR.
    [277784] = "incapacitate", -- Hex (Wicker Mongrel)
    [196942] = "incapacitate", -- Hex (Voodoo Totem)
    [210873] = "incapacitate", -- Hex (Raptor)
    [211004] = "incapacitate", -- Hex (Spider)
    [211010] = "incapacitate", -- Hex (Snake)
    [211015] = "incapacitate", -- Hex (Cockroach)
    [269352] = "incapacitate", -- Hex (Skeletal Hatchling)
    [309328] = "incapacitate", -- Hex (Living Honey)
    [277778] = "incapacitate", -- Hex (Zandalari Tendonripper)
}

-- These show up in LossOfControl but should not drive DR tracking.
local nonDrLossOfControlSpellIds = {
    [87204] = true,  -- Sin and Punishment (Vampiric Touch dispel horror)
    [196364] = true, -- Unstable Affliction dispel silence
    [6789] = true,   -- Death Coil / Mortal Coil
    [100] = true,    -- Charge
    [105771] = true, -- Charge Root (LoC root aura)
    [78675] = true,  -- Solar Beam (cast)
    [81261] = true,  -- Solar Beam Silence (LoC aura)
    [358861] = true, -- Shadow priests PvP talent: Cascading Horrors
    [157997] = true, -- Ice Nova (Mage talent)
    [370970] = true, -- The Hunt's root effect from the DH ability
    [45334] = true,  -- Bear Charge
}

local function createDrFrame(myDRs)
    local containerFrame = CreateFrame("Frame", "MyDRsContainer", UIParent, "BackdropTemplate")
    containerFrame:SetClampedToScreen(false)
    containerFrame:SetFrameStrata("MEDIUM")
    containerFrame:SetSize(1, 1)
    containerFrame:ClearAllPoints()
    local db = myDRs.db.profile
    local position = db.containerPosition
    containerFrame:SetPoint(position.point, UIParent, position.relativePoint, position.x, position.y)

    containerFrame:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            self:StartMoving()
        end
    end)

    containerFrame:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            self:StopMovingOrSizing()

            local point, _, relPoint, xOfs, yOfs = self:GetPoint()

            myDRs.db.profile.containerPosition = { point = point, relativePoint = relPoint, x = xOfs, y = yOfs }
        end
    end)

    local iconsContainer = CreateFrame("Frame", "$parentIcons", containerFrame, "BackdropTemplate")
    iconsContainer:SetPoint("LEFT", containerFrame, "CENTER", 0, 0)
    iconsContainer:SetSize(BASE_ICON_SIZE, BASE_ICON_SIZE)
    iconsContainer:SetScale(db.iconSize / BASE_ICON_SIZE)
    iconsContainer:EnableMouse(false)
    iconsContainer:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" and containerFrame:IsMovable() then
            containerFrame:StartMoving()
        end
    end)
    iconsContainer:SetScript("OnMouseUp", function(_, button)
        if button ~= "LeftButton" or not containerFrame:IsMovable() then
            return
        end

        containerFrame:StopMovingOrSizing()

        local point, _, relPoint, xOfs, yOfs = containerFrame:GetPoint()
        myDRs.db.profile.containerPosition = { point = point, relativePoint = relPoint, x = xOfs, y = yOfs }
    end)

    containerFrame.iconsContainer = iconsContainer

    return containerFrame
end

local function createIconFrames(parentFrame, MyDRs)
    local db = MyDRs.db.profile
    local scale = db.iconSize / BASE_ICON_SIZE
    local padding = db.iconPadding / scale

    parentFrame.drFramesByCategory = {}
    MyDRs.drFrame.drFramesByCategory = parentFrame.drFramesByCategory

    for i = 1, #drCategories do
        local category = drCategories[i]
        local drFrame = CreateFrame("Button", "MyDRsIconTracker"..i, parentFrame)
        drFrame:SetSize(BASE_ICON_SIZE, BASE_ICON_SIZE)
        drFrame:SetPoint("LEFT", (BASE_ICON_SIZE + padding) * (i - 1), 0)
        drFrame:EnableMouse(false)

        local icon = drFrame:CreateTexture(nil, "BACKGROUND")
        icon:SetAllPoints()
        icon:SetTexture(db["drTexture_" .. category] or drIconTextures[category])

        local cooldown = CreateFrame("Cooldown", nil, drFrame, "CooldownFrameTemplate")
        cooldown:SetAllPoints()
        cooldown:SetReverse(db.enableCooldownReverse)
        cooldown:SetSwipeColor(0, 0, 0, db.cooldownSwipeAlpha)

        local immuneAlert = createImmuneAlertFrame(drFrame)
        local immuneBorder = createImmuneBorder(drFrame)
        
        local callbackCategory = category
        pcall(function()
            cooldown:HookScript("OnCooldownDone", function()
                if MyDRs.db.profile.enableTestMode then
                    return
                end

                local state = MyDRs.drStateByCategory[callbackCategory]
                if state and state.isActive then
                    return
                end

                MyDRs:ResetDRState(callbackCategory)
                MyDRs:SetDRFrameVisible(callbackCategory, false)
            end)
        end)

        local drStateText = cooldown:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        drStateText:SetPoint("BOTTOM", cooldown, "BOTTOM", 0, 2)
        drStateText:SetFont(drStateText:GetFont(), db.fontSize / scale, "OUTLINE")
        drStateText:SetText("100%")

        drFrame.icon = icon
        drFrame.cooldown = cooldown
        drFrame.immuneAlert = immuneAlert
        drFrame.immuneBorder = immuneBorder
        drFrame.drStateText = drStateText
        drFrame.category = category
        drFrame.sortIndex = i
        drFrame:Hide()
        parentFrame.drFramesByCategory[category] = drFrame

        MyDRs:RegisterMasqueButton(drFrame)
    end
end

function MyDRs:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("MyDRsDB", DEFAULT_CONFIG, true)
    self.drStateByCategory = {}
    self:InitializeMasque()
    self.drFrame = createDrFrame(self)
    createIconFrames(self.drFrame.iconsContainer, self)
    self.upArrow = self:createArrowButton("UP", -0, -15)
    self.downArrow = self:createArrowButton("DOWN", 0, -45)
    self.leftArrow = self:createArrowButton("LEFT", -15, -30)
    self.rightArrow = self:createArrowButton("RIGHT", 15, -30)

    self.db.RegisterCallback(self, "OnProfileChanged", "OnProfileChanged")
    self.db.RegisterCallback(self, "OnProfileCopied", "OnProfileChanged")
    self.db.RegisterCallback(self, "OnProfileReset", "OnProfileChanged")
	self:RegisterEvent("ZONE_CHANGED_NEW_AREA")
	self:RegisterEvent("PLAYER_ENTERING_WORLD")
	self:RegisterEvent("ARENA_PREP_OPPONENT_SPECIALIZATIONS")
    self:UpdateConfig()
    self:SetupOptions()
    self:applyTestMode()
    self:ApplyZoneState()
end

function MyDRs:OnProfileChanged()
    self:UpdateConfig()
    self:applyTestMode()
    self:ApplyZoneState()
end

function MyDRs:ZONE_CHANGED_NEW_AREA()
   self:ApplyZoneState()
end

function MyDRs:ApplyZoneState()
    self:ResetAllDRStates()
    if self:IsEnabledForCurrentZone() then
        self:RegisterEvent("UNIT_AURA")
    else
        self:UnregisterEvent("UNIT_AURA")
    end
end

function MyDRs:UNIT_AURA(_, unit, updateInfo)
    if unit ~= "player" then
        return
    end
    self:UpdateDRs(updateInfo)
end

function MyDRs:PLAYER_ENTERING_WORLD()
   self:ApplyZoneState()
end

function MyDRs:ARENA_PREP_OPPONENT_SPECIALIZATIONS()
    self:ResetAllDRStates()
end

function MyDRs:IsEnabledForCurrentZone()
    local _, instanceType = IsInInstance()
    if instanceType == "arena" then
        return self.db.profile.enableInArena
    elseif instanceType == "pvp" then
        return self.db.profile.enableInBattleground
    else
        return self.db.profile.enableInWorld
    end
end

function MyDRs:InitializeMasque()
    if not Masque then
        return
    end

    self.masqueGroup = Masque:Group("MyDRs", "DR Icons")
end

function MyDRs:RegisterMasqueButton(button)
    if not self.masqueGroup then
        return
    end

    if button.isMasqueRegistered then
        return
    end
    
    self.masqueGroup:AddButton(button, {
        Icon = button.icon,
        Cooldown = button.cooldown,
    })

    button.isMasqueRegistered = true
end

function MyDRs:RefreshMasqueSkin()
    if not self.masqueGroup then
        return
    end

    if type(self.masqueGroup.ReSkin) == "function" then
        pcall(self.masqueGroup.ReSkin, self.masqueGroup)
    end
end

local function getLossOfControlType(locData)
    return locData and (locData.lockType or locData.locType)
end

local function getDrCategoryForLossOfControl(locData)
    local locType = getLossOfControlType(locData)
    if not locType then
        return nil
    end

    local spellID = locData.spellID
    if spellID and nonDrLossOfControlSpellIds[spellID] then
        return nil
    end

    if spellID then
        local overrideCategory = spellIdToDRCategoryOverrides[spellID]
        if overrideCategory then
            return overrideCategory
        end
    end

    local drCategory = locTypeToDRCategory[locType]
    if not drCategory then
        return nil
    end

    return drCategory
end

function MyDRs:UpdateDRs(updateInfo)
    if self.db.profile.enableTestMode then
        return
    end

    local activeDRs = {}
    local locEntries = {}

    -- 1) Collect all active Loss of Control entries reported for the player.
    for i = 1, 10 do
        local success, locData = pcall(C_LossOfControl.GetActiveLossOfControlDataByUnit, "player", i)
        if success and locData then
            locEntries[#locEntries + 1] = locData
        end
    end

    -- 2) Build a spellID lookup for spells with a non-root DR category. This is used to ignore root LoC if the same spell also has a non-root LoC that should control DR.
    local spellsWithNonRoot = {}
    for _, locData in ipairs(locEntries) do
        local drCat = getDrCategoryForLossOfControl(locData)
        if drCat and drCat ~= "root" and locData.spellID then
            spellsWithNonRoot[locData.spellID] = true
        end
    end

    -- 3) Build a map of ActiveDRs -> { auraIds, startTime } for currently active CCs
    for _, locData in ipairs(locEntries) do
        local drCat = getDrCategoryForLossOfControl(locData)
        -- Ignore root entries when the same spell also produces a non-root DR category.
        -- Example: Warlock Fear can emit both root and disorient LoCs, but only disorient should count for DR.
        if drCat and not (drCat == "root" and spellsWithNonRoot[locData.spellID]) then
            local drState = activeDRs[drCat]
            if not drState then
                drState = { auraIds = {}, startTime = 0 }
                activeDRs[drCat] = drState
            end

            if locData.auraInstanceID then
                drState.auraIds[locData.auraInstanceID] = true
            end
            if locData.startTime and locData.startTime > drState.startTime then
                drState.startTime = locData.startTime
            end
        end
    end

    local now = GetTime()

    -- 4) Per-category update: skip untracked, detect new applications, update visibility
    for _, cat in ipairs(drCategories) do
        local state = self.drStateByCategory[cat]
        if not state then
            self.drStateByCategory[cat] = {
                isActive = false,
                auraIds = nil,
                lastSeenStartTime = nil,
                applicationCount = 0,
                expiresAt = nil,
                stacks = 0,
            }
            state = self.drStateByCategory[cat]
        end

        local isTracked = self.db.profile["trackDR_" .. cat]
        if not isTracked then
            -- Clear state immediately for categories the user is not tracking.
            if state.isActive or state.stacks > 0 or state.expiresAt then
                self:ResetDRState(cat)
            end
            state.isActive = false
            self:SetDRFrameVisible(cat, false)
        else
            -- 5) Determine if the current update represents a new CC application
            local active = activeDRs[cat]
            local isActive = active ~= nil
            local newApp = false

            if isActive then
                if not state.isActive then
                    newApp = true
                else
                    for auraId in pairs(active.auraIds) do
                        if not state.auraIds or not state.auraIds[auraId] then
                            newApp = true
                            break
                        end
                    end
                    if not newApp and active.startTime > (state.lastSeenStartTime or 0) + 0.05 then
                        newApp = true
                    end
                end
            end
            -- 6) On a new application, advance stacks and clear any old cooldown swipe.
            if newApp then
                local count = math.min(state.applicationCount + 1, 2)
                state.applicationCount = count
                if count > state.stacks then
                    state.stacks = count
                    self:UpdateImmuneVisuals(cat, count >= 2)
                end

                local frame = self:GetDRFrame(cat)
                if frame and frame.cooldown then
                    frame.cooldown:SetCooldown(0, 0)
                end
            end
            -- 7) When the CC ends, start the DR timer with the same DR tier the CC reached.
            if state.isActive and not isActive then
                if state.applicationCount > 0 then
                    self:StartDRWindow(cat, state.applicationCount)
                end
            end

            -- 8) Save the current active state so the next UNIT_AURA update can detect changes.
            state.isActive = isActive
            state.auraIds = isActive and active.auraIds or nil
            state.lastSeenStartTime = isActive and active.startTime or nil

            if isActive then
                -- While CC is active, keep the icon visible and hide the DR state text.
                self:SetDRFrameVisible(cat, state.stacks > 0)
                local frame = self:GetDRFrame(cat)
                if frame and frame.drStateText then
                    frame.drStateText:Hide()
                end
            else
                -- Safety clean up, remove expired drs or keep them visible during the DR window.
                local expAt = state.expiresAt
                local inDrWindow = expAt and expAt > now
                self:SetDRFrameVisible(cat, inDrWindow)
                if expAt and not inDrWindow then
                    self:ResetDRState(cat)
                end
            end
        end
    end
end

local function getDrStateTextFromStacks(stacks, db)
    if stacks <= 0 then
        return db.enableTestMode and "50%" or "100%"
    elseif stacks == 1 then
        return "50%"
    end

    return "IMM"
end

function MyDRs:GetDRFrame(category)
    return self.drFrame.iconsContainer.drFramesByCategory[category]
end

function MyDRs:SetDRStateText(category, stacks)
    local frame = self:GetDRFrame(category)
    if not frame or not frame.drStateText then
        return
    end

    frame.drStateText:SetText(getDrStateTextFromStacks(stacks, self.db.profile))
    frame.drStateText:SetShown(self.db.profile.showDRStateText)
    self:UpdateImmuneVisuals(category, stacks >= 2)
end

function MyDRs:StartDRWindow(category, stackOverride)
    local frame = self:GetDRFrame(category)
    if not frame then
        return
    end

    local drState = self.drStateByCategory[category]
    if not drState then
        drState = {
            isActive = false,
            auraIds = nil,
            lastSeenStartTime = nil,
            applicationCount = 0,
            expiresAt = nil,
            stacks = 0,
        }
        self.drStateByCategory[category] = drState
    end

    local now = GetTime()
    frame.startTime = now

    local nextStacks = stackOverride
    if nextStacks == nil then
        local previousStacks = drState.stacks or 0
        nextStacks = previousStacks + 1
    end

    if nextStacks < 1 then
        nextStacks = 1
    elseif nextStacks > 2 then
        nextStacks = 2
    end

    drState.stacks = nextStacks
    drState.applicationCount = nextStacks
    drState.expiresAt = now + DR_WINDOW_DURATION
    self:SetDRStateText(category, nextStacks)

    frame:Show()
    frame.cooldown:SetCooldown(now, DR_WINDOW_DURATION)
    frame.cooldown:SetSwipeColor(0, 0, 0, self.db.profile.cooldownSwipeAlpha)
end

function MyDRs:SetDRFrameVisible(category, isVisible)
    local frame = self:GetDRFrame(category)
    if not frame then
        return
    end

    if isVisible then
        frame.pendingHideAfterImmuneAlert = nil
        frame:Show()
        self:SortIcons()
    else
        local immuneAlert = frame.immuneAlert
        if immuneAlert and (immuneAlert.isActive or immuneAlert.animIn:IsPlaying() or immuneAlert.animOut:IsPlaying()) then
            frame.pendingHideAfterImmuneAlert = true
            self:SetImmuneGlow(category, false)
            self:SetImmuneBorder(category, false)
        else
            frame:Hide()
            self:SortIcons()
        end
    end
end

function MyDRs:SortIcons(skipSort)
    self:SortVisibleDRIcons(drCategories, skipSort)
end

function MyDRs:SetImmuneGlow(category, isVisible)
    local frame = self:GetDRFrame(category)
    if not frame or not frame.immuneAlert then
        return
    end

    local immuneAlert = frame.immuneAlert

    if isVisible then
        frame.pendingHideAfterImmuneAlert = nil
        frame:Show()

        if immuneAlert.animOut:IsPlaying() then
            immuneAlert.animOut:Stop()
        end

        if immuneAlert.isActive or immuneAlert.animIn:IsPlaying() then
            return
        end

        immuneAlert.animIn:Play()
    else
        if immuneAlert.animIn:IsPlaying() then
            immuneAlert.animIn:Stop()
        end

        if immuneAlert.animOut:IsPlaying() then
            return
        end

        if not immuneAlert.isActive then
            immuneAlert:SetScript("OnUpdate", nil)
            immuneAlert:Hide()
            return
        end

        immuneAlert.isAnimatingOut = true
        immuneAlert.animOut:Play()
    end
end

function MyDRs:SetImmuneBorder(category, isVisible)
    local frame = self:GetDRFrame(category)    
    if isVisible then
        frame:Show()
        frame.immuneBorder:Show()
    else
        frame.immuneBorder:Hide()
    end
end

function MyDRs:UpdateImmuneVisuals(category, isImmune)
    local useGlow = self.db.profile.enableImmuneAlertGlow and isImmune
    local useBorder = (not self.db.profile.enableImmuneAlertGlow) and isImmune and self.db.profile.enableImmuneBorder

    self:SetImmuneGlow(category, useGlow)
    self:SetImmuneBorder(category, useBorder)
end

function MyDRs:ResetDRState(category)
    local frame = self:GetDRFrame(category)
    local drState = self.drStateByCategory[category]

    if drState then
        drState.expiresAt = nil
        drState.stacks = 0
        drState.applicationCount = 0
        drState.auraIds = nil
        drState.lastSeenStartTime = nil
    end

    if frame then
        frame.startTime = nil
    end
    self:SetDRStateText(category, 0)
end

function MyDRs:ResetAllDRStates()
    if self.db.profile.enableTestMode then
        return
    end

    for _, category in ipairs(drCategories) do
        local drState = self.drStateByCategory[category]
        if drState then
            drState.isActive = false
        end
        self:ResetDRState(category)

        local frame = self:GetDRFrame(category)
        if frame then
            frame.pendingHideAfterImmuneAlert = nil

            local immuneAlert = frame.immuneAlert
            if immuneAlert then
                if immuneAlert.animIn:IsPlaying() then
                    immuneAlert.animIn:Stop()
                end
                if immuneAlert.animOut:IsPlaying() then
                    immuneAlert.animOut:Stop()
                end

                immuneAlert.isActive = false
                immuneAlert.isAnimatingOut = false
                immuneAlert:SetScript("OnUpdate", nil)
                immuneAlertResetVisuals(immuneAlert)
                immuneAlert:Hide()
            end

            frame.immuneBorder:Hide()
            frame:Hide()
        end
    end

    self:SortIcons()
end

function MyDRs:GetIconScale()
    return self.db.profile.iconSize / BASE_ICON_SIZE
end

function MyDRs:GetBaseIconPadding()
    local scale = self:GetIconScale()
    return scale > 0 and (self.db.profile.iconPadding / scale) or self.db.profile.iconPadding
end

function MyDRs:GetTrackedCategoryCount()
    local count = 0
    for _, category in ipairs(drCategories) do
        if self.db.profile["trackDR_" .. category] then
            count = count + 1
        end
    end
    return count
end

function MyDRs:GetIconContainer()
    return self.drFrame.iconsContainer
end

function MyDRs:UpdateIconContainerLayout(iconCount)
    local trackerFrame = self:GetIconContainer()
    
    local count = (iconCount and iconCount > 0) and iconCount or self:GetTrackedCategoryCount()
    count = math.max(count, 1)

    local padding = self:GetBaseIconPadding()
    local total = (BASE_ICON_SIZE * count) + (padding * (count - 1))

    trackerFrame:ClearAllPoints()

    if self.db.profile.orientation == "VERTICAL" then
        local anchorPoint = self.db.profile.growDirectionVertical == "UP" and "BOTTOM" or "TOP"
        trackerFrame:SetPoint(anchorPoint, self.drFrame, "CENTER", 0, 0)
        trackerFrame:SetSize(BASE_ICON_SIZE, total)
    else
        local anchorPoint = self.db.profile.growIconsFromLeft and "RIGHT" or "LEFT"
        trackerFrame:SetPoint(anchorPoint, self.drFrame, "CENTER", 0, 0)
        trackerFrame:SetSize(total, BASE_ICON_SIZE)
    end

    trackerFrame:SetScale(self:GetIconScale())
end

--[[
 Response Example from C_LossOfControl.GetActiveLossOfControlDataByUnit("player", 1):
{
  "success": true,
  "data": {
    "locType": "STUN_MECHANIC",
    "lockoutSchool": 0,
    "displayText": "Stunned",
    "auraInstanceID": 1423,
    "displayType": 2,
    "priority": 5,
    "duration": 3.0000002384186,
    "timeRemaining": 1.9980001449585,
    "startTime": 97214.8515625,
    "iconTexture": 135782,
    "spellID": 377048
  }
}

]]