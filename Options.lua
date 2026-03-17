local MyDRs = LibStub("AceAddon-3.0"):GetAddon("MyDRs")
local addonName, addon = ...
local drCategories = addon.drCategories
local DR_WINDOW_DURATION = addon.DR_WINDOW_DURATION
local immuneAlertResetVisuals = addon.ResetImmuneAlertVisuals
local C_Timer = C_Timer
local LibStub = LibStub
local InterfaceOptionsFrame_OpenToCategory = InterfaceOptionsFrame_OpenToCategory
local SlashCmdList = SlashCmdList
local Settings = Settings


function MyDRs:UpdateConfig()
    local db = self.db.profile
    local iconSize = db.iconSize
    local isReversed = db.enableCooldownReverse
    local fontSize = db.fontSize
    local cooldownAlpha = db.cooldownSwipeAlpha
    local showCountdownText = db.showCountdownText

    for i = 1, #drCategories do
        local category = drCategories[i]
        local drFrame = self:GetDRFrame(category)
        if drFrame then
            drFrame:SetSize(iconSize, iconSize)
            drFrame.cooldown:SetReverse(isReversed)
            drFrame.cooldown:SetSwipeColor(0, 0, 0, cooldownAlpha)
            drFrame.cooldown:SetHideCountdownNumbers(not showCountdownText)
            drFrame.drStateText:SetFont(drFrame.drStateText:GetFont(), fontSize, "OUTLINE")
        end
    end

    -- Hide disabled DR categories
    for i = 1, #drCategories do
        local category = drCategories[i]
        if not db["trackDR_" .. category] then
            self:SetDRFrameVisible(category, false)
        end
    end

    local position = db.containerPosition
    self.drFrame:ClearAllPoints()
    self.drFrame:SetPoint(position.point, UIParent, position.relativePoint, position.x or 0, position.y or 0)
    self:SortIcons()
    self:RefreshImmuneAlertGlow()
end

function MyDRs:SetupOptions()
    self.options = {
        type = "group",
        name = "MyDRs Options",
        -- Adds the profile tab to the options menu.
        plugins = {
			profiles = { profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db) }
		},
        childGroups = "tab",
        args = {
            general = {
                type = "group",
                name = "General Settings",
                order = 1,
                args = {
                    desc = {
                        order = 0,
                        type = "description",
                        fontSize = "medium",
                        name = "Tracks your own DRs. Use |cFFFFFF00/mydrs|r to open the options menu. Its a simple addon and wont expand.",
                    },
                    lineBreak1 = {
                        name = " ",
                        type = "description",
                        order = 0.5,
                    },
                    enableTestMode = {
                        order = 1,
                        type = "toggle",
                        name = "Enable Test Mode",
                        desc = "Toggle test mode to preview DR tracking behavior.",
                        get = function() return self.db.profile.enableTestMode end,
                        set = function(_, value)
                            self.db.profile.enableTestMode = value
                            self:applyTestMode()
                        end,
                    },
                    growIconsFromLeft = {
                        order = 2,
                        type = "toggle",
                        name = "Grow Icons From Left",
                        get = function() return self.db.profile.growIconsFromLeft end,
                        set = function(_, value)
                            self.db.profile.growIconsFromLeft = value
                            self:UpdateConfig()
                        end,
                    },
                    enableCooldownReverse = {
                        order = 3,
                        type = "toggle",
                        name = "Reverse Cooldown Swipe",
                        get = function() return self.db.profile.enableCooldownReverse end,
                        set = function(_, value)
                            self.db.profile.enableCooldownReverse = value
                            self:UpdateConfig()
                        end,
                    },
                    showCountdownText = {
                        order = 4,
                        type = "toggle",
                        name = "Show Countdown Text",
                        get = function() return self.db.profile.showCountdownText end,
                        set = function(_, value)
                            self.db.profile.showCountdownText = value
                            self:UpdateConfig()
                        end,
                    },
                    enableImmuneAlertGlow = {
                        order = 4.1,
                        type = "toggle",
                        name = "Enable Immune Glow",
                        desc = "Show or hide the immune glow animation on DR icons.",
                        get = function() return self.db.profile.enableImmuneAlertGlow end,
                        set = function(_, value)
                            self.db.profile.enableImmuneAlertGlow = value
                            self:RefreshImmuneAlertGlow()
                            self:RefreshTestAnimation(self.db.profile.enableImmuneAlertGlow)
                        end,
                    },
                    lineBreak2 = {
                        name = " ",
                        type = "description",
                        order = 4.5,
                    },
                    iconSize = {
                        order = 5,
                        type = "range",
                        name = "Icon Size",
                        min = 30,
                        max = 100,
                        step = 1,
                        get = function() return self.db.profile.iconSize end,
                        set = function(_, value)
                            self.db.profile.iconSize = value
                            self:UpdateConfig()
                        end,
                    },
                    iconPadding = {
                        order = 6,
                        type = "range",
                        name = "Icon Padding",
                        min = 0,
                        max = 20,
                        step = 1,
                        get = function() return self.db.profile.iconPadding end,
                        set = function(_, value)
                            self.db.profile.iconPadding = value
                            self:UpdateConfig()
                        end,
                    },
                    fontSize = {
                        order = 7,
                        type = "range",
                        name = "Font Size",
                        min = 8,
                        max = 32,
                        step = 1,
                        get = function() return self.db.profile.fontSize end,
                        set = function(_, value)
                            self.db.profile.fontSize = value
                            self:UpdateConfig()
                        end,
                    },
                    cooldownSwipeAlpha = {
                        order = 8,
                        type = "range",
                        name = "Cooldown Swipe Alpha",
                        min = 0,
                        max = 1,
                        step = 0.05,
                        get = function() return self.db.profile.cooldownSwipeAlpha end,
                        set = function(_, value)
                            self.db.profile.cooldownSwipeAlpha = value
                            self:UpdateConfig()
                        end,
                    },
                    lineBreak3 = {
                        name = " ",
                        type = "description",
                        order = 8.5,
                    },
                    drTrackingHeader = {
                        order = 9,
                        type = "description",
                        fontSize = "large",
                        name = "Tracked DR Categories:",
                    },
                    lineBreak4 = {
                        name = " ",
                        type = "description",
                        order = 9.1,
                    },
                    trackDR_stun = {
                        order = 9.2,
                        type = "toggle",
                        name = "Stun",
                        desc = "Cheap Shot, Kidney Shot, etc.",
                        get = function() return self.db.profile.trackDR_stun end,
                        set = function(_, value)
                            self.db.profile.trackDR_stun = value
                            self:UpdateConfig()
                            self:RefreshTestAnimation(self.db.profile.trackDR_stun)
                        end,
                    },
                    trackDR_disorient = {
                        order = 9.3,
                        type = "toggle",
                        name = "Disorient",
                        desc = "Fear, Cyclone, Sleep Walk, Blind etc.",
                        get = function() return self.db.profile.trackDR_disorient end,
                        set = function(_, value)
                            self.db.profile.trackDR_disorient = value
                            self:UpdateConfig()
                            self:RefreshTestAnimation(self.db.profile.trackDR_disorient)
                        end,
                    },
                    trackDR_incapacitate = {
                        order = 9.4,
                        type = "toggle",
                        name = "Incapacitate",
                        desc = "Sap, Polymorph, Freezing Trap, etc.",
                        get = function() return self.db.profile.trackDR_incapacitate end,
                        set = function(_, value)
                            self.db.profile.trackDR_incapacitate = value
                            self:UpdateConfig()
                            self:RefreshTestAnimation(self.db.profile.trackDR_incapacitate)
                        end,
                    },
                    trackDR_root = {
                        order = 9.5,
                        type = "toggle",
                        name = "Root",
                        desc = "Entangling Roots, Frost Nova, etc.",
                        get = function() return self.db.profile.trackDR_root end,
                        set = function(_, value)
                            self.db.profile.trackDR_root = value
                            self:UpdateConfig()
                            self:RefreshTestAnimation(self.db.profile.trackDR_root)
                        end,
                    },
                    trackDR_silence = {
                        order = 9.6,
                        type = "toggle",
                        name = "Silence",
                        desc = "Strangulate, Garrote, etc.",
                        get = function() return self.db.profile.trackDR_silence end,
                        set = function(_, value)
                            self.db.profile.trackDR_silence = value
                            self:UpdateConfig()
                            self:RefreshTestAnimation(self.db.profile.trackDR_silence)
                        end,
                    },
                    trackDR_knockback = {
                        order = 9.7,
                        type = "toggle",
                        name = "Knockback",
                        desc = "Typhoon, Thunderstorm etc.",
                        get = function() return self.db.profile.trackDR_knockback end,
                        set = function(_, value)
                            self.db.profile.trackDR_knockback = value
                            self:UpdateConfig()
                            self:RefreshTestAnimation(self.db.profile.trackDR_knockback)

                        end,
                    },
                    trackDR_disarm = {
                        order = 9.8,
                        type = "toggle",
                        name = "Disarm",
                        desc = "Disarm abilities",
                        get = function() return self.db.profile.trackDR_disarm end,
                        set = function(_, value)
                            self.db.profile.trackDR_disarm = value
                            self:UpdateConfig()
                            self:RefreshTestAnimation(self.db.profile.trackDR_disarm)
                        end,
                    },
                },
            },
        },
    }

    LibStub("AceConfig-3.0"):RegisterOptionsTable("MyDRs", self.options)

    -- Add the options table to Blizzard's options UI
    self.optionsFrame, self.optionsCategoryID = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("MyDRs", "MyDRs")
    -- Register slash commands
    self:RegisterChatCommand("mydrs", function(input)
        if Settings and Settings.OpenToCategory and self.optionsCategoryID then
            Settings.OpenToCategory(self.optionsCategoryID)
            return
        end

        if InterfaceOptionsFrame_OpenToCategory and self.optionsFrame then
            InterfaceOptionsFrame_OpenToCategory(self.optionsFrame)
        end
    end)

    self:UpdateConfig()
end


local arrowButtonTextures = {
    RIGHT = {
        normal = "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up",
        pushed = "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down",
        disabled = "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Disabled",
        rotation = 0,
    },
    LEFT = {
        normal = "Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up",
        pushed = "Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Down",
        disabled = "Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Disabled",
        rotation = 0,
    },
    UP = {
        normal = "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up",
        pushed = "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down",
        disabled = "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Disabled",
        rotation = math.pi / 2,
    },
    DOWN = {
        normal = "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up",
        pushed = "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down",
        disabled = "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Disabled",
        rotation = -math.pi / 2,
    },
}

function MyDRs:createArrowButton(direction, x, y)
    local parent = self.drFrame
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(24, 24)
    button:SetFrameLevel(parent:GetFrameLevel() + 10)

    local style = arrowButtonTextures[direction]
    if not style then
        return button
    end

    if direction == "UP" or direction == "DOWN" then
        button:SetPoint("CENTER", parent, "RIGHT", x, y)
    else
        button:SetPoint("BOTTOM", parent, "BOTTOM", x, y)
    end

    button:SetNormalTexture(style.normal)
    button:SetPushedTexture(style.pushed)
    button:SetDisabledTexture(style.disabled)
    button:SetHighlightTexture(style.normal, "ADD")

    local rotation = style.rotation or 0
    local normalTexture = button:GetNormalTexture()
    local pushedTexture = button:GetPushedTexture()
    local disabledTexture = button:GetDisabledTexture()
    local highlightTexture = button:GetHighlightTexture()

    if normalTexture then
        normalTexture:SetAllPoints(button)
        normalTexture:SetRotation(rotation)
    end
    if pushedTexture then
        pushedTexture:SetAllPoints(button)
        pushedTexture:SetRotation(rotation)
    end
    if disabledTexture then
        disabledTexture:SetAllPoints(button)
        disabledTexture:SetRotation(rotation)
    end
    if highlightTexture then
        highlightTexture:SetAllPoints(button)
        highlightTexture:SetRotation(rotation)
        highlightTexture:SetAlpha(0.35)
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
        MyDRs.db.profile.containerPosition = { point = point, relativePoint = relPoint, x = xOffset, y = yOffset }
    end)

    return button
end

local ticker

function MyDRs:applyTestMode()
    local arrowsReady = self.upArrow and self.downArrow and self.leftArrow and self.rightArrow

    if self.db.profile.enableTestMode then
        self.drFrame:SetMovable(true)
        self.drFrame:EnableMouse(true)
        self.drFrame:Show()
        if arrowsReady then
            self.upArrow:Show()
            self.downArrow:Show()
            self.leftArrow:Show()
            self.rightArrow:Show()
        end
        self.drFrame:SetBackdrop({
            bgFile = nil,
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 12,
        })
        self.drFrame:SetBackdropBorderColor(1, 0, 0, 1)
        self:playTestAnimation()
    else 
        if ticker then
            ticker:Cancel()
            ticker = nil
        end

        self.drFrame:SetMovable(false)
        self.drFrame:EnableMouse(false)
        self.drFrame:SetBackdrop(nil)
        self.drFrame:Show()
        if arrowsReady then
            self.upArrow:Hide()
            self.downArrow:Hide()
            self.leftArrow:Hide()
            self.rightArrow:Hide()
        end

        -- Clear test-mode visuals immediately, then rebuild from live state if needed.
        self:ResetAllDRStates()
        self:UpdateDRs()
    end
end

function MyDRs:playTestAnimation()
    if not self.drFrame then
        return
    end

    local interval = 16

    if ticker then
        ticker:Cancel()
    end

    ticker = C_Timer.NewTicker(interval, function()
        if not self.db.profile.enableTestMode then
            ticker:Cancel()
            ticker = nil
            return
        end

        if not self.drFrame then
            ticker:Cancel()
            ticker = nil
            return
        end
    
        self:PlayTestMode()
    end)

    -- Run once immediately (replicates isFirstTimePlaying)
    self:PlayTestMode()
end


function MyDRs:PlayTestMode()
    local now = GetTime()

    for i = 1, #drCategories do
        local category = drCategories[i]
        local isTracked = self.db.profile["trackDR_" .. category]
        local drFrame = self:GetDRFrame(category)
        if drFrame and drFrame.cooldown then
            if isTracked then
                drFrame:Show()
                drFrame.cooldown:SetCooldown(now, DR_WINDOW_DURATION)
                drFrame.cooldown:SetSwipeColor(0, 0, 0, self.db.profile.cooldownSwipeAlpha)
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
            else
                drFrame:Hide()
            end
        end
    end

    self:SortIcons()
end

function MyDRs:RefreshImmuneAlertGlow()
    local glowEnabled = self.db.profile.enableImmuneAlertGlow

    for _, category in ipairs(drCategories) do
        local state = self.drStateByCategory[category]
        local stacks = state and state.stacks or 0
        self:SetImmuneGlow(category, glowEnabled and stacks >= 2)
    end
end

function MyDRs:RefreshTestAnimation(condition)
    if self.db.profile.enableTestMode and condition then
        self:playTestAnimation()
    end
end