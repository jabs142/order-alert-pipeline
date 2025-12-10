-- OAuth 2.0 authentication module for Google APIs

-- Why not use lua-resty-jwt or luajwt?
-- - lua-resty-jwt requires OpenResty/nginx (not compatible with IguanaX)
-- - luajwt requires LuaCrypto and C dependencies (complex setup)
-- - IguanaX doesn't have native LuaRocks integration
--
-- For production systems with Epic/ServiceNow:
-- - Use vendor-provided integration libraries (e.g., Epic Interconnect, ServiceNow REST API)
-- - Those platforms have built-in OAuth/JWT support
--
-- This implementation is intentionally simple and self-contained for this project

local GoogleAuth = {}

local cachedToken = nil
local tokenExpiry = 0

-- Convert Base64 to URL-safe format (required by JWT specification)
function GoogleAuth.base64UrlEncode(data)
    local encoded = filter.base64.enc(data)
    encoded = encoded:gsub('+', '-')
    encoded = encoded:gsub('/', '_')
    encoded = encoded:gsub('=', '')
    return encoded
end

-- Create signed JWT (JSON Web Token)
function GoogleAuth.createJWT(credentials)
    -- Header: declares token type and signing algorithm
    local header = {
        alg = "RS256",
        typ = "JWT"
    }

    local now = os.time()
    -- Payload: who you are (iss), what you want (scope), who to talk to (aud), when (iat/exp)
    local payload = {
        iss = credentials.client_email,
        scope = "https://www.googleapis.com/auth/spreadsheets",
        aud = "https://oauth2.googleapis.com/token",
        iat = now,
        exp = now + 3600  -- Token valid for 1 hour
    }

    local headerJson = json.serialize{data=header}
    local payloadJson = json.serialize{data=payload}

    local encodedHeader = GoogleAuth.base64UrlEncode(headerJson)
    local encodedPayload = GoogleAuth.base64UrlEncode(payloadJson)

    local headerPayload = encodedHeader .. "." .. encodedPayload

    -- Signature: cryptographic proof that you own the private key
    -- Only we can create this signature; Google verifies with public key
    local signature = crypto.sign{
        data = headerPayload,
        key = credentials.private_key,
        algorithm = 'sha256WithRSAEncryption'
    }

    local encodedSignature = GoogleAuth.base64UrlEncode(signature)
    return headerPayload .. "." .. encodedSignature
end

-- Exchange JWT for access token
-- JWT proves identity; access token is temporary "ticket" to use APIs
function GoogleAuth.exchangeJWT(jwt)
    local tokenUrl = "https://oauth2.googleapis.com/token"
    local body = "grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=" .. jwt

    local success, responseBody, statusCode, headers = pcall(net.http.post, {
        url = tokenUrl,
        body = body,
        headers = {["Content-Type"] = "application/x-www-form-urlencoded"},
        live = true
    })

    if not success then
        iguana.logError("Token request failed: " .. tostring(responseBody))
        return nil
    end

    if statusCode ~= 200 then
        iguana.logError("Token exchange failed (HTTP " .. statusCode .. ")")
        return nil
    end

    if not responseBody or responseBody == "" then
        iguana.logError("Empty response from OAuth server")
        return nil
    end

    local parseSuccess, responseData = pcall(json.parse, {data=responseBody})

    if not parseSuccess then
        iguana.logError("Failed to parse OAuth response")
        return nil
    end

    if responseData and responseData.access_token then
        return responseData.access_token
    else
        if responseData and responseData.error then
            iguana.logError("OAuth error: " .. tostring(responseData.error))
        end
        return nil
    end
end

-- Main function: Get access token (with caching for performance)
-- Check cache first, only create new JWT if expired
function GoogleAuth.getAccessToken(credentials)
    local now = os.time()

        -- Return cached token if still valid
    if cachedToken and now < tokenExpiry then
        return cachedToken
    end

    -- Create new JWT and exchange for access token
    local jwt = GoogleAuth.createJWT(credentials)
    if not jwt then
        return nil
    end

    local token = GoogleAuth.exchangeJWT(jwt)

    if token then
        cachedToken = token
        tokenExpiry = now + 3300  -- Cache for 55 min (refresh 5 min early to avoid expiration)
        iguana.logInfo("Access token obtained and cached")
        return token
    end

    return nil
end

return GoogleAuth
