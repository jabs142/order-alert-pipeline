# Order Alert Pipeline

**Criteria:** Build an end-to-end integration using IguanaX to:
- Ingest incoming JSON messages via HTTP
- Process and filter the data
- Send notifications via Twilio (SMS alerts) OR Google Sheets (data logging)


## My Approach

### 1. Understanding the Requirements

**Initial questions:**
- Why SMS only for orders >$300? (High-value purchases need immediate attention, similar to critical lab values in healthcare)
- Why both Google Sheets AND SMS? (Different purposes - audit trail vs real-time alerting)

### 2. Identifying Knowledge Gaps

**1. What is IguanaX?**

- Read: IguanaX Setup Guide & Lua in Iguana Translator documentation
- An integration platform that sits between systems to help them communicate
- Component architecture: Source → Translator → Destination
  - Source Components - Receive data (HTTP listener, database reader, etc.)
  - Data Components - Transform/process data
  - Destination Components - Send data somewhere
- Components communicate by sending messages to each other
- Used to build custom integrations - making it ideal for teams that value independence and customization

**IguanaX and Healthcare:**
- Why use it over Python/JavaScript in healthcare? Built-in support for healthcare standards (HL7, FHIR), pre-built connectors, reliability features
- Is IguanaX only for healthcare? Primarily yes, but could be used for any system integration

**Healthcare Terminologies:**
- **HL7 v2**: Standard format for exchanging clinical data (lab results, patient admissions, etc.)
- **FHIR**: Modern RESTful API standard for healthcare data exchange

**What other technologies are there out there?**
<Picture here>

<details>
<summary><b>LLM Prompt - What is IguanaX</b></summary>

**I'm a beginner and I want to learn about IguanaX. Cover the following clearly and simply, using analogies if helpful:**

1. **What is IguanaX?**
    - Explain what it does in very simple terms.
    - Describe the core idea or problem it solves.

2. **How does IguanaX work?**
    - Give me a high-level mental model.
    - Don't assume I know anything beyond basic programming.
    - Use step-by-step breakdowns and examples.

3. **What would *I* actually use IguanaX for?**
    - Include concrete examples (e.g., small tasks, real-world use cases).

4. **What are common tools or frameworks that do similar things?**
    - list at least 3 alternatives
    - explain how each compares in simple terms
    - tell me when I might choose them instead of IguanaX

5. **Wrap up with a short summary of "If you remember only 3 things about IguanaX, remember this…"**

**Keep everything ELI5, friendly, and very beginner-oriented.**

</details>

**2. How to integrate with Google Sheets API:**
- Understand OAuth flow 
- Researched JWT structure
- Read Google Sheets API Docs

**Why do we need OAuth if we already set up the service account?**
- Credentials are like an ID card, but you still need to exchange them for an access token

**Why build JWT from scratch instead of using a library?**
- IguanaX doesn't support popular JWT libraries (lua-resty-jwt requires OpenResty, luajwt needs C dependencies)
- Building from scratch demonstrates deep understanding of OAuth 2.0 flow

**3. How to integrate with Twilio:**
- Read Twilio SMS API Docs

### 3. Implementation Decisions

**Modular design:**
- Each file has one responsibility (separation of concerns)
- Makes testing and debugging easier
- Follows real-world software engineering best practices

**Performance:**
- Token caching (cache for 55 min, refresh 5 min early to avoid expiration)
- Reduced API calls


## Architecture

### Data Flow

```
External System
    ↓ HTTP POST (JSON order data)
IguanaX Component (main.lua)
    ├─→ utils.lua: Load credentials
    ├─→ google_auth.lua: Get OAuth token
    ├─→ google_sheets.lua: Log to spreadsheet 
    └─→ twilio_sms.lua: Send SMS ⏳
```

**main.lua** - Entry point that receives orders, validates them, logs everything to Google Sheets, and flags high-value orders for alerts:

1. Receives incoming order data via HTTP POST on port 8080
2. Validates the JSON order data (required fields, data types)
3. Authenticates with Google via OAuth (calls `google_auth.getAccessToken()`)
4. Logs all orders to Google Sheets (calls `google_sheets.appendRow()` with retry logic)
5. Identifies high-value orders (>$300) for SMS alerts (Twilio integration pending)
6. Responds to the client with success/error status


---

## Real World Healthcare Applications

### Why Log to Google Sheets?
- **Audit trail:** Compliance for financial/clinical transactions
- **Analytics:** Track trends and patterns
- **Backup:** Redundancy if primary database fails
- **Accessibility:** Non-technical staff can view in familiar interface

### Healthcare Adaptation Scenarios

#### Scenario 1: Prescription Monitoring System
**Use Case:** Detect potential drug abuse through repeat prescription patterns

Pharmacy system POSTs prescription data → System tracks patient prescription history → Alert pharmacist/prescriber if high-risk pattern detected

**Example trigger conditions:**
- Patient fills same controlled substance (e.g., oxycodone, alprazolam) >3 times in 30 days
- Multiple prescribers for same medication class
- Early refills (>7 days before expected)
- "Doctor shopping" across multiple pharmacies

**Data flow:**
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

**Production needs:**
- PHI should be encrypted at rest (for example, using strong algorithms such as AES) and in transit (for example, using secure transport protocols such as TLS) to reduce the risk of unauthorized access to sensitive patient data, in line with HIPAA’s security requirements and current industry best practices
- Cross-pharmacy lookup to detect doctor shopping

#### Scenario 2: Lab Results Notification
**Use Case:** Critical lab values trigger immediate alerts

Lab system POSTs results → Log to HIPAA-compliant DB → Alert physicians if critical

**Production needs:**
- PHI encryption at rest and in transit
- Audit logging for compliance
- Patient consent checks
- Integration with Epic/Cerner EHR systems

#### Scenario 3: Medication Alert System
**Use Case:** Prevent overdoses at point of administration

Nurse scans barcode → System validates dosage → Alert if exceeds safe limit

**Production needs:**
- EHR integration (Epic/Cerner)
- Allergy checking against patient history
- Override workflow for emergencies
- Drug interaction checking

### Production Improvements for Healthcare

For healthcare deployment, would add:
- **HIPAA Compliance:** Encrypted database, access controls, audit trails, PHI tokenization
- **Reliability:** Message queues (RabbitMQ, Kafka), redundancy, monitoring/alerting (PagerDuty)
- **Scalability:** Connection pooling, rate limiting, load balancing, horizontal scaling
- **Interoperability:** HL7 v2, FHIR, Epic, Cerner integration

---

## Technical Deep Dive

### Why No JWT Library?

- `lua-resty-jwt` requires OpenResty (not compatible with IguanaX)
- `luajwt` needs LuaCrypto and C dependencies (complex setup)
- IguanaX doesn't have LuaRocks integration
- Built from scratch following RFC 7515 - demonstrates deep understanding
- In production with Epic/ServiceNow, would use vendor libraries

**Future Enhancements:**
- Message queue for guaranteed delivery
- HIPAA-compliant database for healthcare use
- Monitoring and alerting
- Rate limiting and circuit breaker
- Unit test suite
