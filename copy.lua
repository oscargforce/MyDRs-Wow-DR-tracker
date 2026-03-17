local addonName, addon = ...
local createImmuneAlertFrame = addon.CreateImmuneAlertFrame
local immuneAlertResetVisuals = addon.ResetImmuneAlertVisuals
local ProfileManager = addon.ProfileManager
local C_LossOfControl = _G.C_LossOfControl
local pcall = pcall
local GetTime = GetTime

--[[
   TODOLIST
    - Add toggle for immune alert glow
    - Add select which drs to track
    - (Nice to have) add option to set dr textures
    - (Nice to have) add new textures for the arrow buttons.
    
-- /dump pcall(_G.C_LossOfControl.GetActiveLossOfControlDataByUnit, "player", 2)
]]

MyDRs = LibStub("AceAddon-3.0"):NewAddon("MyDRs", "AceEvent-3.0", "AceConsole-3.0")

local DEFAULT_CONFIG = {
    profile = {
        enableTestMode = false, 
        containerPosition = { point = "CENTER", relativePoint = "CENTER", x = 0, y = 0 },
        iconPadding = 4, 
        iconSize = 50, 
        growIconsFromLeft = false, 
        enableCooldownReverse = true, 
        showCountdownText = true, 
        fontSize = 16, 
        cooldownSwipeAlpha = 1, 
    },
}

local DR_WINDOW_DURATION = 16
addon.DR_WINDOW_DURATION = DR_WINDOW_DURATION
local drCategories = { "stun", "disorient", "incapacitate", "root", "silence", "knockback", "disarm" }
addon.drCategories = drCategories
local drIconTextures = {
    stun = "Interface\\Icons\\Ability_Rogue_KidneyShot",
    disorient =  "Interface\\Icons\\Spell_Shadow_Possession",
    incapacitate = "Interface\\Icons\\Spell_Nature_Polymorph",
    root = "Interface\\Icons\\Spell_Frost_FrostNova",
    silence = "Interface\\Icons\\Spell_Shadow_SoulLeech_3",
    knockback = "Interface\\Icons\\Spell_Nature_CallStorm",
    disarm = "Interface\\Icons\\Ability_Warrior_Disarm",
}
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
}

local function createDrFrame(myDRs)
    local containerFrame = CreateFrame("Frame", "MyDRsContainer", UIParent, "BackdropTemplate")
    containerFrame:SetClampedToScreen(true)
    containerFrame:SetFrameStrata("HIGH")
    containerFrame:SetSize(410, 150)
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

    return containerFrame
end

local function createIconFrames(parentFrame, MyDRs)
    local db = MyDRs.db.profile
    local iconSize = db.iconSize
    local padding = db.iconPadding
    local isReversed = db.enableCooldownReverse
    local fontSize = db.fontSize
    local cooldownAlpha = db.cooldownSwipeAlpha

    parentFrame.drFramesByCategory = {}

    for i = 1, #drCategories do
        local category = drCategories[i]
        local drFrame = CreateFrame("Frame", "MyDRsIconTracker"..i, parentFrame)
        drFrame:SetSize(iconSize, iconSize)
        drFrame:SetPoint("LEFT", (iconSize + padding) * (i - 1), 0)

        local icon = drFrame:CreateTexture(nil, "BACKGROUND")
        icon:SetAllPoints()
        icon:SetTexture(drIconTextures[category])

        local cooldown = CreateFrame("Cooldown", nil, drFrame, "CooldownFrameTemplate")
        cooldown:SetAllPoints()
        cooldown:SetReverse(isReversed)
        cooldown:SetSwipeColor(0, 0, 0, cooldownAlpha)

        local immuneAlert = createImmuneAlertFrame(drFrame)

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
        drStateText:SetFont(drStateText:GetFont(), fontSize, "OUTLINE") 
        drStateText:SetText("100%") 

        drFrame.icon = icon
        drFrame.cooldown = cooldown
        drFrame.immuneAlert = immuneAlert
        drFrame.drStateText = drStateText
        drFrame.category = category
        drFrame.sortIndex = i
        parentFrame.drFramesByCategory[category] = drFrame
        
    end
end

function MyDRs:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("MyDRsDB", DEFAULT_CONFIG, true)
    self.drStateByCategory = {}
    self.drFrame = createDrFrame(self)
    createIconFrames(self.drFrame, self)
    -- remove self.arrow later
    self.upArrow = self:createArrowButton("UP", 0, 15)
    self.downArrow = self:createArrowButton("DOWN", 0, -15)
    self.leftArrow = self:createArrowButton("LEFT", -15, 0)
    self.rightArrow = self:createArrowButton("RIGHT", 15, 0)

    self.db.RegisterCallback(self, "OnProfileChanged", "OnProfileChanged")
    self.db.RegisterCallback(self, "OnProfileCopied", "OnProfileChanged")
    self.db.RegisterCallback(self, "OnProfileReset", "OnProfileChanged")
	self:RegisterEvent("UNIT_AURA")
	self:RegisterEvent("ZONE_CHANGED_NEW_AREA")
	self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:SetupOptions()
    self:applyTestMode()
end

function MyDRs:OnProfileChanged()
    self:UpdateConfig()
    self:applyTestMode()

    if not self.db.profile.enableTestMode then
        self:ResetAllDRStates()
    end
end

function MyDRs:UNIT_AURA(_, unit, updateInfo)
    if unit ~= "player" then
        return
    end
    self:UpdateDRs(updateInfo)
end

function MyDRs:ZONE_CHANGED_NEW_AREA()
    self:ResetAllDRStates()
end

function MyDRs:PLAYER_ENTERING_WORLD()
    self:ResetAllDRStates()
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

    local unit = "player"
    local activeDRCategories = {}
    local activeLocEntries = {}
    local spellIdsWithNonRootCategory = {}

    for i = 1, 10 do
        local success, locData = pcall(C_LossOfControl.GetActiveLossOfControlDataByUnit, unit, i)
        local drCategory = success and locData and getDrCategoryForLossOfControl(locData)
        if drCategory and locData then
            activeLocEntries[#activeLocEntries + 1] = {
                drCategory = drCategory,
                locData = locData,
            }

            local spellID = locData.spellID
            
            if spellID and drCategory ~= "root" then
                spellIdsWithNonRootCategory[spellID] = true
            end
        end
    end

    for i = 1, #activeLocEntries do
        local locEntry = activeLocEntries[i]
        local drCategory = locEntry.drCategory
        local locData = locEntry.locData
        local spellID = locData.spellID

        -- Some spells (e.g. Fear) can report a secondary ROOT LoC row with the same spellID.
        if not (drCategory == "root" and spellID and spellIdsWithNonRootCategory[spellID]) then
            local categoryState = activeDRCategories[drCategory]
            if not categoryState then
                categoryState = { isActive = true, auraIds = {}, latestStartTime = 0 }
                activeDRCategories[drCategory] = categoryState
            end

            categoryState.isActive = true

            if locData.auraInstanceID then
                categoryState.auraIds[locData.auraInstanceID] = true
            end

            if locData.startTime and locData.startTime > categoryState.latestStartTime then
                categoryState.latestStartTime = locData.startTime
            end
        end
    end

    local now = GetTime()

    for _, category in ipairs(drCategories) do
        local drState = self.drStateByCategory[category]
        if not drState then
            drState = {
                isActive = false,
                auraIds = nil,
                lastSeenStartTime = nil,
                applicationCount = 0,
                expiresAt = nil,
                stacks = 0,
                windowRefreshedOnApply = false,
            }
            self.drStateByCategory[category] = drState
        end

        local wasActive = drState.isActive
        local categoryState = activeDRCategories[category]
        local isActive = categoryState and categoryState.isActive or false
        local currentAuraIds = categoryState and categoryState.auraIds or nil
        local latestStartTime = categoryState and categoryState.latestStartTime or nil

        local previousAuraIds = drState.auraIds
        local previousStartTime = drState.lastSeenStartTime or 0
        local newApplicationDetected = false

        if isActive then
            if currentAuraIds then
                for auraInstanceID in pairs(currentAuraIds) do
                    if not previousAuraIds or not previousAuraIds[auraInstanceID] then
                        newApplicationDetected = true
                        break
                    end
                end
            end

            if not newApplicationDetected and wasActive and latestStartTime and latestStartTime > (previousStartTime + 0.05) then
                newApplicationDetected = true
            end
        end

        if newApplicationDetected then
            local applicationCount = (drState.applicationCount or 0) + 1
            if applicationCount > 2 then
                applicationCount = 2
            end

            drState.applicationCount = applicationCount

            local currentStacks = drState.stacks or 0
            if currentStacks > 0 and applicationCount > currentStacks then
                drState.stacks = applicationCount
                self:SetDRStateText(category, applicationCount)
            end

            local expiresAt = drState.expiresAt
            if expiresAt and expiresAt > now then
                -- Re-applying CC during an active DR window should immediately restart the DR timer.
                self:StartDRWindow(category, applicationCount)
                drState.windowRefreshedOnApply = true
            else
                drState.windowRefreshedOnApply = false
            end
        end

        if wasActive and not isActive then
            local applicationCount = drState.applicationCount or 0
            if drState.windowRefreshedOnApply then
                drState.windowRefreshedOnApply = false
            elseif applicationCount > 0 then
                self:StartDRWindow(category, applicationCount)
            end
        end

        drState.isActive = isActive
        drState.auraIds = isActive and currentAuraIds or nil
        drState.lastSeenStartTime = isActive and latestStartTime or nil

        if isActive then
            local currentStacks = drState.stacks or 0
            local shouldPersistDrState = currentStacks > 0
            self:SetDRFrameVisible(category, shouldPersistDrState)
        else
            local expiresAt = drState.expiresAt
            local isInDrWindow = expiresAt and expiresAt > now

            self:SetDRFrameVisible(category, isInDrWindow)

            if expiresAt and not isInDrWindow then
                self:ResetDRState(category)
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
    return self.drFrame.drFramesByCategory and self.drFrame.drFramesByCategory[category]
end

function MyDRs:SetDRStateText(category, stacks)
    local frame = self:GetDRFrame(category)
    if not frame or not frame.drStateText then
        return
    end

    frame.drStateText:SetText(getDrStateTextFromStacks(stacks, self.db.profile))
    self:SetImmuneGlow(category, stacks >= 2)
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
            windowRefreshedOnApply = false,
        }
        self.drStateByCategory[category] = drState
    end

    local now = GetTime()
    if not frame:IsShown() then
        frame.startTime = now
    end

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
        else
            frame:Hide()
            self:SortIcons()
        end
    end
end

function MyDRs:ResetDRState(category)
    local frame = self:GetDRFrame(category)
    local drState = self.drStateByCategory[category]

    if drState then
        drState.expiresAt = nil
        drState.stacks = 0
        drState.applicationCount = 0
        drState.windowRefreshedOnApply = false
        drState.auraIds = nil
        drState.lastSeenStartTime = nil
    end

    if frame then
        frame.startTime = nil
    end
    self:SetDRStateText(category, 0)
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

            frame:Hide()
        end
    end

    self:SortIcons()
end

function MyDRs:SortIcons(skipSort)
    self:SortVisibleDRIcons(drCategories, skipSort)
end

--[[
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