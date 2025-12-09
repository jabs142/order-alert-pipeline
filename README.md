# Order Alert Pipeline

An end-to-end integration using IguanaX to process incoming order events and trigger automated notifications.

## Overview

This system receives order data via HTTP POST requests, logs all orders to Google Sheets, and sends SMS alerts via Twilio for high-value orders (total > $300).

## Architecture

```
External System → HTTP POST → IguanaX Component → Google Sheets (all orders)
                                    ↓
                            Twilio SMS (if total > $300)
```

## Features

- ✅ HTTP endpoint to receive order JSON
- ✅ JSON parsing and validation
- 🚧 Google Sheets integration (logging all orders)
- 🚧 Twilio SMS alerts for high-value orders
- 🚧 Error handling with retry logic
- 🚧 Comprehensive logging

## Technologies

- **IguanaX**: Integration platform
- **Lua**: Programming language
- **Google Sheets API**: Data logging
- **Twilio API**: SMS notifications

## Prerequisites

- IguanaX installed and running
- Google Cloud account (free tier)
- Twilio account (free trial)

## Setup Instructions

### 1. Install IguanaX

Download and install IguanaX from [interfaceware.com](https://www.interfaceware.com/)

### 2. Create IguanaX Component

1. Open IguanaX dashboard (http://localhost:7654)
2. Click "+ COMPONENT"
3. Select "Web Services and APIs" collection
4. Choose "Custom Blank"
5. Name it: `order-alert-service`
6. Copy the code from `iguana-component/main.lua` into the component

### 3. Set Up Google Sheets API

(Instructions to be added)

### 4. Set Up Twilio Account

(Instructions to be added)

## Testing

### Test with curl

Send a low-value order (no SMS):
```bash
curl -X POST http://localhost:8080 \
  -H "Content-Type: application/json" \
  -d @test-data/sample-order-low.json
```

Send a high-value order (triggers SMS):
```bash
curl -X POST http://localhost:8080 \
  -H "Content-Type: application/json" \
  -d @test-data/sample-order-high.json
```

Test error handling:
```bash
curl -X POST http://localhost:8080 \
  -H "Content-Type: application/json" \
  -d @test-data/sample-order-invalid.json
```

## Design Decisions

### Why IguanaX?
TBC

### Error Handling Strategy
Using `pcall()` for protected function calls to catch errors gracefully without crashing the component.

### Business Logic
- **All orders** are logged to Google Sheets for record-keeping
- **Only high-value orders** (total > $300) trigger SMS alerts to reduce notification fatigue

## Known Issues
TBC

## Future Improvements
TBC
