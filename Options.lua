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

    local position = db.containerPosition
    self.drFrame:ClearAllPoints()
    self.drFrame:SetPoint(position.point, UIParent, position.relativePoint, position.x or 0, position.y or 0)
    self:SortIcons()
     
 
end

function MyDRs:SetupOptions()
    self.options = {
        type = "group",
        name = "MyDRs Options",
        args = {
            desc = {
                order = 0,
                type = "description",
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
        },
    }

    -- Creates the profiules options table and embeds it in our options
    local aceDBOptions = LibStub("AceDBOptions-3.0", true)
    if aceDBOptions then
        local profilesOptions = aceDBOptions:GetOptionsTable(self.db)
        profilesOptions.order = 100
        self.options.args.profiles = profilesOptions
    end

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


function MyDRs:createArrowButton(direction, x, y)
    local parent = self.drFrame
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
        local drFrame = self:GetDRFrame(category)
        if drFrame and drFrame.cooldown then
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
        end
    end

    self:SortIcons()
end