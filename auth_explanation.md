# OAuth 2.0 & JWT Authentication 

## The Technical Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│                         OAuth 2.0 JWT Flow                          │
└─────────────────────────────────────────────────────────────────────┘

STEP 1: Check Cache
┌──────────────────┐
│ Need to call     │──┐
│ Google API       │  │
└──────────────────┘  │
                      ▼
                ┌──────────────┐      YES    ┌─────────────────┐
                │ Have cached  │────────────▶ │ Return cached   │
                │ token?       │              │ token (FAST!)   │
                └──────────────┘              └─────────────────┘
                      │ NO
                      ▼

STEP 2: Create JWT (JSON Web Token)
┌─────────────────────────────────────────────────────────────────┐
│                                                                   │
│   JWT Structure: [HEADER].[PAYLOAD].[SIGNATURE]                 │
│                                                                   │
│   ┌──────────────────┐  ┌──────────────────┐  ┌──────────────┐ │
│   │     HEADER       │  │     PAYLOAD      │  │  SIGNATURE   │ │
│   ├──────────────────┤  ├──────────────────┤  ├──────────────┤ │
│   │ {                │  │ {                │  │ Created by   │ │
│   │  "alg": "RS256", │  │  "iss": "...",   │  │ signing      │ │
│   │  "typ": "JWT"    │  │  "scope": "...", │  │ header +     │ │
│   │ }                │  │  "aud": "...",   │  │ payload with │ │
│   │                  │  │  "iat": 123,     │  │ PRIVATE KEY  │ │
│   │ Base64URL        │  │  "exp": 456      │  │              │ │
│   │ encoded          │  │ }                │  │ Base64URL    │ │
│   │                  │  │                  │  │ encoded      │ │
│   │                  │  │ Base64URL        │  │              │ │
│   │                  │  │ encoded          │  │              │ │
│   └──────────────────┘  └──────────────────┘  └──────────────┘ │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
                      │
                      ▼

STEP 3: Exchange JWT for Access Token
┌──────────────────┐              ┌────────────────────────────┐
│  POST JWT to     │──────────▶   │  Google OAuth Server       │
│  oauth2.         │              │  https://oauth2.           │
│  googleapis.com  │              │  googleapis.com/token      │
└──────────────────┘              └────────────────────────────┘
                                              │
                                              │ Verifies signature
                                              │ with public key
                                              ▼
                                  ┌────────────────────────────┐
                                  │  Response:                 │
                                  │  {                         │
                                  │    "access_token": "xyz",  │
                                  │    "expires_in": 3600      │
                                  │  }                         │
                                  └────────────────────────────┘
                                              │
                                              ▼

STEP 4: Cache Token for 55 Minutes
┌──────────────────────────────────────────────────────────────┐
│  Store in module-level variables:                            │
│  • cachedToken = "xyz"                                        │
│  • tokenExpiry = now + 3300 seconds (55 min)                 │
│                                                               │
│  Why 55 min instead of 60 min?                               │
│  → Refresh 5 min early to avoid expiration race conditions   │
└──────────────────────────────────────────────────────────────┘
                      │
                      ▼
              ┌─────────────────┐
              │ Return access   │
              │ token to caller │
              └─────────────────┘
```

---

## JWT Deep Dive: The Three Parts

### Part 1: Header - How is it signed? 
```json
{
  "alg": "RS256",    ← Signing algorithm (RSA with SHA-256)
  "typ": "JWT"       ← Token type
}
```

**What is this?**
- **JWT** = JSON Web Token - a standardized format for securely transmitting identity/claims
- **RS256** = RSA encryption with **SHA-256** hashing - the specific cryptographic method used to create the signature

**Purpose of the header:** Tells Google "this is a JWT" and "verify the signature using RS256"

When Google receives your token, it reads this header first to know how to validate it.

---

### Part 2: Payload (Claims)
```json
{
  "iss": "my-service@project.iam.gserviceaccount.com",  ← Issuer (who you are)
  "scope": "https://www.googleapis.com/auth/spreadsheets", ← What permission you want
  "aud": "https://oauth2.googleapis.com/token",         ← Audience (who this is for)
  "iat": 1735603200,                                    ← Issued at (timestamp)
  "exp": 1735606800                                     ← Expires at (1 hour later)
}
```

---

### Part 3: Signature

**How it's created:**
1. Take the encoded header and payload: `encodedHeader.encodedPayload`
2. Sign it with your **private key** using RSA-SHA256
3. Base64URL encode the signature

**Why this is secure:**
- Only you have the private key (stored in credentials file)
- Only you can create this valid signature
- Google has your public key (paired with private key)
- Google can verify the signature using the public key
- If someone changes even 1 character in header/payload, signature becomes invalid

---

## Key Security Concepts

### 1. **Asymmetric Cryptography (Public/Private Key Pair)**

**Simple explanation:**
- Private key = locks things only you can unlock
- Public key = lets others verify you locked it
- It's mathematically linked but you can't derive private from public

**In our case:**
- We sign with private key (only we can do this)
- Google verifies with public key (anyone can verify, but only we could create it)

### 2. **Why Not Just Send Credentials Every Time?**

❌ **Bad approach:**
```
Every API request → Send private key → Google verifies → Access granted
```
**Problems:**
- Private key transmitted constantly (more chances to intercept)
- Slow (crypto operations are expensive)
- Insecure (key could be logged, cached, stolen in transit)

✅ **Better approach (what we do):**
```
Once per hour → Send JWT (signed with private key) → Get access token → Use token for API calls
```
**Benefits:**
- Private key never transmitted (only signature sent)
- Fast (token is just a string, no crypto needed)
- Secure (token expires in 1 hour, limited damage if stolen)

### 3. **Token Caching**

**Without caching:**
- Every API request (every order!) → Create JWT → Network call to Google → Get token
- ~500ms per request

**With caching:**
- First request → Create JWT → Network call → Get token → Cache for 55 min
- Next 100+ requests → Use cached token (no JWT creation, no network call)
- ~50ms per request

---

### `GoogleAuth.exchangeJWT(jwt)`
**Purpose:** Trade JWT for access token

**Step-by-step:**
1. POST JWT to `https://oauth2.googleapis.com/token`
2. Google verifies signature with your public key
3. If valid, Google returns: `{"access_token": "...", "expires_in": 3600}`
4. Extract and return the access token
---

**Credentials file structure:**
```json
{
  "type": "service_account",
  "project_id": "...",
  "private_key": "-----BEGIN PRIVATE KEY-----\n...",  ← Used to sign JWTs
  "client_email": "...@....iam.gserviceaccount.com",   ← Your identity
  "client_id": "...",
  ...
}
```

---

## Summary: What Makes This Secure

✅ **Private key never leaves our system**
✅ **Tokens expire after 1 hour** (limited damage if stolen)
✅ **Scoped permissions** (only Google Sheets access)
✅ **Signature verification** (can't forge without private key)
✅ **Encrypted transmission** (HTTPS for all requests)
✅ **Credentials stored securely** (not in code, in .gitignore)

---

## What I'd Improve for Production

1. **Secret Management:** Use a secret manager (HashiCorp Vault, AWS Secrets Manager) instead of file
2. **Key Rotation:** Implement automatic key rotation every 90 days
3. **Monitoring:** Track auth failures, token refresh rates, unusual patterns
4. **Multiple Service Accounts:** Separate accounts for different environments (dev/staging/prod)
5. **Audit Logging:** Log all token creations and API calls for compliance
6. **Rate Limiting:** Prevent token refresh abuse
