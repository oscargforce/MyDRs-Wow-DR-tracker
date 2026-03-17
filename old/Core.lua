local addonName, addon = ...
local createArrowButton = addon.createArrowButton
local applyTestMode = addon.applyTestMode
local createImmuneAlertFrame = addon.CreateImmuneAlertFrame
local immuneAlertResetVisuals = addon.ResetImmuneAlertVisuals
local ProfileManager = addon.ProfileManager
local C_LossOfControl = _G.C_LossOfControl
local pcall = pcall
local GetTime = GetTime

--[[
   TODOLIST
    - Why does dispelling vampiric touch trigger the fear dr icon? Maybe same issue silence from dispelling UA?
    
-- /dump pcall(_G.C_LossOfControl.GetActiveLossOfControlDataByUnit, "player", 2)
]]

local DR_WINDOW_DURATION = 16
local drCategories = { "stun", "disorient", "incapacitate", "root", "silence", "knockback", "disarm" }
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

-- These show up in LossOfControl but should not drive DR tracking.
local nonDrLossOfControlSpellIds = {
    [87204] = true,  -- Sin and Punishment (Vampiric Touch dispel horror)
    [196364] = true, -- Unstable Affliction dispel silence
    [6789] = true,   -- Death Coil / Mortal Coil
}

local function getLossOfControlType(locData)
    return locData and (locData.lockType or locData.locType)
end

local function getDrCategoryForLossOfControl(locData)
    local locType = getLossOfControlType(locData)
    if not locType then
        return nil
    end

    local drCategory = locTypeToDRCategory[locType]
    if not drCategory then
        return nil
    end

    local spellID = locData.spellID
    if spellID and nonDrLossOfControlSpellIds[spellID] then
        return nil
    end

    return drCategory
end

local function ensureProfileConfig()
    if ProfileManager and ProfileManager.setDefaultConfig then
        ProfileManager.setDefaultConfig()
    else
        OscarDrTrackerDB = OscarDrTrackerDB or {}
    end
end

local OscarDrTracker = CreateFrame("Frame", "OscarDrTracker", UIParent, "BackdropTemplate")
addon.frame = OscarDrTracker
OscarDrTracker:SetClampedToScreen(true)
OscarDrTracker:SetFrameStrata("HIGH")
OscarDrTracker:RegisterEvent("UNIT_AURA")
OscarDrTracker:RegisterEvent("ZONE_CHANGED_NEW_AREA")
OscarDrTracker:RegisterEvent("PLAYER_ENTERING_WORLD")
OscarDrTracker:RegisterEvent("PLAYER_LOGIN")
OscarDrTracker:SetScript("OnEvent", function(self, event, arg1)
    if event == "UNIT_AURA" then
        if arg1 ~= "player" then return end
        self:UpdateDRs()
    elseif event == "PLAYER_LOGIN" then
        ensureProfileConfig()
        self:Init()
        self:UnregisterEvent("PLAYER_LOGIN")
    elseif event == "ZONE_CHANGED_NEW_AREA" or event == "PLAYER_ENTERING_WORLD" then
        self:ResetAllDRStates()
    end
end)

OscarDrTracker:SetScript("OnMouseDown", function(self, button)
    if button == "LeftButton" then
        self:StartMoving()
    end
end)

OscarDrTracker:SetScript("OnMouseUp", function(self, button)
    if button == "LeftButton" then
        self:StopMovingOrSizing()

        local point, _, relPoint, xOfs, yOfs = self:GetPoint()
       
        OscarDrTrackerDB.containerPosition = { point = point, relativePoint = relPoint, x = xOfs, y = yOfs }
    end
end)

local function getDrStateTextFromStacks(stacks)
    if stacks <= 0 then
        return OscarDrTrackerDB.enableTestMode and "50%" or "100%"
    elseif stacks == 1 then
        return "50%"
    end

    return "IMM"
end

local function createDrFrames()
    local iconSize = OscarDrTrackerDB.iconSize
    local padding = OscarDrTrackerDB.iconPadding
    local isReversed = OscarDrTrackerDB.enableCooldownReverse
    local fontSize = OscarDrTrackerDB.fontSize
    local cooldownAlpha = OscarDrTrackerDB.cooldownSwipeAlpha

    OscarDrTracker.drFramesByCategory = {}

    for i = 1, #drCategories do
        local category = drCategories[i]
        local drFrame = CreateFrame("Frame", "OscarDrTracker_DR"..i, OscarDrTracker)
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
                if OscarDrTrackerDB and OscarDrTrackerDB.enableTestMode then
                    return
                end

                if OscarDrTracker.activeCCByCategory and OscarDrTracker.activeCCByCategory[callbackCategory] then
                    return
                end

                OscarDrTracker:ResetDRState(callbackCategory)
                OscarDrTracker:SetDRFrameVisible(callbackCategory, false)
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
        OscarDrTracker.drFramesByCategory[category] = drFrame
        
    end
end

function OscarDrTracker:Init()
    local position = OscarDrTrackerDB.containerPosition
    self:SetSize(410, 150)
    self:ClearAllPoints()
    self:SetPoint(position.point, UIParent, position.relativePoint, position.x, position.y)
    self.upArrow = createArrowButton(self, "UP", 0, 15)
    self.downArrow = createArrowButton(self, "DOWN", 0, -15)
    self.leftArrow = createArrowButton(self, "LEFT", -15, 0)
    self.rightArrow = createArrowButton(self, "RIGHT", 15, 0)
    createDrFrames()
    self.activeCCByCategory = {}
    self.activeAuraIdsByCategory = {}
    self.lastSeenStartTimeByCategory = {}
    self.drApplicationCountByCategory = {}
    self.drExpiresAtByCategory = {}
    self.drStacksByCategory = {}
    -- Initially hide the frame (if not in test mode)
    applyTestMode(self)
end

function OscarDrTracker:GetDRFrame(category)
    return self.drFramesByCategory and self.drFramesByCategory[category]
end

function OscarDrTracker:SetDRFrameVisible(category, isVisible)
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

function OscarDrTracker:SetImmuneGlow(category, isVisible)
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

function OscarDrTracker:SetDRStateText(category, stacks)
    local frame = self:GetDRFrame(category)
    if not frame or not frame.drStateText then
        return
    end

    frame.drStateText:SetText(getDrStateTextFromStacks(stacks))
    self:SetImmuneGlow(category, stacks >= 2)
end

function OscarDrTracker:ResetDRState(category)
    self.drExpiresAtByCategory = self.drExpiresAtByCategory or {}
    self.drStacksByCategory = self.drStacksByCategory or {}
    self.drApplicationCountByCategory = self.drApplicationCountByCategory or {}
    self.activeAuraIdsByCategory = self.activeAuraIdsByCategory or {}
    self.lastSeenStartTimeByCategory = self.lastSeenStartTimeByCategory or {}
    local frame = self:GetDRFrame(category)

    self.drExpiresAtByCategory[category] = nil
    self.drStacksByCategory[category] = 0
    self.drApplicationCountByCategory[category] = 0
    self.activeAuraIdsByCategory[category] = nil
    self.lastSeenStartTimeByCategory[category] = nil
    if frame then
        frame.startTime = nil
    end
    self:SetDRStateText(category, 0)
end

function OscarDrTracker:ResetAllDRStates()
    if OscarDrTrackerDB and OscarDrTrackerDB.enableTestMode then
        return
    end

    self.activeCCByCategory = self.activeCCByCategory or {}

    for _, category in ipairs(drCategories) do
        self.activeCCByCategory[category] = false
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

function OscarDrTracker:StartDRWindow(category, stackOverride)
    local frame = self:GetDRFrame(category)
    if not frame then
        return
    end

    self.drExpiresAtByCategory = self.drExpiresAtByCategory or {}
    self.drStacksByCategory = self.drStacksByCategory or {}
    self.drApplicationCountByCategory = self.drApplicationCountByCategory or {}

    local now = GetTime()
    if not frame:IsShown() then
        frame.startTime = now
    end

    local nextStacks = stackOverride
    if nextStacks == nil then
        local previousStacks = self.drStacksByCategory[category] or 0
        nextStacks = previousStacks + 1
    end

    if nextStacks < 1 then
        nextStacks = 1
    elseif nextStacks > 2 then
        nextStacks = 2
    end

    self.drStacksByCategory[category] = nextStacks
    self.drApplicationCountByCategory[category] = nextStacks
    self.drExpiresAtByCategory[category] = now + DR_WINDOW_DURATION
    self:SetDRStateText(category, nextStacks)

    frame:Show()
    frame.cooldown:SetCooldown(now, DR_WINDOW_DURATION)
    frame.cooldown:SetSwipeColor(0, 0, 0, OscarDrTrackerDB.cooldownSwipeAlpha)
end

function OscarDrTracker:UpdateDRs()
    if OscarDrTrackerDB and OscarDrTrackerDB.enableTestMode then
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

    self.activeCCByCategory = self.activeCCByCategory or {}
    self.activeAuraIdsByCategory = self.activeAuraIdsByCategory or {}
    self.lastSeenStartTimeByCategory = self.lastSeenStartTimeByCategory or {}
    self.drApplicationCountByCategory = self.drApplicationCountByCategory or {}
    self.drExpiresAtByCategory = self.drExpiresAtByCategory or {}
    self.drStacksByCategory = self.drStacksByCategory or {}
    local now = GetTime()

    for _, category in ipairs(drCategories) do
        local wasActive = self.activeCCByCategory[category] == true
        local categoryState = activeDRCategories[category]
        local isActive = categoryState and categoryState.isActive or false
        local currentAuraIds = categoryState and categoryState.auraIds or nil
        local latestStartTime = categoryState and categoryState.latestStartTime or nil

        local previousAuraIds = self.activeAuraIdsByCategory[category]
        local previousStartTime = self.lastSeenStartTimeByCategory[category] or 0
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
            local applicationCount = (self.drApplicationCountByCategory[category] or 0) + 1
            if applicationCount > 2 then
                applicationCount = 2
            end

            self.drApplicationCountByCategory[category] = applicationCount

            local currentStacks = self.drStacksByCategory[category] or 0
            if currentStacks > 0 and applicationCount > currentStacks then
                self.drStacksByCategory[category] = applicationCount
                self:SetDRStateText(category, applicationCount)
            end
        end

        if wasActive and not isActive then
            local applicationCount = self.drApplicationCountByCategory[category] or 0
            if applicationCount > 0 then
                self:StartDRWindow(category, applicationCount)
            end
        end

        self.activeCCByCategory[category] = isActive
        self.activeAuraIdsByCategory[category] = isActive and currentAuraIds or nil
        self.lastSeenStartTimeByCategory[category] = isActive and latestStartTime or nil

        if isActive then
            local currentStacks = self.drStacksByCategory[category] or 0
            local shouldPersistDrState = currentStacks > 0
            self:SetDRFrameVisible(category, shouldPersistDrState)
        else
            local expiresAt = self.drExpiresAtByCategory[category]
            local isInDrWindow = expiresAt and expiresAt > now

            self:SetDRFrameVisible(category, isInDrWindow)

            if expiresAt and not isInDrWindow then
                self:ResetDRState(category)
            end
        end
    end
end

function OscarDrTracker:SortIcons(skipSort)
    if addon.SortVisibleDRIcons then
        addon.SortVisibleDRIcons(self, drCategories, skipSort)
    end
end

function OscarDrTracker:PlayTestMode()
    local now = GetTime()

    for i = 1, #drCategories do
        local category = drCategories[i]
        local drFrame = self:GetDRFrame(category)
        if drFrame and drFrame.cooldown then
            drFrame:Show()
            drFrame.cooldown:SetCooldown(now, DR_WINDOW_DURATION)
            drFrame.cooldown:SetSwipeColor(0, 0, 0, OscarDrTrackerDB.cooldownSwipeAlpha)
            drFrame.startTime = now + (i * 0.001)

            if i == 1 and drFrame.immuneAlert then
                local immuneAlert = drFrame.immuneAlert

                if immuneAlert.animOut:IsPlaying() then
                    immuneAlert.animOut:Stop()
                end
                if immuneAlert.animIn:IsPlaying() then
                    immuneAlert.animIn:Stop()
                end

                immuneAlert.isActive = false
                immuneAlert.isAnimatingOut = false
                immuneAlert:SetScript("OnUpdate", nil)
                immuneAlertResetVisuals(immuneAlert)
                immuneAlert:Hide()

                self:SetDRStateText(category, 2)
            else
                self:SetDRStateText(category, 0)
            end
        end
    end

    self:SortIcons()
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