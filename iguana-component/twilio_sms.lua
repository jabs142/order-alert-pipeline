local TwilioSMS = {}

-- URL encode a string for form submission
-- Converts special characters to %XX format, spaces to +
local function urlEncode(str)
    if not str then return "" end

    str = string.gsub(str, "([^%w ])", function(c)
        return string.format("%%%02X", string.byte(c))
    end)

    str = string.gsub(str, " ", "+")

    return str
end

-- Build HTTP Basic Auth header
-- Format: "Basic base64(AccountSid:AuthToken)"
function TwilioSMS.buildBasicAuthHeader(accountSid, authToken)
    local credentials = accountSid .. ":" .. authToken
    local encodedCredentials = filter.base64.enc(credentials)
    return "Basic " .. encodedCredentials
end

-- Send SMS via Twilio API
-- Returns: success (boolean), messageSid or error (string)
function TwilioSMS.sendSMS(accountSid, authToken, toNumber, fromNumber, messageBody)
    -- Build API URL
    local apiUrl = string.format(
        "https://api.twilio.com/2010-04-01/Accounts/%s/Messages.json",
        accountSid
    )

    -- Build Authorization header
    local authHeader = TwilioSMS.buildBasicAuthHeader(accountSid, authToken)

    -- Build form-encoded request body
    local requestBody = "To=" .. urlEncode(toNumber) ..
                        "&From=" .. urlEncode(fromNumber) ..
                        "&Body=" .. urlEncode(messageBody)

    iguana.logInfo("Sending SMS to " .. toNumber)

    -- Make HTTP POST request
    local success, body, statusCode, headers = pcall(net.http.post, {
        url = apiUrl,
        body = requestBody,
        headers = {
            ["Authorization"] = authHeader,
            ["Content-Type"] = "application/x-www-form-urlencoded"
        },
        live = true
    })

    if not success then
        iguana.logError("SMS request failed: " .. tostring(body))
        return false, "Network error"
    end

    -- Check status code (201 = Created = Success for Twilio)
    if statusCode ~= 201 then
        iguana.logError("Twilio API error (HTTP " .. statusCode .. ")")

        -- Try to parse error response
        local parseSuccess, errorData = pcall(json.parse, {data=body})
        if parseSuccess and errorData.message then
            iguana.logError("Twilio error: " .. errorData.message)
            return false, errorData.message
        end

        return false, "HTTP " .. statusCode
    end

    -- Parse successful response
    local parseSuccess, responseData = pcall(json.parse, {data=body})

    if not parseSuccess then
        iguana.logError("Failed to parse Twilio response")
        return false, "Invalid response"
    end

    -- Extract message SID for tracking
    if responseData.sid then
        iguana.logInfo("SMS queued successfully (MessageSID: " .. responseData.sid .. ")")
        return true, responseData.sid
    else
        iguana.logError("No message SID in response")
        return false, "Missing SID"
    end
end

-- Retry wrapper with exponential backoff
function TwilioSMS.withRetry(func, maxRetries, accountSid, authToken, toNumber, fromNumber, messageBody)
    local attempt = 0

    while attempt <= maxRetries do
        attempt = attempt + 1

        iguana.logInfo("SMS attempt " .. attempt .. " of " .. (maxRetries + 1))

        local success, result = func(accountSid, authToken, toNumber, fromNumber, messageBody)

        if success and result then
            return true, result
        end

        -- If not last attempt, wait before retry
        if attempt <= maxRetries then
            local backoffSeconds = math.pow(2, attempt - 1)
            iguana.logInfo("Retrying in " .. backoffSeconds .. " seconds...")
            os.sleep(backoffSeconds * 1000)  -- Convert to milliseconds
        end
    end

    iguana.logError("SMS failed after " .. (maxRetries + 1) .. " attempts")
    return false, "Max retries exceeded"
end

return TwilioSMS
