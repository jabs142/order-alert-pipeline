local Utils = {}

-- Load Google service account credentials from JSON file
function Utils.loadCredentials(filepath)
    -- Protected call to handle missing file gracefully
    local success, file = pcall(io.open, filepath, "r")

    if not success or not file then
        iguana.logError("Failed to open credentials file: " .. filepath)
        return nil
    end

    local content = file:read("*all")
    file:close()

    -- Parse JSON to Lua table
    local parseSuccess, credentials = pcall(json.parse, {data=content})

    if not parseSuccess then
        iguana.logError("Failed to parse credentials JSON: " .. tostring(credentials))
        return nil
    end

    iguana.logInfo("Credentials loaded successfully from: " .. filepath)
    return credentials
end

return Utils
