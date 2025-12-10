local GoogleSheets = {}

-- Append a single row to Google Sheets
function GoogleSheets.appendRow(accessToken, spreadsheetId, orderData)
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")

    -- Format row data: [order_id, name, phone, total, timestamp]
    local row = {
        orderData.order_id,
        orderData.customer.name,
        orderData.customer.phone,
        tostring(orderData.total),
        timestamp
    }

    local requestBody = {values = {row}}

    -- A1 notation: Sheet1!A:E = columns A through E
    -- :append = add to next empty row
    -- valueInputOption=RAW = insert as-is (don't interpret formulas)
    local apiUrl = string.format(
        "https://sheets.googleapis.com/v4/spreadsheets/%s/values/Sheet1!A:E:append?valueInputOption=RAW",
        spreadsheetId
    )

    local success, body, code, headers = pcall(net.http.post, {
        url = apiUrl,
        body = json.serialize{data=requestBody},
        headers = {
            ["Authorization"] = "Bearer " .. accessToken,
            ["Content-Type"] = "application/json"
        },
        live = true
    })

    if not success then
        iguana.logError("Sheets API request failed: " .. tostring(body))
        return false, body
    end

    if code ~= 200 then
        iguana.logError("Sheets API error (HTTP " .. code .. ")")
        return false, "HTTP " .. code
    end

    local parseSuccess, responseData = pcall(json.parse, {data=body})
    if not parseSuccess then
        iguana.logError("Failed to parse Sheets API response")
        return false, responseData
    end

    if responseData.updates and responseData.updates.updatedRows then
        iguana.logInfo("Added " .. responseData.updates.updatedRows .. " row(s) to Google Sheet")
        return true, responseData
    end

    return false, "Unexpected response"
end

-- Retry logic with exponential backoff 
function GoogleSheets.withRetry(func, maxRetries, accessToken, spreadsheetId, orderData)
    local attempt = 0

    while attempt <= maxRetries do
        attempt = attempt + 1
        local success, result = func(accessToken, spreadsheetId, orderData)

        if success and result then
            if attempt > 1 then
                iguana.logInfo("Retry succeeded on attempt " .. attempt)
            end
            return true, result
        end

        -- Exponential backoff: wait 1s, 2s, 4s (don't overwhelm a failing server)
        if attempt <= maxRetries then
            local backoffSeconds = math.pow(2, attempt - 1)
            iguana.logInfo("Retry " .. attempt .. "/" .. maxRetries .. " after " .. backoffSeconds .. "s")
            os.sleep(backoffSeconds * 1000)
        else
            iguana.logError("Max retries exceeded")
            return false, result
        end
    end

    return false, "Max retries exceeded"
end

return GoogleSheets
