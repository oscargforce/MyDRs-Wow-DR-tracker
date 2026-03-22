local MyDRs = LibStub("AceAddon-3.0"):GetAddon("MyDRs")
local addonName, addon = ...
local drCategories = addon.drCategories
local DR_WINDOW_DURATION = addon.DR_WINDOW_DURATION
local immuneAlertResetVisuals = addon.ResetImmuneAlertVisuals
local drIconTextures = addon.drIconTextures
local C_Timer = C_Timer
local LibStub = LibStub
local InterfaceOptionsFrame_OpenToCategory = InterfaceOptionsFrame_OpenToCategory
local Settings = Settings

function MyDRs:UpdateConfig()
    local db = self.db.profile
    local fontSize = self:GetBaseFontSize()

    for i = 1, #drCategories do
        local category = drCategories[i]
        local drFrame = self:GetDRFrame(category)
        if drFrame then
            drFrame:SetSize(addon.BASE_ICON_SIZE, addon.BASE_ICON_SIZE)
            drFrame.cooldown:SetReverse(db.enableCooldownReverse)
            drFrame.cooldown:SetSwipeColor(0, 0, 0, db.cooldownSwipeAlpha)
            drFrame.cooldown:SetHideCountdownNumbers(not db.showCountdownText)
            drFrame.drStateText:SetFont(drFrame.drStateText:GetFont(), fontSize, "OUTLINE")
            drFrame.drStateText:SetShown(db.showDRStateText)

            local tex = db["drTexture_" .. category]
            if drFrame.icon and tex and tex ~= "" then
                drFrame.icon:SetTexture(tex)
            end

            if not db["trackDR_" .. category] then
                self:SetDRFrameVisible(category, false)
            end
        end
    end

    local position = db.containerPosition
    self.drFrame:ClearAllPoints()
    self.drFrame:SetPoint(position.point, UIParent, position.relativePoint, position.x or 0, position.y or 0)
    self:UpdateIconContainerLayout()
    self:SortIcons()
    self:RefreshImmuneAlertGlow()
    self:RefreshMasqueSkin() -- not sure if needed
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
            resetPosition = {
                type = "execute",
                name = "Reset Position",
                desc = "Reset the position of the DR bar to its default location.",
                order = 0,
                func = function()
                    self.db.profile.containerPosition = { point = "CENTER", relativePoint = "CENTER", x = 0, y = 0 }
                    self:UpdateConfig()
                end,
                width = 0.7,
            },
            enableTestMode = {
                        order = 1,
                        type = "execute",
                        desc = "Toggle test mode to preview DR tracking behavior.",
                        name = function() return self.db.profile.enableTestMode and "Stop Test Mode" or "Play Test Mode" end,
                        func = function()
                            self.db.profile.enableTestMode = not self.db.profile.enableTestMode
                            self:applyTestMode()
                        end,
                        width = 1.5,
                    },
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
                      lineBreak0 = {
                        name = " ",
                        type = "description",
                        order = 1,
                    },
                    orientation = {
                        order = 1.5,
                        type = "select",
                        name = "Bar Orientation",
                        desc = "Choose the orientation of the DR bar.",
                        values = { ["HORIZONTAL"] = "Horizontal", ["VERTICAL"] = "Vertical" },
                        get = function() return self.db.profile.orientation end,
                        set = function(_, value)
                            self.db.profile.orientation = value
                            self:UpdateConfig()
                            self:RefreshTestAnimation(true)
                        end,
                    },
                    growIconsFromLeft = {
                        order = 2,
                        type = "select",
                        name = "Icon Growth Direction",
                        desc = "Choose the direction from which new DR icons will grow when added to the bar.",
                        values = { ["LEFT"] = "Left", ["RIGHT"] = "Right" },
                        get = function() return self.db.profile.growIconsFromLeft and "LEFT" or "RIGHT" end,
                        set = function(_, value)
                            local isLeft = value == "LEFT"
                            self.db.profile.growIconsFromLeft = isLeft
                            self:UpdateConfig()
                            self:RefreshTestAnimation(true)
                        end,
                        hidden = function() return self.db.profile.orientation == "VERTICAL" end,
                    },
                    growDirectionVertical = {
                        order = 2.2,
                        type = "select",
                        name = "Icon Growth Direction",
                        desc = "Choose the direction from which new DR icons will grow when added to the bar.",
                        values = { ["UP"] = "Up", ["DOWN"] = "Down" },
                        get = function() return self.db.profile.growDirectionVertical end,
                        set = function(_, value)
                            self.db.profile.growDirectionVertical = value
                            self:UpdateConfig()
                            self:RefreshTestAnimation(true)
                        end,
                        hidden = function() return self.db.profile.orientation == "HORIZONTAL" end,
                    },
                    lineBreak1 = {
                        name = " ",
                        type = "description",
                        order = 2.5,
                    },
                    enableCooldownReverse = {
                        order = 3,
                        type = "toggle",
                        name = "Reverse Cooldown Swipe",
                        get = function() return self.db.profile.enableCooldownReverse end,
                        set = function(_, value)
                            self.db.profile.enableCooldownReverse = value
                            self:UpdateConfig()
                            self:RefreshTestAnimation(true)
                        end,
                    },
                    showCountdownText = {
                        order = 4,
                        type = "toggle",
                        name = "Show Countdown Text",
                        desc = "Show or hide Blizzard's default countdown text on DR icons.",
                        get = function() return self.db.profile.showCountdownText end,
                        set = function(_, value)
                            self.db.profile.showCountdownText = value
                            self:UpdateConfig()
                            self:RefreshTestAnimation(true)
                        end,
                    },
                    showDRStateText = {
                        order = 4.05,
                        type = "toggle",
                        name = "Show DR State Text",
                        desc = "Show or hide the 50% / IMM text on DR icons.",
                        get = function() return self.db.profile.showDRStateText end,
                        set = function(_, value)
                            self.db.profile.showDRStateText = value
                            self:UpdateConfig()
                            self:RefreshTestAnimation(true)
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
                        min = 20,
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
                        max = 40,
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
                        disabled = function() return not self.db.profile.showDRStateText end,
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
                    lineBreak5 = {
                        name = " ",
                        type = "description",
                        order = 9.9,
                    },
                    zoneTypeHeader = {
                        order = 10,
                        type = "description",
                        fontSize = "large",
                        name = "Enable Tracking In:",
                    },
                    lineBreak6 = {
                        name = " ",
                        type = "description",
                        order = 10.5,
                    },
                    enableInArena = {
                        order = 11,
                        type = "toggle",
                        name = "Arenas",
                        get = function() return self.db.profile.enableInArena end,
                        set = function(_, value)
                            self.db.profile.enableInArena = value
                            self:ApplyZoneState()
                        end,
                    },
                    enableInBattleground = {
                        order = 12,
                        type = "toggle",
                        name = "Battlegrounds",
                        get = function() return self.db.profile.enableInBattleground end,
                        set = function(_, value)
                            self.db.profile.enableInBattleground = value
                            self:ApplyZoneState()
                        end,
                    },
                    enableInWorld = {
                        order = 13,
                        type = "toggle",
                        name = "World",
                        get = function() return self.db.profile.enableInWorld end,
                        set = function(_, value)
                            self.db.profile.enableInWorld = value
                            self:ApplyZoneState()
                        end,
                    },
                },
            },
            textures = {
                type = "group",
                name = "Textures",
                order = 2,
                args = {
                    desc = {
                        order = 0,
                        type = "description",
                        fontSize = "medium",
                        name = "|cffffd200Custom Icon Path|r\n\n" ..
                                "Enter the full path to the icon you want to use.\n\n" ..
                                "Example:\n" ..
                                "|cff00ff00Interface\\Icons\\Spell_Frost_FrostNova|r\n\n" ..
                                "You can search for the spell on |cff33ccffWowhead|r and open its page.\n" ..
                                "The icon name can be found in the |cffffff00\"Quick Facts\"|r section.\n" ..
                                "Copy the icon name and paste it after:\n" ..
                                "|cffaaaaaaInterface\\Icons\\|r",
                    },
                    lineBreak1 = { order = 0.5, type = "description", name = " " },
                    drTexture_stun = {
                        order = 1,
                        type = "input",
                        name = "Stun",
                        desc = "Texture path or ID for Stun icons. Leave empty to use default.",
                        get = function() return self.db.profile.drTexture_stun end,
                        set = function(_, value)
                            self.db.profile.drTexture_stun = value
                            self:UpdateConfig()
                        end,
                        width = "full",
                    },
                    drTexture_disorient = {
                        order = 2,
                        type = "input",
                        name = "Disorient",
                        desc = "Texture path or ID for Disorient icons. Leave empty to use default.",
                        get = function() return self.db.profile.drTexture_disorient end,
                        set = function(_, value)
                            self.db.profile.drTexture_disorient = value
                            self:UpdateConfig()
                        end,
                        width = "full",
                    },
                    drTexture_incapacitate = {
                        order = 3,
                        type = "input",
                        name = "Incapacitate",
                        desc = "Texture path or ID for Incapacitate icons. Leave empty to use default.",
                        get = function() return self.db.profile.drTexture_incapacitate end,
                        set = function(_, value)
                            self.db.profile.drTexture_incapacitate = value
                            self:UpdateConfig()
                        end,
                        width = "full",
                    },
                    drTexture_root = {
                        order = 4,
                        type = "input",
                        name = "Root",
                        desc = "Texture path or ID for Root icons. Leave empty to use default.",
                        get = function() return self.db.profile.drTexture_root end,
                        set = function(_, value)
                            self.db.profile.drTexture_root = value
                            self:UpdateConfig()
                        end,
                        width = "full",
                    },
                    drTexture_silence = {
                        order = 5,
                        type = "input",
                        name = "Silence",
                        desc = "Texture path or ID for Silence icons. Leave empty to use default.",
                        get = function() return self.db.profile.drTexture_silence end,
                        set = function(_, value)
                            self.db.profile.drTexture_silence = value
                            self:UpdateConfig()
                        end,
                        width = "full",
                    },
                    drTexture_knockback = {
                        order = 6,
                        type = "input",
                        name = "Knockback",
                        desc = "Texture path or ID for Knockback icons. Leave empty to use default.",
                        get = function() return self.db.profile.drTexture_knockback end,
                        set = function(_, value)
                            self.db.profile.drTexture_knockback = value
                            self:UpdateConfig()
                        end,
                        width = "full",
                    },
                    drTexture_disarm = {
                        order = 7,
                        type = "input",
                        name = "Disarm",
                        desc = "Texture path or ID for Disarm icons. Leave empty to use default.",
                        get = function() return self.db.profile.drTexture_disarm end,
                        set = function(_, value)
                            self.db.profile.drTexture_disarm = value
                            self:UpdateConfig()
                        end,
                        width = "full",
                    },
                    lineBreak2 = { order = 7.5, type = "description", name = " " },
                    resetTextures = {
                        order = 8,
                        type = "execute",
                        name = "Reset All Textures",
                        desc = "Restore all DR category icons to their default textures.",
                        func = function()
                            self.db.profile.drTexture_stun         =  drIconTextures.stun
                            self.db.profile.drTexture_disorient    =  drIconTextures.disorient
                            self.db.profile.drTexture_incapacitate =  drIconTextures.incapacitate
                            self.db.profile.drTexture_root         =  drIconTextures.root
                            self.db.profile.drTexture_silence      =  drIconTextures.silence
                            self.db.profile.drTexture_knockback    =  drIconTextures.knockback
                            self.db.profile.drTexture_disarm       =  drIconTextures.disarm
                            self:UpdateConfig()
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
        local command = input and input:trim():lower() or ""
        if command == "test" then
            self.db.profile.enableTestMode = not self.db.profile.enableTestMode
            self:applyTestMode()
            -- Refresh the options UI to reflect the changes
             LibStub("AceConfigRegistry-3.0"):NotifyChange("MyDRs")
            return
        else
            if Settings and Settings.OpenToCategory and self.optionsCategoryID then
                Settings.OpenToCategory(self.optionsCategoryID)
                return
             end

        if InterfaceOptionsFrame_OpenToCategory and self.optionsFrame then
                InterfaceOptionsFrame_OpenToCategory(self.optionsFrame)
            end
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
    local anchorTarget = self:GetIconContainer() or parent
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(24, 24)
    button:SetFrameLevel(anchorTarget:GetFrameLevel() + 10)

    local style = arrowButtonTextures[direction]
    if not style then
        return button
    end

    button:SetPoint("BOTTOM", anchorTarget, "BOTTOM", x, y)

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

        MyDRs.db.profile.containerPosition = { point = point, relativePoint = relPoint, x = xOffset, y = yOffset }
    end)

    return button
end

local ticker

function MyDRs:applyTestMode()
    local arrowsReady = self.upArrow and self.downArrow and self.leftArrow and self.rightArrow
    local visualFrame = self:GetIconContainer() or self.drFrame

    if self.db.profile.enableTestMode then
        self.drFrame:SetMovable(true)
        self.drFrame:EnableMouse(true)
        self.drFrame:SetFrameStrata("TOOLTIP")
        if visualFrame then
            visualFrame:EnableMouse(true)
        end
        self.drFrame:Show()
        if arrowsReady then
            self.upArrow:Show()
            self.downArrow:Show()
            self.leftArrow:Show()
            self.rightArrow:Show()
        end
        if visualFrame then
            visualFrame:SetBackdrop({
                bgFile = nil,
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                edgeSize = 12,
            })
            visualFrame:SetBackdropBorderColor(0, 0, 0, 0.3)
        end
        self:playTestAnimation()
    else
        if ticker then
            ticker:Cancel()
            ticker = nil
        end

        self.drFrame:SetMovable(false)
        self.drFrame:EnableMouse(false)
        self.drFrame:SetFrameStrata("MEDIUM")
        if visualFrame then
            visualFrame:EnableMouse(false)
            visualFrame:SetBackdrop(nil)
        end
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
                self:RefreshMasqueSkin()
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