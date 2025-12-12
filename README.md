# 📦 Order Alert Pipeline Using IguanaX with Google Sheets & Twilio Integrations 
<br>

## 🎯 Agenda:
- Introduction (5 min)
- Demo (5 min)
- My approach to the task (15 min)
- Learnings & Improvements (5 min)
- QnA & Discussions 


<br>
<br>


## Project Goal: Build an end-to-end integration using IguanaX to process order data and send intelligent notifications
<br>
<br>

**Core Requirements:**
- Ingest incoming JSON messages via HTTP
- Process and filter the data
- Send notifications via Twilio (SMS alerts) AND Google Sheets (data logging)

<br>
<br>

**Output**

Test case: High-Value Order (Google Sheets + SMS)

**Test Case:** Order over $300 - should log to Sheets and send SMS

```
{
  "order_id": "10002",
  "customer": {
    "name": "Jane Doe",
    "phone": "+6597822466"
  },
  "total": 350.00
}
```


Run
```bash
curl -X POST http://localhost:8080 \
  -H "Content-Type: application/json" \
  -d @test-data/sample-order-high.json
```

Google Sheets ouput:

<img width="718" height="222" alt="image" src="https://github.com/user-attachments/assets/f9f1175d-26ee-4dc7-a886-137d2f7ee028" />

<br>
<br>

Twilio SMS: 

<img width="322" height="143" alt="image" src="https://github.com/user-attachments/assets/dd1a3d30-dc43-4cb4-9617-17ab23eb15aa" />

<br>
<br>

IguanaX Logs: 

<img width="860" height="806" alt="image" src="https://github.com/user-attachments/assets/5365f636-8d77-49ec-9654-20b1eb106f3e" />

<br>
<br>
<br>

# How I approached the task

## 1. Understanding the Requirements

**Key Questions:**

- **Why SMS only for orders >$300?**
  - High-value purchases need immediate attention, similar to critical lab values in healthcare

- **Why both Google Sheets AND SMS?**
  - Different purposes - audit trail vs real-time alerting

<br>
<br>

## 2. Identifying Knowledge Gaps

### A. What is IguanaX?

- Read IguanaX Setup Guide & Lua in Iguana Translator documentation
- An integration platform that sits between systems to help them communicate
- Component architecture: `Source → Translator → Destination`
  - **Source Components:** Receive data (HTTP listener, database reader, etc.)
  - **Data Components:** Transform/process data
  - **Destination Components:** Send data somewhere
- Components communicate by sending messages to each other
- Used to build custom integrations - ideal for teams that value independence and customization

<br>

**IguanaX and Healthcare:**

- **Q: Why use it over Python/JavaScript in healthcare?**
  Built-in support for healthcare standards (HL7, FHIR), pre-built connectors, reliability features
  Python/JavaScript are more flexible but require more effort to achieve the same level of reliability and monitoring for integration-heavy tasks.

- **Q: Is IguanaX only for healthcare?**
  It can be used for any system-to-system communication, data routing, and workflow automation. But it's used particularly with structured message standards like HL7 in healthcare.

<br>

**Healthcare Terminologies:**
- **HL7 v2:** Standard format for exchanging clinical data (lab results, patient admissions, etc.)
- **FHIR:** Modern RESTful API standard for healthcare data exchange

<br>

**What other technologies are there out there?**

<img width="729" height="282" alt="image" src="https://github.com/user-attachments/assets/6acb6f40-9ea6-4e1d-98a4-fd2b4248ca9a" />

<br>

<details>
<summary>💡 <b>LLM Prompt Used for Learning</b></summary>

```
"I'm a beginner and I want to learn about IguanaX. Cover the following clearly and simply, using analogies if helpful:

1. What is IguanaX?
   - Explain what it does in very simple terms
   - Describe the core idea or problem it solves

2. How does IguanaX work?
   - Give me a high-level mental model
   - Don't assume I know anything beyond basic programming
   - Use step-by-step breakdowns and examples

3. What would *I* actually use IguanaX for?
   - Include concrete examples (e.g., small tasks, real-world use cases)

4. What are common tools or frameworks that do similar things?
   - List at least 3 alternatives
   - Explain how each compares in simple terms
   - Tell me when I might choose them instead of IguanaX

5. Wrap up with a short summary of 'If you remember only 3 things about IguanaX, remember this…'

Keep everything ELI5, friendly, and very beginner-oriented."
```

</details>

<br>
<br>
<br>

### B. How to integrate with Google Sheets API

**Learnings:**
- Read Google Sheets API Docs
- Understand OAuth flow
- Understand JWT structure

<br>

**Q: Why do we need OAuth if we already set up the service account?**

Even though you don’t have a human user logging in, Google still needs a secure and standardized way to verify who is calling its APIs and what permissions they should have.

1. Service account → creates and signs a JWT
2. Sends JWT to Google’s OAuth endpoint
3. OAuth endpoint → returns access token
4. Access token → used to call the Sheets API

<br>

**Q: Why Log to Google Sheets?**

- **Audit trail:** Compliance for financial/clinical transactions
- **Analytics:** Track trends and patterns
- **Backup:** Redundancy if primary database fails
- **Accessibility:** Non-technical staff can view in familiar interface

<br>

**Q: Why build JWT from scratch instead of using a library?**

- IguanaX doesn't support popular JWT libraries (lua-resty-jwt requires OpenResty, luajwt needs C dependencies)
<img width="732" height="494" alt="image" src="https://github.com/user-attachments/assets/8e7ccf69-3192-450a-b4f1-9a194e00d553" />


<br>
<br>
<br>

### C. How to integrate with Twilio

**Learnings:**
- Read Twilio SMS API Docs
- Understand HTTP Basic Authentication
- Learn about form-encoded requests vs JSON

<br>
<br>

**Q: How is Twilio different from Google Sheets authentication?**

<img width="660" height="618" alt="image" src="https://github.com/user-attachments/assets/1aa7d177-d91b-47be-86f9-ccc600d9b39f" />


```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│   "Hi Jane! Order #123 ($50) is ready."                     │
└─────────────────────────────────────────────────────────────┘
                           │
         ┌─────────────────┴─────────────────┐
         │                                   │
    ┌────▼────┐                         ┌────▼────┐
    │  JSON   │                         │  FORM   │
    │ (Auto)  │                         │ (Manual)│
    └────┬────┘                         └────┬────┘
         │                                   │
         │ json.serialize()                  │ urlEncode()
         │                                   │
         ▼                                   ▼
    {"message":                         Body=Hi+Jane%21+Order+
     "Hi Jane!                          %23123+%28%2450%29+
      Order #123                        is+ready.
      ($50) is
      ready."}
         │                                   │
         │                                   │
         ▼                                   ▼
    Google Sheets API                   Twilio API
```

<br>
<br>

**Q: Why does Twilio use URL encoding?**

Twilio API is older and expects form-encoded data (like HTML form submission), so special characters must be URL-encoded:
- Space → `+` or `%20`
- `#` → `%23`
- `&` → `%26`

This is different from Google Sheets which uses JSON (automatically handles encoding).

Google Sheets API is modern and uses JSON because:
JSON handles special characters automatically - you don't need to encode manually
JSON is easier to read and write
JSON can represent complex nested data (like lists within lists)

<br>
<br>
<br>

## 🏗️ Architecture

### Data Flow

```
External System
    ↓ HTTP POST (JSON order data)
IguanaX Component (main.lua) - Entry point that receives orders, validates them, logs everything to Google Sheets, and flags high-value orders for alerts
    ├─→ utils.lua: Load Google service account credentials from JSON file
    ├─→ google_auth.lua: Get OAuth token
    ├─→ google_sheets.lua: Log to google spreadsheet ✅
    └─→ twilio_sms.lua: Send SMS with Twilio ✅
```

<br>
<br>

**Process Flow:**

1. Receives incoming order data via HTTP POST on port 8080
2. Validates the JSON order data (required fields, data types)
3. Authenticates with Google via OAuth (calls `google_auth.getAccessToken()`)
4. Logs all orders to Google Sheets (calls `google_sheets.appendRow()` with retry logic)
5. Identifies high-value orders (>$300) and sends SMS alerts via Twilio (calls `twilio_sms.sendSMS()` with retry logic)
6. Responds to the client with success/error status


<br>
<br>
<br>


# 🏥 Real World Healthcare Applications

<br>



### Scenario 1: Prescription Monitoring System

**Use Case:** Detect potential drug abuse through repeat prescription patterns

**Flow:**
```
Pharmacy system POSTs prescription data
    → System tracks patient prescription history
    → Alert pharmacist/prescriber if high-risk pattern detected
```

**Example Trigger Conditions:**
- Patient fills same controlled substance (e.g., oxycodone, alprazolam) >3 times in 30 days
- Multiple prescribers for same medication class
- Early refills (>7 days before expected)
- "Doctor shopping" across multiple pharmacies

**Sample Data Payload:**
```json
{
  "patient_id": "P12345",
  "medication": "Oxycodone 10mg",
  "prescriber_id": "DR789",
  "pharmacy_id": "PH456",
  "fill_date": "2024-01-15",
  "days_supply": 30,
  "refill_number": 4
}
```

**Production Requirements:**
- PHI encryption at rest (AES) and in transit (TLS) per HIPAA security requirements
- Cross-pharmacy lookup to detect doctor shopping
<br>
<br>
<br>

### Scenario 2: Lab Results Notification

**Use Case:** Critical lab values trigger immediate alerts

**Flow:**
```
Lab system POSTs results
    → Log to HIPAA-compliant DB
    → Alert physicians if critical
```

**Example Trigger Conditions:**
- Potassium >6.0 mEq/L (hyperkalemia - cardiac risk)
- Glucose <50 mg/dL (severe hypoglycemia)
- Troponin >0.4 ng/mL (possible heart attack)
- INR >5.0 (high bleeding risk for patients on warfarin)
- Creatinine increase >50% from baseline (acute kidney injury)

**Sample Data Payload:**
```json
{
  "patient_id": "P67890",
  "patient_name": "Sarah Johnson",
  "mrn": "MRN123456",
  "test_name": "Potassium",
  "result_value": 6.5,
  "result_unit": "mEq/L",
  "normal_range": "3.5-5.0",
  "status": "critical",
  "collection_time": "2025-12-11T14:30:00Z",
  "result_time": "2025-12-11T15:45:00Z",
  "ordering_physician": "DR-Smith-4521",
  "location": "ICU-3-Bed-12"
}
```

**Production Requirements:**
- PHI encryption at rest and in transit
- Audit logging for compliance
- Patient consent checks
- Integration with Epic/Cerner EHR systems

<br>

#### Scenario 3: Medication Alert System

**Use Case:** Prevent overdoses at point of administration

**Flow:**
```
Nurse scans barcode
    → System validates dosage
    → Alert if exceeds safe limit
```

**Example Trigger Conditions:**
- Dose exceeds maximum daily limit (e.g., >4000mg acetaminophen/day)
- Dose exceeds weight-based maximum (pediatric patients)
- Medication on patient's allergy list
- Drug-drug interaction detected (e.g., warfarin + aspirin)
- Duplicate therapy (same drug class already administered)
- Frequency violation (dose given too soon after previous dose)

**Sample Data Payload:**
```json
{
  "patient_id": "P24680",
  "patient_name": "Michael Chen",
  "mrn": "MRN789012",
  "patient_weight_kg": 75,
  "medication_name": "Morphine Sulfate",
  "dose_amount": 15,
  "dose_unit": "mg",
  "route": "IV",
  "scheduled_time": "2025-12-11T16:00:00Z",
  "nurse_id": "RN-Williams-7834",
  "barcode_scanned": "MED-MORPH-15MG-001234",
  "location": "Med-Surg-2-Room-215",
  "previous_doses_24h": [
    {"time": "2025-12-11T12:00:00Z", "amount": 10, "unit": "mg"},
    {"time": "2025-12-11T08:00:00Z", "amount": 10, "unit": "mg"}
  ],
  "patient_allergies": ["Codeine", "Penicillin"]
}
```

**Production Requirements:**
- EHR integration (Epic/Cerner)
- Allergy checking against patient history
- Override workflow for emergencies
- Drug interaction checking
<br>
<br>
<br>

### Production Improvements for Healthcare

For healthcare deployment, would add:

- **HIPAA Compliance:** Encrypted database, access controls, audit trails, PHI tokenization
- **Reliability:** Message queues (RabbitMQ, Kafka), redundancy, monitoring/alerting (PagerDuty)
- **Scalability:** Connection pooling, rate limiting, load balancing, horizontal scaling
- **Interoperability:** HL7 v2, FHIR, Epic, Cerner integration

<br>
<br>
<br>


# 🔧 Technical

## Logging in IguanaX

**Automatic Timestamps:**

IguanaX automatically adds timestamps to `iguana.logInfo()` and `iguana.logError()` calls. You don't need to manually add them to your log messages.

**Example log output in IguanaX:**
```
2025-12-11 14:23:45 - INFO: Order #12345 received - Total: $350
2025-12-11 14:23:46 - INFO: High-value order detected: $350 - Sending SMS
2025-12-11 14:23:47 - INFO: SMS sent successfully (MessageSID: SM...)
```

**Code that generates these logs** (main.lua:62, 88, 107):
```lua
iguana.logInfo('Order #' .. Order.order_id .. ' received - Total: $' .. Order.total)
iguana.logInfo('High-value order detected: $' .. Order.total .. ' - Sending SMS')
iguana.logInfo('SMS sent successfully (MessageSID: ' .. messageSid .. ')')
```

<br>
<br>

### B. Lua Transformations & HTTP Calls

**Requirement:** Use Lua for data transformation and HTTP calls

#### Data Transformation Example

**BEFORE (Raw JSON string):**
```json
{
  "order_id": "12345",
  "customer": {
    "name": "Jane Doe",
    "phone": "+15551234567"
  },
  "total": 350.00
}
```

**TRANSFORMATION #1: JSON → Lua Table** (main.lua:35)
```lua
-- Parse JSON string into Lua data structure
local parseSuccess, Order = pcall(json.parse, {data=Request.body})

-- Now Order is a Lua table:
-- Order.order_id = "12345"
-- Order.customer.name = "Jane Doe"
-- Order.customer.phone = "+15551234567"
-- Order.total = 350.00
```

**TRANSFORMATION #2: Lua Table → SMS Message String** (main.lua:90-94)
```lua
local messageText = string.format(
    "Your order #%s has been processed successfully! Total: $%.2f",
    Order.order_id,
    Order.total
)
-- Result: "Your order #12345 has been processed successfully! Total: $350.00"
```

**TRANSFORMATION #3: Lua Table → Google Sheets Row** (google_sheets.lua:8-14)
```lua
-- Transform order data into spreadsheet row format
local row = {
    orderData.order_id,           -- "12345"
    orderData.customer.name,      -- "Jane Doe"
    orderData.customer.phone,     -- "+15551234567"
    tostring(orderData.total),    -- "350.00"
    timestamp                     -- "2025-12-11 14:23:45"
}
```
<br>
<br>

### C. Using Iguana's Net Module for HTTP Requests

**Requirement:** Use Iguana's Net module (`net.http`) for HTTP requests

### Example 1: Google Sheets API Call (google_sheets.lua:26-34)

```lua
-- POST request to Google Sheets API
local success, body, code, headers = pcall(net.http.post, {
    url = apiUrl,
    body = json.serialize{data=requestBody},
    headers = {
        ["Authorization"] = "Bearer " .. accessToken,
        ["Content-Type"] = "application/json"
    },
    live = true  -- Required for external API calls
})
```

**What this does:**
- `net.http.post` is IguanaX's built-in HTTP client
- Sends JSON data to Google Sheets API
- Returns: `success` (boolean), `body` (response), `code` (HTTP status), `headers`

<br>

### Example 2: Twilio SMS API Call (twilio_sms.lua:46-54)

```lua
-- POST request to Twilio API
local success, body, statusCode, headers = pcall(net.http.post, {
    url = apiUrl,
    body = requestBody,  -- Form-encoded string
    headers = {
        ["Authorization"] = authHeader,  -- HTTP Basic Auth
        ["Content-Type"] = "application/x-www-form-urlencoded"
    },
    live = true
})
```

**What this does:**
- Same `net.http.post` function, different data format
- Sends form-encoded data (not JSON) to Twilio
- Uses HTTP Basic Authentication (Base64-encoded credentials)

<br>

### Example 3: Responding to HTTP Requests (main.lua:115-118)

```lua
-- Send HTTP response back to the client
net.http.respond{
    body='{\"status\": \"success\", \"order_id\": \"' .. Order.order_id .. '\"}',
    entity_type='application/json'
}
```

**What this does:**
- `net.http.respond` sends the HTTP response back to the client
- Returns JSON with order confirmation

<br>


<br>
<br>
<br>



## 🧪 Testing

**Test Case:** Malformed request - should return error without crashing

```bash
curl -X POST http://localhost:8080 \
  -H "Content-Type: application/json" \
  -d @test-data/sample-order-invalid.json
```

**Expected Results:**
- ✅ Response: `{"status": "error", "message": "Missing required fields"}`
- ✅ IguanaX Logs: "Missing required fields in order data"
- ❌ No Google Sheets entry
- ❌ No SMS sent

<br>

**IguanaX Logs (Error Handling):**

<img width="861" height="126" alt="image" src="https://github.com/user-attachments/assets/02f9dd94-a3b4-4b66-86e6-51f1b390966e" />


<br>

**cURL Response:**

```
{"status": "error", "message": "Missing required fields"}%
```


<br>
<br>
<br>
<br>


## 🎯 What we've accomplished

**Multi-API Integration:**
- ✅ Successfully integrated two different external APIs (Google Sheets + Twilio)
- ✅ Handled different auth mechanisms (OAuth 2.0 vs HTTP Basic Auth)
- ✅ Managed different data formats (JSON vs form-encoded)

**Error Handling:**
- ✅ Retry logic with exponential backoff (1s, 2s, 4s)
- ✅ SMS failure doesn't block order processing
- ✅ Input validation (Missing inputs, type check)
- ✅ Protected calls (`pcall`) prevent crashes

<br>
<br>

## 🎯 Future Enhancements

- Message queue for guaranteed delivery
- HIPAA-compliant database for healthcare use
- Monitoring and alerting
- Rate limiting and circuit breaker
- Unit test






