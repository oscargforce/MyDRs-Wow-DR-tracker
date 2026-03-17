local addonName, addon = ...

local ProfileManager = {}
addon.ProfileManager = ProfileManager

local defaultConfig = {
    enableTestMode = false,
    containerPosition = { point = "CENTER", relativePoint = "CENTER", x = 0, y = 0 },
    iconPadding = 4,
    iconSize = 50,
    growIconsFromLeft = false,
    enableCooldownReverse = true,
    showCountdownText = true,
    fontSize = 16,
    cooldownSwipeAlpha = 1,
}

local profileMetaKeys = {
    _profiles = true,
    _charProfiles = true,
    _activeProfile = true,
    _activeCharacterKey = true,
    _schemaVersion = true,
}

local function deepCopy(value)
    if type(value) ~= "table" then
        return value
    end

    local copied = {}
    for k, v in pairs(value) do
        copied[k] = deepCopy(v)
    end
    return copied
end

local function mergeDefaults(target, defaults)
    for k, v in pairs(defaults) do
        if type(v) == "table" then
            target[k] = target[k] or {}
            mergeDefaults(target[k], v)
        else
            if target[k] == nil then
                target[k] = v
            end
        end
    end
end

local function getCharacterKey()
    local characterName, realmName = UnitFullName("player")
    characterName = characterName or UnitName("player")
    realmName = realmName or GetRealmName()

    if not characterName or characterName == "" then
        return nil
    end

    realmName = realmName or "UnknownRealm"
    realmName = realmName:gsub("%s+", "")
    return characterName .. "-" .. realmName
end

local function getSortedProfileNames()
    local profileNames = {}
    local profiles = OscarDrTrackerDB and OscarDrTrackerDB._profiles
    if not profiles then
        return profileNames
    end

    for profileName in pairs(profiles) do
        profileNames[#profileNames + 1] = profileName
    end

    table.sort(profileNames)
    return profileNames
end

local function sanitizeProfileName(profileName)
    if type(profileName) ~= "string" then
        return nil
    end

    profileName = profileName:gsub("^%s+", ""):gsub("%s+$", "")
    if profileName == "" then
        return nil
    end

    return profileName
end

local function setActiveProfile(profileName)
    profileName = sanitizeProfileName(profileName)
    if not OscarDrTrackerDB or not profileName then
        return
    end

    OscarDrTrackerDB._profiles = OscarDrTrackerDB._profiles or {}
    OscarDrTrackerDB._charProfiles = OscarDrTrackerDB._charProfiles or {}

    if not OscarDrTrackerDB._profiles[profileName] then
        OscarDrTrackerDB._profiles[profileName] = {}
    end

    mergeDefaults(OscarDrTrackerDB._profiles[profileName], defaultConfig)

    local characterKey = getCharacterKey() or OscarDrTrackerDB._activeCharacterKey
    if not characterKey then
        return
    end

    OscarDrTrackerDB._charProfiles[characterKey] = profileName
    OscarDrTrackerDB._activeCharacterKey = characterKey
    OscarDrTrackerDB._activeProfile = profileName
end

local function createProfile(profileName)
    profileName = sanitizeProfileName(profileName)
    if not profileName then
        return false, "Enter a profile name."
    end

    OscarDrTrackerDB = OscarDrTrackerDB or {}
    OscarDrTrackerDB._profiles = OscarDrTrackerDB._profiles or {}

    if OscarDrTrackerDB._profiles[profileName] then
        return false, "A profile with that name already exists."
    end

    OscarDrTrackerDB._profiles[profileName] = deepCopy(defaultConfig)
    setActiveProfile(profileName)
    return true
end

local function deleteProfile(profileName)
    profileName = sanitizeProfileName(profileName)
    if not profileName then
        return false, "Invalid profile name."
    end

    local profiles = OscarDrTrackerDB and OscarDrTrackerDB._profiles
    if not profiles or not profiles[profileName] then
        return false, "Profile not found."
    end

    local profileCount = 0
    for _ in pairs(profiles) do
        profileCount = profileCount + 1
    end

    if profileCount <= 1 then
        return false, "You cannot delete the last profile."
    end

    profiles[profileName] = nil

    local fallbackProfileName
    for name in pairs(profiles) do
        fallbackProfileName = name
        break
    end

    OscarDrTrackerDB._charProfiles = OscarDrTrackerDB._charProfiles or {}
    for characterKey, mappedProfileName in pairs(OscarDrTrackerDB._charProfiles) do
        if mappedProfileName == profileName then
            OscarDrTrackerDB._charProfiles[characterKey] = fallbackProfileName
        end
    end

    if OscarDrTrackerDB._activeProfile == profileName then
        setActiveProfile(fallbackProfileName)
    end

    return true
end

local function setDefaultConfig()
    OscarDrTrackerDB = OscarDrTrackerDB or {}

    local root = OscarDrTrackerDB
    local legacyValues = {}
    for key in pairs(defaultConfig) do
        local currentValue = rawget(root, key)
        if currentValue ~= nil then
            legacyValues[key] = deepCopy(currentValue)
        end
    end

    root._profiles = root._profiles or {}
    root._charProfiles = root._charProfiles or {}

    local characterKey = getCharacterKey() or root._activeCharacterKey
    if not characterKey then
        return
    end

    root._activeCharacterKey = characterKey

    local profileName = root._charProfiles[characterKey]
    if not profileName then
        profileName = characterKey
        root._charProfiles[characterKey] = profileName
    end

    local activeProfile = root._profiles[profileName]
    if not activeProfile then
        activeProfile = {}
        root._profiles[profileName] = activeProfile
    end

    local isLegacyMigration = root._schemaVersion == nil
    if isLegacyMigration then
        for key, value in pairs(legacyValues) do
            if activeProfile[key] == nil then
                activeProfile[key] = deepCopy(value)
            end
        end
    end

    for key in pairs(defaultConfig) do
        rawset(root, key, nil)
    end

    mergeDefaults(activeProfile, defaultConfig)

    root._activeProfile = profileName
    root._schemaVersion = 2

    setmetatable(root, {
        __index = function(tbl, key)
            if profileMetaKeys[key] then
                return rawget(tbl, key)
            end

            local profiles = rawget(tbl, "_profiles")
            local currentProfile = rawget(tbl, "_activeProfile")
            local profile = profiles and currentProfile and profiles[currentProfile]
            if profile then
                local value = profile[key]
                if value ~= nil then
                    return value
                end
            end

            return rawget(tbl, key)
        end,

        __newindex = function(tbl, key, value)
            if profileMetaKeys[key] then
                rawset(tbl, key, value)
                return
            end

            local profiles = rawget(tbl, "_profiles")
            local currentProfile = rawget(tbl, "_activeProfile")
            local profile = profiles and currentProfile and profiles[currentProfile]
            if profile then
                profile[key] = value
            else
                rawset(tbl, key, value)
            end
        end,
    })
end

ProfileManager.defaultConfig = defaultConfig
ProfileManager.getCharacterKey = getCharacterKey
ProfileManager.getSortedProfileNames = getSortedProfileNames
ProfileManager.setActiveProfile = setActiveProfile
ProfileManager.createProfile = createProfile
ProfileManager.deleteProfile = deleteProfile
ProfileManager.setDefaultConfig = setDefaultConfig
