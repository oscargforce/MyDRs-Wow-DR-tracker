local addonName, addon = ...
local C_Timer = C_Timer
local ProfileManager = addon.ProfileManager

local function getSortedProfileNames()
    if ProfileManager and ProfileManager.getSortedProfileNames then
        return ProfileManager.getSortedProfileNames()
    end

    return {}
end

local function setActiveProfile(profileName)
    if ProfileManager and ProfileManager.setActiveProfile then
        ProfileManager.setActiveProfile(profileName)
    end
end

local function createProfile(profileName)
    if ProfileManager and ProfileManager.createProfile then
        return ProfileManager.createProfile(profileName)
    end

    return false, "Profile manager is unavailable."
end

local function deleteProfile(profileName)
    if ProfileManager and ProfileManager.deleteProfile then
        return ProfileManager.deleteProfile(profileName)
    end

    return false, "Profile manager is unavailable."
end

local function setDefaultConfig()
    if ProfileManager and ProfileManager.setDefaultConfig then
        ProfileManager.setDefaultConfig()
    else
        OscarDrTrackerDB = OscarDrTrackerDB or {}
    end
end

local function UpdateConfig()
    local iconSize = OscarDrTrackerDB.iconSize
    local isReversed = OscarDrTrackerDB.enableCooldownReverse
    local fontSize = OscarDrTrackerDB.fontSize
    local cooldownAlpha = OscarDrTrackerDB.cooldownSwipeAlpha

    for i = 1, 7 do
        local drFrame = _G["OscarDrTracker_DR"..i]
        if drFrame then
            drFrame:SetSize(iconSize, iconSize)
            drFrame.cooldown:SetReverse(isReversed)
            drFrame.cooldown:SetSwipeColor(0, 0, 0, cooldownAlpha)
            drFrame.drStateText:SetFont(drFrame.drStateText:GetFont(), fontSize, "OUTLINE")
        end
    end

    if addon.frame then
        local position = OscarDrTrackerDB.containerPosition
        if position and position.point and position.relativePoint then
            addon.frame:ClearAllPoints()
            addon.frame:SetPoint(position.point, UIParent, position.relativePoint, position.x or 0, position.y or 0)
        end

        if addon.frame.SortIcons then
            addon.frame:SortIcons()
        end
    end
end

local catergoryID

local function createOptionsMenu()
    local panel = CreateFrame("Frame")
    panel.name = "Oscar DR Tracker"
    local refreshOptionsFromActiveProfile

    catergoryID = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
    Settings.RegisterAddOnCategory(catergoryID)

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Oscar DR Tracker Options")

    local activeProfileLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    activeProfileLabel:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    activeProfileLabel:SetText("Active Profile: " .. (OscarDrTrackerDB._activeProfile or "Unknown"))

    local profileSelectorLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    profileSelectorLabel:SetPoint("TOPLEFT", activeProfileLabel, "BOTTOMLEFT", 0, -16)
    profileSelectorLabel:SetText("Profile")

    local profileSelectorDropdown = CreateFrame("Frame", "OscarDRTrackerProfileSelector", panel, "UIDropDownMenuTemplate")
    profileSelectorDropdown:SetPoint("TOPLEFT", profileSelectorLabel, "BOTTOMLEFT", -16, -4)
    UIDropDownMenu_SetWidth(profileSelectorDropdown, 220)
    UIDropDownMenu_SetText(profileSelectorDropdown, OscarDrTrackerDB._activeProfile or "Unknown")

    local newProfileLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    newProfileLabel:SetPoint("TOPLEFT", profileSelectorDropdown, "BOTTOMLEFT", 16, -14)
    newProfileLabel:SetText("Create New Profile")

    local newProfileInputBox = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    newProfileInputBox:SetSize(180, 20)
    newProfileInputBox:SetPoint("TOPLEFT", newProfileLabel, "BOTTOMLEFT", 0, -6)
    newProfileInputBox:SetAutoFocus(false)
    newProfileInputBox:SetMaxLetters(32)

    local createProfileButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    createProfileButton:SetSize(46, 20)
    createProfileButton:SetPoint("LEFT", newProfileInputBox, "RIGHT", 8, 0)
    createProfileButton:SetText("OK")

    local deleteProfileButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    deleteProfileButton:SetSize(234, 20)
    deleteProfileButton:SetPoint("TOPLEFT", newProfileInputBox, "BOTTOMLEFT", 0, -8)
    deleteProfileButton:SetText("Delete Active Profile")

    local profileActionStatus = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    profileActionStatus:SetPoint("TOPLEFT", deleteProfileButton, "BOTTOMLEFT", 0, -6)
    profileActionStatus:SetText(" ")

    local function showProfileStatus(message)
        profileActionStatus:SetText(message or "")
    end

    createProfileButton:SetScript("OnClick", function()
        local profileName = newProfileInputBox:GetText() or ""
        local success, err = createProfile(profileName)
        if success then
            newProfileInputBox:SetText("")
            refreshOptionsFromActiveProfile()
            showProfileStatus("Created and switched to profile: " .. (OscarDrTrackerDB._activeProfile or profileName))
        else
            showProfileStatus(err or "Failed to create profile.")
        end
    end)

    newProfileInputBox:SetScript("OnEnterPressed", function()
        createProfileButton:Click()
    end)

    if not StaticPopupDialogs["OSCARDRTRACKER_DELETE_PROFILE"] then
        StaticPopupDialogs["OSCARDRTRACKER_DELETE_PROFILE"] = {
            text = "Delete profile \"%s\"?",
            button1 = ACCEPT,
            button2 = CANCEL,
            OnAccept = function(_, data)
                if not data then
                    return
                end

                local success, err = deleteProfile(data.profileName)
                if success then
                    refreshOptionsFromActiveProfile()
                    showProfileStatus("Deleted profile: " .. data.profileName)
                else
                    showProfileStatus(err or "Failed to delete profile.")
                end
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
    end

    deleteProfileButton:SetScript("OnClick", function()
        local activeProfile = OscarDrTrackerDB and OscarDrTrackerDB._activeProfile
        if not activeProfile then
            showProfileStatus("No active profile selected.")
            return
        end

        StaticPopup_Show("OSCARDRTRACKER_DELETE_PROFILE", activeProfile, nil, {
            profileName = activeProfile,
        })
    end)

    ------------------------------------------------------------------
    -- Test Mode
    ------------------------------------------------------------------

    local testModeLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    testModeLabel:SetPoint("TOPLEFT", profileActionStatus, "BOTTOMLEFT", 0, -16)
    testModeLabel:SetText("Enable Test Mode")

    local enableTestModeCheckbox = CreateFrame("CheckButton", "OscarDRTrackerEnableTestMode", panel, "UICheckButtonTemplate")
    enableTestModeCheckbox:SetPoint("TOPLEFT", testModeLabel, "BOTTOMLEFT", 0, -2)
    enableTestModeCheckbox:SetChecked(OscarDrTrackerDB.enableTestMode)

    enableTestModeCheckbox:SetScript("OnClick", function(self)
        OscarDrTrackerDB.enableTestMode = self:GetChecked()
        addon.applyTestMode(addon.frame)
    end)

    enableTestModeCheckbox:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(
            "Allows you to drag and reposition the frame while\n" ..
            "providing a visual representation of your current\n" ..
            "configuration settings."
        )
        GameTooltip:Show()
    end)

    enableTestModeCheckbox:SetScript("OnLeave", GameTooltip_Hide)

    ------------------------------------------------------------------
    -- Reverse Cooldown Shading
    ------------------------------------------------------------------

    local shadingLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    shadingLabel:SetPoint("TOPLEFT", enableTestModeCheckbox, "BOTTOMLEFT", 0, -30)
    shadingLabel:SetText("Reversed Cooldown Shading")

    local shadingCheckbox = CreateFrame("CheckButton", "OscarDRTrackerShading", panel, "UICheckButtonTemplate")
    shadingCheckbox:SetPoint("TOPLEFT", shadingLabel, "BOTTOMLEFT", 0, -2)
    shadingCheckbox:SetChecked(OscarDrTrackerDB.enableCooldownReverse)

    shadingCheckbox:SetScript("OnClick", function(self)
        OscarDrTrackerDB.enableCooldownReverse = self:GetChecked()
        UpdateConfig()
    end)

    shadingCheckbox:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(
            "Sets the direction of the gcd cooldown\n" ..
            "displayed on the icons."
        )
        GameTooltip:Show()
    end)

    shadingCheckbox:SetScript("OnLeave", GameTooltip_Hide)

    ------------------------------------------------------------------
    -- Icon Growth Direction
    ------------------------------------------------------------------

    local growthDirectionLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    growthDirectionLabel:SetPoint("TOPLEFT", shadingCheckbox, "BOTTOMLEFT", 0, -30)
    growthDirectionLabel:SetText("Grow Icons From Left")

    local growthDirectionCheckbox = CreateFrame("CheckButton", "OscarDRTrackerGrowIconsFromLeft", panel, "UICheckButtonTemplate")
    growthDirectionCheckbox:SetPoint("TOPLEFT", growthDirectionLabel, "BOTTOMLEFT", 0, -2)
    growthDirectionCheckbox:SetChecked(OscarDrTrackerDB.growIconsFromLeft)

    growthDirectionCheckbox:SetScript("OnClick", function(self)
        OscarDrTrackerDB.growIconsFromLeft = self:GetChecked()
        if addon.frame and addon.frame.SortIcons then
            addon.frame:SortIcons()
        end
    end)

    growthDirectionCheckbox:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(
            "If enabled, active icons are anchored on the right\n" ..
            "and new icons grow toward the left."
        )
        GameTooltip:Show()
    end)

    growthDirectionCheckbox:SetScript("OnLeave", GameTooltip_Hide)

    local sliderColumnLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    sliderColumnLabel:SetPoint("TOPLEFT", activeProfileLabel, "TOPLEFT", 340, 0)
    sliderColumnLabel:SetText("Display")

    local sliderColumnAnchor = CreateFrame("Frame", nil, panel)
    sliderColumnAnchor:SetSize(1, 1)
    sliderColumnAnchor:SetPoint("TOPLEFT", sliderColumnLabel, "BOTTOMLEFT", 0, -22)

    ------------------------------------------------------------------
    -- Icon Size Slider
    ------------------------------------------------------------------

    local iconSizeSlider = CreateFrame("Slider", "OscarDRTrackerIconSizeSlider", panel, "OptionsSliderTemplate")
    local iconSizeInputBox = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")

    iconSizeSlider:SetWidth(200)
    iconSizeSlider:SetMinMaxValues(30, 100)
    iconSizeSlider:SetValueStep(1)
    iconSizeSlider:SetPoint("TOPLEFT", sliderColumnAnchor, "TOPLEFT", 0, 0)
    iconSizeSlider:SetValue(OscarDrTrackerDB.iconSize)

    OscarDRTrackerIconSizeSliderText:SetText("Icon Size: "..OscarDrTrackerDB.iconSize)

    iconSizeSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value)

        OscarDrTrackerDB.iconSize = value
        UpdateConfig()

        OscarDRTrackerIconSizeSliderText:SetText("Icon Size: "..value)
        iconSizeInputBox:SetText(value)
    end)

    iconSizeInputBox:SetSize(40,20)
    iconSizeInputBox:SetPoint("CENTER", iconSizeSlider, "CENTER", 0, -20)
    iconSizeInputBox:SetAutoFocus(false)
    iconSizeInputBox:SetNumeric(true)

    iconSizeInputBox:SetScript("OnEnterPressed", function(self)

        local value = tonumber(self:GetText())
        local minValue,maxValue = iconSizeSlider:GetMinMaxValues()

        if value then
            value = math.max(minValue, math.min(value, maxValue))
            iconSizeSlider:SetValue(value)
            self:SetText(value)
        else
            self:SetText(math.floor(iconSizeSlider:GetValue()))
        end

        self:ClearFocus()
    end)

    ------------------------------------------------------------------
    -- Icon Padding Slider
    ------------------------------------------------------------------

    local iconPaddingSlider = CreateFrame("Slider", "OscarDRTrackerIconPaddingSlider", panel, "OptionsSliderTemplate")
    local iconPaddingInputBox = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")

    iconPaddingSlider:SetWidth(200)
    iconPaddingSlider:SetMinMaxValues(0,20)
    iconPaddingSlider:SetValueStep(1)
    iconPaddingSlider:SetPoint("TOPLEFT", iconSizeSlider, "BOTTOMLEFT", 0, -40)
    iconPaddingSlider:SetValue(OscarDrTrackerDB.iconPadding)

    OscarDRTrackerIconPaddingSliderText:SetText("Icon Padding: "..OscarDrTrackerDB.iconPadding)

    iconPaddingSlider:SetScript("OnValueChanged", function(self,value)

        value = math.floor(value)

        OscarDrTrackerDB.iconPadding = value
        UpdateConfig()

        OscarDRTrackerIconPaddingSliderText:SetText("Icon Padding: "..value)
        iconPaddingInputBox:SetText(value)

    end)

    iconPaddingInputBox:SetSize(40,20)
    iconPaddingInputBox:SetPoint("CENTER", iconPaddingSlider, "CENTER", 0, -20)
    iconPaddingInputBox:SetNumeric(true)
    iconPaddingInputBox:SetAutoFocus(false)

    iconPaddingInputBox:SetScript("OnEnterPressed", function(self)

        local value = tonumber(self:GetText())
        local minValue,maxValue = iconPaddingSlider:GetMinMaxValues()

        if value then
            value = math.max(minValue, math.min(value, maxValue))
            iconPaddingSlider:SetValue(value)
            self:SetText(value)
        else
            self:SetText(math.floor(iconPaddingSlider:GetValue()))
        end

        self:ClearFocus()

    end)

    ------------------------------------------------------------------
    -- Font Size Slider
    ------------------------------------------------------------------

    local fontSizeSlider = CreateFrame("Slider", "OscarDRTrackerFontSizeSlider", panel, "OptionsSliderTemplate")
    local fontSizeInputBox = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")

    fontSizeSlider:SetWidth(200)
    fontSizeSlider:SetMinMaxValues(1,32)
    fontSizeSlider:SetValueStep(1)
    fontSizeSlider:SetPoint("TOPLEFT", iconPaddingSlider, "BOTTOMLEFT", 0, -40)
    fontSizeSlider:SetValue(OscarDrTrackerDB.fontSize)

    OscarDRTrackerFontSizeSliderText:SetText("Font Size: "..OscarDrTrackerDB.fontSize)

    fontSizeSlider:SetScript("OnValueChanged", function(self,value)

        value = math.floor(value)

        OscarDrTrackerDB.fontSize = value
        UpdateConfig()

        OscarDRTrackerFontSizeSliderText:SetText("Font Size: "..value)
        fontSizeInputBox:SetText(value)

    end)

    fontSizeInputBox:SetSize(40,20)
    fontSizeInputBox:SetPoint("CENTER", fontSizeSlider, "CENTER", 0, -20)
    fontSizeInputBox:SetNumeric(true)
    fontSizeInputBox:SetAutoFocus(false)

    fontSizeInputBox:SetScript("OnEnterPressed", function(self)

        local value = tonumber(self:GetText())
        local minValue,maxValue = fontSizeSlider:GetMinMaxValues()

        if value then
            value = math.max(minValue, math.min(value, maxValue))
            fontSizeSlider:SetValue(value)
            self:SetText(value)
        else
            self:SetText(math.floor(fontSizeSlider:GetValue()))
        end

        self:ClearFocus()

    end)

    ------------------------------------------------------------------
    -- Alpha Slider
    ------------------------------------------------------------------

    local alphaSlider = CreateFrame("Slider", "OscarDRTrackerAlphaSlider", panel, "OptionsSliderTemplate")
    local alphaInputBox = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")

    alphaSlider:SetWidth(200)
    alphaSlider:SetMinMaxValues(0, 1)
    alphaSlider:SetValueStep(0.1)
    alphaSlider:SetPoint("TOPLEFT", fontSizeSlider, "BOTTOMLEFT", 0, -40)
    alphaSlider:SetValue(OscarDrTrackerDB.cooldownSwipeAlpha)

    OscarDRTrackerAlphaSliderText:SetText("Alpha: "..OscarDrTrackerDB.cooldownSwipeAlpha)

    alphaSlider:SetScript("OnValueChanged", function(self,value)

        value = math.floor(value * 100) / 100

        OscarDrTrackerDB.cooldownSwipeAlpha = value
        UpdateConfig()

        OscarDRTrackerAlphaSliderText:SetText("Alpha: "..value)
        alphaInputBox:SetText(value)

    end)

    alphaInputBox:SetSize(40,20)
    alphaInputBox:SetPoint("CENTER", alphaSlider, "CENTER", 0, -20)
   -- alphaInputBox:SetNumeric(true)
    alphaInputBox:SetAutoFocus(false)

    alphaInputBox:SetScript("OnEnterPressed", function(self)

        local value = tonumber(self:GetText())
        local minValue,maxValue = alphaSlider:GetMinMaxValues()

        if value then
            value = math.max(minValue, math.min(value, maxValue))
            alphaSlider:SetValue(value)
            self:SetText(value)
        else
            self:SetText(math.floor(alphaSlider:GetValue() * 100) / 100)
        end

        self:ClearFocus()

    end)

    refreshOptionsFromActiveProfile = function()
        local activeProfile = OscarDrTrackerDB._activeProfile or "Unknown"

        activeProfileLabel:SetText("Active Profile: " .. activeProfile)
        UIDropDownMenu_SetText(profileSelectorDropdown, activeProfile)

        enableTestModeCheckbox:SetChecked(OscarDrTrackerDB.enableTestMode)
        shadingCheckbox:SetChecked(OscarDrTrackerDB.enableCooldownReverse)
        growthDirectionCheckbox:SetChecked(OscarDrTrackerDB.growIconsFromLeft)

        iconSizeSlider:SetValue(OscarDrTrackerDB.iconSize)
        iconSizeInputBox:SetText(OscarDrTrackerDB.iconSize)
        OscarDRTrackerIconSizeSliderText:SetText("Icon Size: "..OscarDrTrackerDB.iconSize)

        iconPaddingSlider:SetValue(OscarDrTrackerDB.iconPadding)
        iconPaddingInputBox:SetText(OscarDrTrackerDB.iconPadding)
        OscarDRTrackerIconPaddingSliderText:SetText("Icon Padding: "..OscarDrTrackerDB.iconPadding)

        fontSizeSlider:SetValue(OscarDrTrackerDB.fontSize)
        fontSizeInputBox:SetText(OscarDrTrackerDB.fontSize)
        OscarDRTrackerFontSizeSliderText:SetText("Font Size: "..OscarDrTrackerDB.fontSize)

        alphaSlider:SetValue(OscarDrTrackerDB.cooldownSwipeAlpha)
        alphaInputBox:SetText(OscarDrTrackerDB.cooldownSwipeAlpha)
        OscarDRTrackerAlphaSliderText:SetText("Alpha: "..OscarDrTrackerDB.cooldownSwipeAlpha)

        UpdateConfig()
        addon.applyTestMode(addon.frame)
    end

    UIDropDownMenu_Initialize(profileSelectorDropdown, function(_, level)
        if level ~= 1 then
            return
        end

        local profileNames = getSortedProfileNames()
        for _, profileName in ipairs(profileNames) do
            local selectedProfileName = profileName
            local info = UIDropDownMenu_CreateInfo()
            info.text = selectedProfileName
            info.checked = (selectedProfileName == OscarDrTrackerDB._activeProfile)
            info.func = function()
                setActiveProfile(selectedProfileName)
                refreshOptionsFromActiveProfile()
            end

            UIDropDownMenu_AddButton(info, level)
        end
    end)

    refreshOptionsFromActiveProfile()

end


local optionsInitFrame = CreateFrame("Frame")
optionsInitFrame:RegisterEvent("ADDON_LOADED")
optionsInitFrame:RegisterEvent("PLAYER_LOGIN")

local isOptionsAddonLoaded = false
local isPlayerLoggedIn = false
local isOptionsInitialized = false

local function tryInitializeOptions(frame)
    if isOptionsInitialized or not isOptionsAddonLoaded or not isPlayerLoggedIn then
        return
    end

    setDefaultConfig()
    createOptionsMenu()
    isOptionsInitialized = true
    frame:UnregisterEvent("ADDON_LOADED")
    frame:UnregisterEvent("PLAYER_LOGIN")
end

optionsInitFrame:SetScript("OnEvent", function(self, event, addonName)
    if event == "ADDON_LOADED" and addonName == "OscarDrTracker" then
        isOptionsAddonLoaded = true
        tryInitializeOptions(self)
    elseif event == "PLAYER_LOGIN" then
        isPlayerLoggedIn = true
        tryInitializeOptions(self)
    end
end)

SLASH_OSCARDR1 = "/odr"
SlashCmdList["OSCARDR"] = function()
    if catergoryID and catergoryID.ID then
        Settings.OpenToCategory(catergoryID.ID)
    end
end


function addon.createArrowButton(parent, direction, x, y)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(24, 24)
    button:SetFrameLevel("10")

    if direction == "UP" then
        button:SetPoint("CENTER", parent, "RIGHT", x, y) 
        button:SetText("^")
        button:SetNormalFontObject(GameFontNormalLarge)
    elseif direction == "DOWN" then
        button:SetPoint("CENTER", parent, "RIGHT", x, y)
        button:SetText("v")
    elseif direction == "LEFT" then
        button:SetPoint("BOTTOM", parent, "BOTTOM", x, y)
        button:SetText("<")
    elseif direction == "RIGHT" then
        button:SetPoint("BOTTOM", parent, "BOTTOM", x, y)
        button:SetText(">")
    end

    button:SetScript("OnClick", function()
        local point, _, relPoint, xOffset, yOffset = parent:GetPoint()

        -- Move the frame by 1 pixel in the specified direction
        if direction == "UP" then
            yOffset = yOffset + 1
        elseif direction == "DOWN" then
            yOffset = yOffset - 1
        elseif direction == "LEFT" then
            xOffset = xOffset - 1
        elseif direction == "RIGHT" then
            xOffset = xOffset + 1
        end

        parent:ClearAllPoints()
        parent:SetPoint(point, UIParent, relPoint, xOffset, yOffset)

        -- Save the updated position to your configuration
        OscarDrTrackerDB.containerPosition = { point = point, relativePoint = relPoint, x = xOffset, y = yOffset }
    end)

    return button
end

local ticker

function addon.playTestAnimation()
    if not addon.frame or not addon.frame.PlayTestMode then
        return
    end

    local interval = 11

    if ticker then
        ticker:Cancel()
    end

    ticker = C_Timer.NewTicker(interval, function()
        if not OscarDrTrackerDB.enableTestMode then
            ticker:Cancel()
            ticker = nil
            return
        end

        if not addon.frame or not addon.frame.PlayTestMode then
            ticker:Cancel()
            ticker = nil
            return
        end

        addon.frame:PlayTestMode()
    end)

    -- Run once immediately (replicates isFirstTimePlaying)
    addon.frame:PlayTestMode()
end

function addon.applyTestMode(self)
    if not self then
        return
    end

    local arrowsReady = self.upArrow and self.downArrow and self.leftArrow and self.rightArrow

    if OscarDrTrackerDB.enableTestMode then
        self:SetMovable(true)
        self:EnableMouse(true)
        if self.SetBackdrop then
            self:SetBackdrop({
                bgFile = nil,
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                edgeSize = 12,
            })
            self:SetBackdropBorderColor(1, 0, 0, 1)
        end
        if arrowsReady then
            self.upArrow:Show()
            self.downArrow:Show()
            self.leftArrow:Show()
            self.rightArrow:Show()
        end
        addon.playTestAnimation()
    else 
        if ticker then
            ticker:Cancel()
            ticker = nil
        end

        self:SetMovable(false)
        self:EnableMouse(false)
        self:SetBackdrop(nil)
        if arrowsReady then
            self.upArrow:Hide()
            self.downArrow:Hide()
            self.leftArrow:Hide()
            self.rightArrow:Hide()
        end
        for i = 1, 7 do
            local frame = _G["OscarDrTracker_DR" .. i]
            if frame then
                frame:Hide()
            end
        end
    end
end

