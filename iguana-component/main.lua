local utils = require('utils')
local google_auth = require('google_auth')
local google_sheets = require('google_sheets')
local twilio_sms = require('twilio_sms')

local CREDENTIALS = utils.loadCredentials('/Users/jabelle/Code/repos/order-alert-pipeline/credentials/order-alert-pipeline-97184e4676c4.json')
local SPREADSHEET_ID = "1qHZNx5CfLI5c_e31OnvtVHgS_5RxUUbkO067x6ZvXdg"

local TWILIO_CONFIG = {
   accountSid = CREDENTIALS.twilio.account_sid,
   authToken = CREDENTIALS.twilio.auth_token,
   fromNumber = CREDENTIALS.twilio.from_number
}

local Server = net.http.listen{
   port = 8080,
   main = main
}

function main(Data)
   -- Handle component initialization
   if Data == "INIT" then
      iguana.logInfo('Order Alert Service started on port 8080')
      return
   end

   -- Step 1: Parse HTTP request (pcall = protected call, prevents crashes on errors)
   local success, Request = pcall(net.http.parseRequest, {data=Data})
   if not success then
      iguana.logError('Invalid HTTP request')
      return
   end

   -- Step 2: Parse JSON order data from request body
   local parseSuccess, Order = pcall(json.parse, {data=Request.body})
   if not parseSuccess then
      iguana.logError('Invalid JSON in request body')
      return
   end

   -- Step 3: Data validation (defensive programming - validate at system boundaries)
   if not Order.order_id or not Order.customer or not Order.customer.name or
      not Order.customer.phone or not Order.total then
      iguana.logError('Missing required fields in order data')
      net.http.respond{
         body='{"status": "error", "message": "Missing required fields"}',
         entity_type='application/json'
      }
      return
   end

   -- Type checking (ensure total is number, not string)
   if type(Order.total) ~= "number" then
      iguana.logError('Order total must be a number')
      net.http.respond{
         body='{"status": "error", "message": "Invalid total value"}',
         entity_type='application/json'
      }
      return
   end

   iguana.logInfo('Order #' .. Order.order_id .. ' received - Total: $' .. Order.total)

   -- Step 4: Get OAuth access token (uses cached token if still valid)
   local accessToken = google_auth.getAccessToken(CREDENTIALS)

   -- Step 5: Log to Google Sheets (with retry logic - up to 3 attempts with exponential backoff)
   if accessToken then
      local success, result = google_sheets.withRetry(
         google_sheets.appendRow,
         3,
         accessToken,
         SPREADSHEET_ID,
         Order
      )

      if success then
         iguana.logInfo('Order #' .. Order.order_id .. ' logged to Google Sheets')
      else
         iguana.logError('Failed to log order #' .. Order.order_id .. ' to Sheets')
      end
   else
      iguana.logError('Failed to get access token')
   end

   -- Step 6: SMS alerts for high-value orders (> $300)
   if Order.total > 300 then
      iguana.logInfo('High-value order detected: $' .. Order.total .. ' - Sending SMS')

      local messageText = string.format(
         "Your order #%s has been processed successfully! Total: $%.2f",
         Order.order_id,
         Order.total
      )

      local smsSuccess, messageSid = twilio_sms.withRetry(
         twilio_sms.sendSMS,
         3,  -- Max 3 retries
         TWILIO_CONFIG.accountSid,
         TWILIO_CONFIG.authToken,
         Order.customer.phone,
         TWILIO_CONFIG.fromNumber,
         messageText
      )

      if smsSuccess then
         iguana.logInfo('SMS sent successfully (MessageSID: ' .. messageSid .. ')')
      else
         iguana.logError('Failed to send SMS after retries')
         -- Note: Order still logged to Google Sheets, SMS failure doesn't block
      end
   end

   -- Step 7: Always respond to client (even if Sheets logging failed)
   net.http.respond{
      body='{"status": "success", "order_id": "' .. Order.order_id .. '"}',
      entity_type='application/json'
   }
end
