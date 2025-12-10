# 📦 Order Alert Pipeline

> **Project Goal:** Build an end-to-end integration using IguanaX to process order data and send intelligent notifications

**Core Requirements:**
- Ingest incoming JSON messages via HTTP
- Process and filter the data
- Send notifications via Twilio (SMS alerts) AND Google Sheets (data logging)

---

## My Approach

### 1. Understanding the Requirements

**Key Questions:**

- **Why SMS only for orders >$300?**
  High-value purchases need immediate attention, similar to critical lab values in healthcare

- **Why both Google Sheets AND SMS?**
  Different purposes - audit trail vs real-time alerting

<br>

### 2. Identifying Knowledge Gaps

#### What is IguanaX?

**Resources:** IguanaX Setup Guide & Lua in Iguana Translator documentation

**Key Concepts:**
- An integration platform that sits between systems to help them communicate
- Component architecture: `Source → Translator → Destination`
  - **Source Components:** Receive data (HTTP listener, database reader, etc.)
  - **Data Components:** Transform/process data
  - **Destination Components:** Send data somewhere
- Components communicate by sending messages to each other
- Used to build custom integrations - ideal for teams that value independence and customization

<br>

**IguanaX and Healthcare:**

- **Why use it over Python/JavaScript in healthcare?**
  Built-in support for healthcare standards (HL7, FHIR), pre-built connectors, reliability features

- **Is IguanaX only for healthcare?**
  Primarily yes, but could be used for any system integration

<br>

**Healthcare Terminologies:**
- **HL7 v2:** Standard format for exchanging clinical data (lab results, patient admissions, etc.)
- **FHIR:** Modern RESTful API standard for healthcare data exchange

<br>

**What other technologies are there out there?**
<Picture here>

<br>

---

> 💡 **LLM Prompt Used for Learning**
>
> *"I'm a beginner and I want to learn about IguanaX. Cover the following clearly and simply, using analogies if helpful:*
>
> 1. **What is IguanaX?**
>    - Explain what it does in very simple terms
>    - Describe the core idea or problem it solves
>
> 2. **How does IguanaX work?**
>    - Give me a high-level mental model
>    - Don't assume I know anything beyond basic programming
>    - Use step-by-step breakdowns and examples
>
> 3. **What would *I* actually use IguanaX for?**
>    - Include concrete examples (e.g., small tasks, real-world use cases)
>
> 4. **What are common tools or frameworks that do similar things?**
>    - List at least 3 alternatives
>    - Explain how each compares in simple terms
>    - Tell me when I might choose them instead of IguanaX
>
> 5. **Wrap up with a short summary of 'If you remember only 3 things about IguanaX, remember this…'"**
>
> *Keep everything ELI5, friendly, and very beginner-oriented."*

---

#### How to integrate with Google Sheets API

**Learning Path:**
- Understand OAuth flow
- Research JWT structure
- Read Google Sheets API Docs

<br>

**Q: Why do we need OAuth if we already set up the service account?**

Credentials are like an ID card, but you still need to exchange them for an access token

<br>

**Q: Why build JWT from scratch instead of using a library?**

- IguanaX doesn't support popular JWT libraries (lua-resty-jwt requires OpenResty, luajwt needs C dependencies)
<Insert picture here>

<br>

#### How to integrate with Twilio

**Learning Path:**
- Read Twilio SMS API Docs
- Understand HTTP Basic Authentication
- Learn about form-encoded requests vs JSON

<br>

**Q: How is Twilio different from Google Sheets authentication?**

<Picture>

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
         │ does it for you                   │ you must do it
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

### 3. Implementation Decisions

**Modular Design:**
- Each file has one responsibility (separation of concerns)
- Makes testing and debugging easier
- Follows real-world software engineering best practices

**Performance Optimization:**
- Token caching (cache for 55 min, refresh 5 min early to avoid expiration)
- Reduced API calls


---

## 🏗️ Architecture

### Data Flow

```
External System
    ↓ HTTP POST (JSON order data)
IguanaX Component (main.lua)
    ├─→ utils.lua: Load credentials
    ├─→ google_auth.lua: Get OAuth token
    ├─→ google_sheets.lua: Log to spreadsheet ✅
    └─→ twilio_sms.lua: Send SMS ✅
```

<br>

### Component Breakdown

**main.lua** - Entry point that receives orders, validates them, logs everything to Google Sheets, and flags high-value orders for alerts

**Process Flow:**

1. Receives incoming order data via HTTP POST on port 8080
2. Validates the JSON order data (required fields, data types)
3. Authenticates with Google via OAuth (calls `google_auth.getAccessToken()`)
4. Logs all orders to Google Sheets (calls `google_sheets.appendRow()` with retry logic)
5. Identifies high-value orders (>$300) and sends SMS alerts via Twilio (calls `twilio_sms.sendSMS()` with retry logic)
6. Responds to the client with success/error status


---

## 🏥 Real World Healthcare Applications

### Why Log to Google Sheets?

- **Audit trail:** Compliance for financial/clinical transactions
- **Analytics:** Track trends and patterns
- **Backup:** Redundancy if primary database fails
- **Accessibility:** Non-technical staff can view in familiar interface

<br>

### Healthcare Adaptation Scenarios

#### Scenario 1: Prescription Monitoring System

**Use Case:** Detect potential drug abuse through repeat prescription patterns

**Flow:**
```
Pharmacy system POSTs prescription data
    → System tracks patient prescription history
    → Alert pharmacist/prescriber if high-risk pattern detected
```

<br>

**Example Trigger Conditions:**
- Patient fills same controlled substance (e.g., oxycodone, alprazolam) >3 times in 30 days
- Multiple prescribers for same medication class
- Early refills (>7 days before expected)
- "Doctor shopping" across multiple pharmacies

<br>

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

<br>

**Production Requirements:**
- PHI encryption at rest (AES) and in transit (TLS) per HIPAA security requirements
- Cross-pharmacy lookup to detect doctor shopping

<br>

#### Scenario 2: Lab Results Notification

**Use Case:** Critical lab values trigger immediate alerts

**Flow:**
```
Lab system POSTs results
    → Log to HIPAA-compliant DB
    → Alert physicians if critical
```

<br>

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

<br>

**Production Requirements:**
- EHR integration (Epic/Cerner)
- Allergy checking against patient history
- Override workflow for emergencies
- Drug interaction checking

<br>

### Production Improvements for Healthcare

For healthcare deployment, would add:

- **HIPAA Compliance:** Encrypted database, access controls, audit trails, PHI tokenization
- **Reliability:** Message queues (RabbitMQ, Kafka), redundancy, monitoring/alerting (PagerDuty)
- **Scalability:** Connection pooling, rate limiting, load balancing, horizontal scaling
- **Interoperability:** HL7 v2, FHIR, Epic, Cerner integration

---

## 🔧 Technical Deep Dive

### Why No JWT Library?

**Challenge:** IguanaX environment limitations

**Why popular libraries won't work:**
- `lua-resty-jwt` requires OpenResty (not compatible with IguanaX)
- `luajwt` needs LuaCrypto and C dependencies (complex setup)
- IguanaX doesn't have LuaRocks integration

**Solution:** Built from scratch following RFC 7515

**Benefits:**
- Demonstrates deep understanding of OAuth 2.0 flow
- No external dependencies
- Full control over implementation

> **Note:** In production with Epic/ServiceNow, would use vendor-provided libraries

<br>

---

## 🧪 Testing

### Test 1: Low-Value Order (Google Sheets Only)

**Test Case:** Order under $300 - should log to Sheets but not send SMS

```bash
curl -X POST http://localhost:8080 \
  -H "Content-Type: application/json" \
  -d @test-data/sample-order-low.json
```

**Expected Results:**
- ✅ Response: `{"status": "success", "order_id": "10001"}`
- ✅ Google Sheets: New row added with order details
- ✅ IguanaX Logs: "Order logged to Google Sheets"
- ❌ No SMS sent (order total is $150)

<br>

### Test 2: High-Value Order (Google Sheets + SMS)

**Test Case:** Order over $300 - should log to Sheets AND send SMS

```bash
curl -X POST http://localhost:8080 \
  -H "Content-Type: application/json" \
  -d @test-data/sample-order-high.json
```

**Expected Results:**
- ✅ Response: `{"status": "success", "order_id": "10002"}`
- ✅ Google Sheets: New row added with order details
- ✅ IguanaX Logs: "High-value order detected: $350 - Sending SMS"
- ✅ IguanaX Logs: "SMS sent successfully (MessageSID: SM...)"
- ✅ Phone receives SMS: "Your order #10002 has been processed successfully! Total: $350.00"
- ✅ Twilio Console: Message shows status "Delivered"

<br>

### Test 3: Invalid Data (Error Handling)

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
---

## 🎯 What we've accomplished

**Multi-API Integration:**
- ✅ Successfully integrated two different external APIs (Google Sheets + Twilio)
- ✅ Handled different auth mechanisms (OAuth 2.0 vs HTTP Basic Auth)
- ✅ Managed different data formats (JSON vs form-encoded)

**Robust Error Handling:**
- ✅ Retry logic with exponential backoff (1s, 2s, 4s)
- ✅ SMS failure doesn't block order processing
- ✅ Input validation
- ✅ Protected calls (`pcall`) prevent crashes

<br>

### Future Enhancements

- Message queue for guaranteed delivery
- HIPAA-compliant database for healthcare use
- Monitoring and alerting
- Rate limiting and circuit breaker
- Unit test
