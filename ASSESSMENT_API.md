# Self-Assessment API Documentation

## Overview
The self-assessment feature allows users to submit structured mental health assessments that are stored in the PostgreSQL database.

## Endpoints

### POST /self_assessment
Submit a self-assessment entry.

**Headers:**
- `Content-Type: application/json`
- `X-Session-ID: <session_id>` (required)

**Request Body:**
```json
{
  "mood": "anxious|happy|depressed|mixed|calm|angry|sad",
  "energy": "very_low|low|medium|high|very_high",
  "sleep": "poor|interrupted|fair|good|excessive",
  "stress": "very_low|low|medium|high|very_high",
  "notes": "Optional text description",
  "crisis_level": "low|medium|high|none",
  "anxiety_level": "low|moderate|high|severe"
}
```

**Response:**
```json
{
  "success": true,
  "id": 1
}
```

**Status Codes:**
- `201`: Assessment created successfully
- `400`: Invalid request data or missing session ID
- `404`: Session not found
- `500`: Server error

## Example Usage

### 1. Create a Session
```bash
curl -X GET http://localhost:5055/api/get_or_create_session
```

### 2. Submit Assessment
```bash
curl -X POST http://localhost:5055/self_assessment \
  -H "Content-Type: application/json" \
  -H "X-Session-ID: your-session-id" \
  -d '{
    "mood": "anxious",
    "energy": "low",
    "sleep": "poor", 
    "stress": "high",
    "notes": "Feeling overwhelmed with work"
  }'
```

## Database Schema

The assessments are stored in the `self_assessment_entries` table:

```sql
CREATE TABLE self_assessment_entries (
    id SERIAL PRIMARY KEY,
    session_id VARCHAR(36) NOT NULL REFERENCES user_sessions(id),
    timestamp TIMESTAMP DEFAULT NOW(),
    assessment_data JSONB NOT NULL
);
```

## Features

✅ **Flexible Data Structure**: Uses JSONB to store any assessment data  
✅ **Session Management**: Links assessments to user sessions  
✅ **PostgreSQL Integration**: Full database persistence  
✅ **Error Handling**: Comprehensive error responses  
✅ **CORS Support**: Works with web applications  

## Testing

Run the test script to verify functionality:
```bash
python3 test_assessment.py
```

## Integration with Chat

The assessment data can be referenced in chat conversations to provide more personalized responses based on the user's self-reported mental state. 