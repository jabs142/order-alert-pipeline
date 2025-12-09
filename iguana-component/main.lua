-- Receives order JSON via HTTP POST, logs to Google Sheets, sends SMS alerts

-- Set up HTTP listener
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

   -- Parse HTTP request (with error handling)
   local success, Request = pcall(net.http.parseRequest, {data=Data})
   if not success then
      iguana.logInfo('ERROR: Invalid HTTP request')
      return
   end

   -- Parse JSON order data
   local Order = json.parse{data=Request.body}

   -- Log order received
   iguana.logInfo('Order #' .. Order.order_id .. ' received - Total: $' .. Order.total)

   -- TODO: Log to Google Sheets (always)
   -- TODO: Check if total > 300 and send SMS

   -- Send success response
   net.http.respond{
      body='{"status": "success", "order_id": "' .. Order.order_id .. '"}',
      entity_type='application/json'
   }
end
