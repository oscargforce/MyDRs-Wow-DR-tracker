local MyDRs = LibStub("AceAddon-3.0"):GetAddon("MyDRs")

function MyDRs:HorizontalLayout(visibleFrames, trackerFrame, padding)
    local growIconsFromLeft = self.db.profile.growIconsFromLeft

     for index, frame in ipairs(visibleFrames) do
        frame:ClearAllPoints()

        if index == 1 then
            if growIconsFromLeft then
                frame:SetPoint("RIGHT", trackerFrame, "RIGHT", 0, 0)
            else
                frame:SetPoint("LEFT", trackerFrame, "LEFT", 0, 0)
            end
        else
            if growIconsFromLeft then
                frame:SetPoint("RIGHT", visibleFrames[index - 1], "LEFT", -padding, 0)
            else
                frame:SetPoint("LEFT", visibleFrames[index - 1], "RIGHT", padding, 0)
            end
        end
    end
end

function MyDRs:VerticalLayout(visibleFrames, trackerFrame, padding)
    local growthDirection = self.db.profile.growDirectionVertical

        for index, frame in ipairs(visibleFrames) do
        frame:ClearAllPoints()
        if index == 1 then
             if growthDirection == "DOWN" then
                frame:SetPoint("TOP", trackerFrame, "TOP", 0, 0)
            else
                frame:SetPoint("BOTTOM", trackerFrame, "BOTTOM", 0, 0)
            end
        else
            if growthDirection == "DOWN" then
                frame:SetPoint("TOP", visibleFrames[index - 1], "BOTTOM", 0, -padding)
            else
                frame:SetPoint("BOTTOM", visibleFrames[index - 1], "TOP", 0, padding)
            end
        end 
        
    end
end

function MyDRs:SortVisibleDRIcons(categories, skipSort)
    if not categories then
        return
    end

    local trackerFrame = self:GetIconContainer()

    local visibleFrames = {}
    for _, category in ipairs(categories) do
        local frame = self:GetDRFrame(category)
        if frame and frame:IsShown() then
            visibleFrames[#visibleFrames + 1] = frame
        end
    end

    if not skipSort then
        table.sort(visibleFrames, function(a, b)
            local aStart = a.startTime or math.huge
            local bStart = b.startTime or math.huge

            if aStart == bStart then
                return (a.sortIndex or 0) < (b.sortIndex or 0)
            end

            return aStart < bStart
        end)
    end

    local padding = self:GetBaseIconPadding()
    self:UpdateIconContainerLayout(#visibleFrames)
    
    if self.db.profile.orientation == "HORIZONTAL" then
        self:HorizontalLayout(visibleFrames, trackerFrame, padding)
    else
        self:VerticalLayout(visibleFrames, trackerFrame, padding)
    end
end
