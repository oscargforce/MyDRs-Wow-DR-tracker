-- All credits for the animations go to the authors of OmniCD

local addonName, addon = ...
local AnimateTexCoords = AnimateTexCoords

local IMMUNE_GLOW_COLOR_R = 0.68
local IMMUNE_GLOW_COLOR_G = 0.28
local IMMUNE_GLOW_COLOR_B = 0.98
local IMMUNE_GLOW_COLOR_A = 0.75
local IMMUNE_ALERT_FRAME_PADDING = 0.35
local IMMUNE_ALERT_ANTS_SCALE = 0.78
local IMMUNE_ALERT_ANTS_THROTTLE = 0.006

local function createScaleAnim(group, childKey, order, duration, scaleX, scaleY, startDelay)
    local scale = group:CreateAnimation("Scale")
    scale:SetChildKey(childKey)
    scale:SetOrder(order)
    scale:SetDuration(duration)
    scale:SetScale(scaleX, scaleY)

    if startDelay then
        scale:SetStartDelay(startDelay)
    end
end

local function createAlphaAnim(group, childKey, order, duration, fromAlpha, toAlpha, startDelay)
    local alpha = group:CreateAnimation("Alpha")
    alpha:SetChildKey(childKey)
    alpha:SetOrder(order)
    alpha:SetDuration(duration)
    alpha:SetFromAlpha(fromAlpha)
    alpha:SetToAlpha(toAlpha)

    if startDelay then
        alpha:SetStartDelay(startDelay)
    end
end

local function immuneAlertOnUpdate(self, elapsed)
    AnimateTexCoords(self.ants, 256, 256, 48, 48, 22, elapsed, IMMUNE_ALERT_ANTS_THROTTLE)
end

local function immuneAlertResetVisuals(alertFrame)
    if not alertFrame then
        return
    end

    local frameWidth, frameHeight = alertFrame:GetSize()

    alertFrame.spark:SetAlpha(0)
    alertFrame.spark:SetSize(frameWidth, frameHeight)
    alertFrame.innerGlow:SetAlpha(0)
    alertFrame.innerGlow:SetSize(frameWidth, frameHeight)
    alertFrame.innerGlowOver:SetAlpha(0)
    alertFrame.outerGlow:SetAlpha(0)
    alertFrame.outerGlow:SetSize(frameWidth, frameHeight)
    alertFrame.outerGlowOver:SetAlpha(0)
    alertFrame.outerGlowOver:SetSize(frameWidth, frameHeight)
    alertFrame.ants:SetAlpha(0)
end

local function immuneAlertAnimIn_OnPlay(group)
    local alertFrame = group:GetParent()
    local frameWidth, frameHeight = alertFrame:GetSize()

    alertFrame.spark:SetSize(frameWidth, frameHeight)
    alertFrame.spark:SetAlpha(0.3)
    alertFrame.innerGlow:SetSize(frameWidth / 2, frameHeight / 2)
    alertFrame.innerGlow:SetAlpha(1.0)
    alertFrame.innerGlowOver:SetAlpha(1.0)
    alertFrame.outerGlow:SetSize(frameWidth * 2, frameHeight * 2)
    alertFrame.outerGlow:SetAlpha(1.0)
    alertFrame.outerGlowOver:SetAlpha(1.0)
    alertFrame.ants:SetSize(frameWidth * IMMUNE_ALERT_ANTS_SCALE, frameHeight * IMMUNE_ALERT_ANTS_SCALE)
    alertFrame.ants:SetAlpha(0)
    alertFrame.isActive = true
    alertFrame.isAnimatingOut = false
    alertFrame:SetScript("OnUpdate", immuneAlertOnUpdate)
    alertFrame:Show()
end

local function immuneAlertAnimIn_OnFinished(group)
    local alertFrame = group:GetParent()
    local frameWidth, frameHeight = alertFrame:GetSize()

    alertFrame.spark:SetAlpha(0)
    alertFrame.innerGlow:SetAlpha(0)
    alertFrame.innerGlow:SetSize(frameWidth, frameHeight)
    alertFrame.innerGlowOver:SetAlpha(0)
    alertFrame.outerGlow:SetSize(frameWidth, frameHeight)
    alertFrame.outerGlowOver:SetAlpha(0)
    alertFrame.outerGlowOver:SetSize(frameWidth, frameHeight)
    alertFrame.ants:SetAlpha(1.0)
end

local function immuneAlertAnimIn_OnStop(group)
    local alertFrame = group:GetParent()

    alertFrame.spark:SetAlpha(0)
    alertFrame.innerGlow:SetAlpha(0)
    alertFrame.innerGlowOver:SetAlpha(0)
    alertFrame.outerGlowOver:SetAlpha(0)
end

local function immuneAlertAnimOut_OnFinished(group)
    local alertFrame = group:GetParent()
    local ownerFrame = alertFrame:GetParent()

    alertFrame.isActive = false
    alertFrame.isAnimatingOut = false
    alertFrame:SetScript("OnUpdate", nil)
    immuneAlertResetVisuals(alertFrame)
    alertFrame:Hide()

    if ownerFrame and ownerFrame.pendingHideAfterImmuneAlert then
        ownerFrame.pendingHideAfterImmuneAlert = nil
        ownerFrame:Hide()
    end
    
    MyDRs:SortIcons()
end

local function createImmuneAlertFrame(parentFrame)
    local alertFrame = CreateFrame("Frame", nil, parentFrame)
    local parentWidth, parentHeight = parentFrame:GetSize()
    alertFrame:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", -parentWidth * IMMUNE_ALERT_FRAME_PADDING, parentHeight * IMMUNE_ALERT_FRAME_PADDING)
    alertFrame:SetPoint("BOTTOMRIGHT", parentFrame, "BOTTOMRIGHT", parentWidth * IMMUNE_ALERT_FRAME_PADDING, -parentHeight * IMMUNE_ALERT_FRAME_PADDING)
    alertFrame:SetFrameLevel(parentFrame:GetFrameLevel() + 10)
    if alertFrame.SetIgnoreParentAlpha then
        alertFrame:SetIgnoreParentAlpha(true)
    end
    alertFrame:Hide()

    alertFrame.spark = alertFrame:CreateTexture(nil, "BACKGROUND")
    alertFrame.spark:SetPoint("CENTER")
    alertFrame.spark:SetAlpha(0)
    alertFrame.spark:SetTexture("Interface\\SpellActivationOverlay\\IconAlert")
    alertFrame.spark:SetVertexColor(IMMUNE_GLOW_COLOR_R, IMMUNE_GLOW_COLOR_G, IMMUNE_GLOW_COLOR_B, IMMUNE_GLOW_COLOR_A)
    alertFrame.spark:SetTexCoord(0.00781250, 0.61718750, 0.00390625, 0.26953125)

    alertFrame.innerGlow = alertFrame:CreateTexture(nil, "ARTWORK")
    alertFrame.innerGlow:SetPoint("CENTER")
    alertFrame.innerGlow:SetAlpha(0)
    alertFrame.innerGlow:SetTexture("Interface\\SpellActivationOverlay\\IconAlert")
    alertFrame.innerGlow:SetVertexColor(IMMUNE_GLOW_COLOR_R, IMMUNE_GLOW_COLOR_G, IMMUNE_GLOW_COLOR_B, IMMUNE_GLOW_COLOR_A)
    alertFrame.innerGlow:SetTexCoord(0.00781250, 0.50781250, 0.27734375, 0.52734375)

    alertFrame.innerGlowOver = alertFrame:CreateTexture(nil, "ARTWORK")
    alertFrame.innerGlowOver:SetPoint("TOPLEFT", alertFrame.spark, "TOPLEFT")
    alertFrame.innerGlowOver:SetPoint("BOTTOMRIGHT", alertFrame.spark, "BOTTOMRIGHT")
    alertFrame.innerGlowOver:SetAlpha(0)
    alertFrame.innerGlowOver:SetTexture("Interface\\SpellActivationOverlay\\IconAlert")
    alertFrame.innerGlowOver:SetVertexColor(IMMUNE_GLOW_COLOR_R, IMMUNE_GLOW_COLOR_G, IMMUNE_GLOW_COLOR_B, IMMUNE_GLOW_COLOR_A)
    alertFrame.innerGlowOver:SetTexCoord(0.00781250, 0.50781250, 0.53515625, 0.78515625)

    alertFrame.outerGlow = alertFrame:CreateTexture(nil, "ARTWORK")
    alertFrame.outerGlow:SetPoint("CENTER")
    alertFrame.outerGlow:SetAlpha(0)
    alertFrame.outerGlow:SetTexture("Interface\\SpellActivationOverlay\\IconAlert")
    alertFrame.outerGlow:SetVertexColor(IMMUNE_GLOW_COLOR_R, IMMUNE_GLOW_COLOR_G, IMMUNE_GLOW_COLOR_B, IMMUNE_GLOW_COLOR_A)
    alertFrame.outerGlow:SetTexCoord(0.00781250, 0.50781250, 0.27734375, 0.52734375)

    alertFrame.outerGlowOver = alertFrame:CreateTexture(nil, "ARTWORK")
    alertFrame.outerGlowOver:SetPoint("TOPLEFT", alertFrame.outerGlow, "TOPLEFT")
    alertFrame.outerGlowOver:SetPoint("BOTTOMRIGHT", alertFrame.outerGlow, "BOTTOMRIGHT")
    alertFrame.outerGlowOver:SetAlpha(0)
    alertFrame.outerGlowOver:SetTexture("Interface\\SpellActivationOverlay\\IconAlert")
    alertFrame.outerGlowOver:SetVertexColor(IMMUNE_GLOW_COLOR_R, IMMUNE_GLOW_COLOR_G, IMMUNE_GLOW_COLOR_B, IMMUNE_GLOW_COLOR_A)
    alertFrame.outerGlowOver:SetTexCoord(0.00781250, 0.50781250, 0.53515625, 0.78515625)

    alertFrame.ants = alertFrame:CreateTexture(nil, "OVERLAY")
    alertFrame.ants:SetPoint("CENTER")
    alertFrame.ants:SetAlpha(0)
    alertFrame.ants:SetTexture("Interface\\SpellActivationOverlay\\IconAlertAnts")
    alertFrame.ants:SetVertexColor(IMMUNE_GLOW_COLOR_R, IMMUNE_GLOW_COLOR_G, IMMUNE_GLOW_COLOR_B, IMMUNE_GLOW_COLOR_A)

    alertFrame.animIn = alertFrame:CreateAnimationGroup()
    createScaleAnim(alertFrame.animIn, "spark", 1, 0.2, 1.5, 1.5)
    createAlphaAnim(alertFrame.animIn, "spark", 1, 0.2, 0, 1)
    createScaleAnim(alertFrame.animIn, "innerGlow", 1, 0.3, 2, 2)
    createScaleAnim(alertFrame.animIn, "innerGlowOver", 1, 0.3, 2, 2)
    createAlphaAnim(alertFrame.animIn, "innerGlowOver", 1, 0.3, 1, 0)
    createScaleAnim(alertFrame.animIn, "outerGlow", 1, 0.3, 0.5, 0.5)
    createScaleAnim(alertFrame.animIn, "outerGlowOver", 1, 0.3, 0.5, 0.5)
    createAlphaAnim(alertFrame.animIn, "outerGlowOver", 1, 0.3, 1, 0)
    createScaleAnim(alertFrame.animIn, "spark", 1, 0.2, 2 / 3, 2 / 3, 0.2)
    createAlphaAnim(alertFrame.animIn, "spark", 1, 0.2, 1, 0, 0.2)
    createAlphaAnim(alertFrame.animIn, "innerGlow", 1, 0.2, 1, 0, 0.3)
    createAlphaAnim(alertFrame.animIn, "ants", 1, 0.2, 0, 1, 0.3)
    alertFrame.animIn:SetScript("OnPlay", immuneAlertAnimIn_OnPlay)
    alertFrame.animIn:SetScript("OnFinished", immuneAlertAnimIn_OnFinished)
    alertFrame.animIn:SetScript("OnStop", immuneAlertAnimIn_OnStop)

    alertFrame.animOut = alertFrame:CreateAnimationGroup()
    createAlphaAnim(alertFrame.animOut, "outerGlowOver", 1, 0.2, 0, 1)
    createAlphaAnim(alertFrame.animOut, "ants", 1, 0.2, 1, 0)
    createAlphaAnim(alertFrame.animOut, "outerGlowOver", 2, 0.2, 1, 0)
    createAlphaAnim(alertFrame.animOut, "outerGlow", 2, 0.2, 1, 0)
    alertFrame.animOut:SetScript("OnFinished", immuneAlertAnimOut_OnFinished)

    alertFrame:SetScript("OnHide", function(self)
        self.isActive = false
        self.isAnimatingOut = false
        self:SetScript("OnUpdate", nil)
    end)

    return alertFrame
end

addon.CreateImmuneAlertFrame = createImmuneAlertFrame
addon.ResetImmuneAlertVisuals = immuneAlertResetVisuals

-- RED IMMUNE BORDER
local function createImmuneBorder(parentFrame)
    local r, g, b, a = 1, 0, 0, 1
    local borderPadding = 1

    local borderFrame = CreateFrame("Frame", nil, parentFrame)
    borderFrame:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", -borderPadding, borderPadding)
    borderFrame:SetPoint("BOTTOMRIGHT", parentFrame, "BOTTOMRIGHT", borderPadding, -borderPadding)
    borderFrame:SetFrameLevel(parentFrame:GetFrameLevel() + 8)

    borderFrame.borderTexture = borderFrame:CreateTexture(nil, "OVERLAY")
    borderFrame.borderTexture:SetAllPoints()
    borderFrame.borderTexture:SetTexture("Interface\\Buttons\\UI-Debuff-Overlays")
    borderFrame.borderTexture:SetTexCoord(0.296875, 0.5703125, 0, 0.515625)
    borderFrame.borderTexture:SetVertexColor(r, g, b, a)

    borderFrame:Hide()

    return borderFrame
end

-- GREEN PRE-IMMUNE BORDER
local function createPreImmuneBorder(parentFrame)
    local r, g, b, a = 0, 1, 0, 1
    local borderPadding = 1

    local borderFrame = CreateFrame("Frame", nil, parentFrame)
    borderFrame:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", -borderPadding, borderPadding)
    borderFrame:SetPoint("BOTTOMRIGHT", parentFrame, "BOTTOMRIGHT", borderPadding, -borderPadding)
    borderFrame:SetFrameLevel(parentFrame:GetFrameLevel() + 8)

    borderFrame.borderTexture = borderFrame:CreateTexture(nil, "OVERLAY")
    borderFrame.borderTexture:SetAllPoints()
    borderFrame.borderTexture:SetTexture("Interface\\Buttons\\UI-Debuff-Overlays")
    borderFrame.borderTexture:SetTexCoord(0.296875, 0.5703125, 0, 0.515625)
    borderFrame.borderTexture:SetVertexColor(r, g, b, a)

    borderFrame:Hide()

    return borderFrame
end

addon.CreateImmuneBorder = createImmuneBorder
addon.CreatePreImmuneBorder = createPreImmuneBorder
