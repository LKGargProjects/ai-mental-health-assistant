# GentleQuest API Documentation

## Base URL
- Production: `https://gentlequest.onrender.com`
- Local: `http://localhost:5055`

## Authentication
All authenticated endpoints require the `X-Session-ID` header.

```http
X-Session-ID: your-session-id-here
```

## Rate Limiting
- Global: 5000 requests/day, 1000 requests/hour per session
- Chat endpoints: 30 requests/minute
- Mood endpoints: 120 requests/minute
- Analytics: 120 requests/minute

Rate limit headers in responses:
- `X-RateLimit-Limit`: Maximum requests allowed
- `X-RateLimit-Remaining`: Requests remaining
- `X-RateLimit-Reset`: Unix timestamp when limit resets
- `Retry-After`: Seconds to wait (on 429 responses)

---

## Endpoints

### 🏥 Health & Monitoring

#### GET /api/health
Health check with system status.

**Response:**
```json
{
  "status": "healthy",
  "timestamp": "2025-01-01T00:00:00",
  "environment": "production",
  "database": "healthy",
  "redis": "healthy",
  "latency_ms": {
    "db_check": 45,
    "redis_check": 12
  },
  "endpoints": [...]
}
```

#### GET /api/ping
Lightweight keep-alive endpoint (no DB/Redis).

**Response:**
```json
{
  "ok": true,
  "ts": "2025-01-01T00:00:00"
}
```

#### GET /api/metrics
Prometheus-formatted metrics.

**Response:**
```
# HELP app_cpu_usage CPU usage percentage
# TYPE app_cpu_usage gauge
app_cpu_usage 45.2
...
```

---

### 🗨️ Chat

#### POST /api/chat
Send a chat message and get AI response.

**Request:**
```json
{
  "message": "I'm feeling anxious today"
}
```

**Response:**
```json
{
  "response": "I understand you're feeling anxious...",
  "risk_level": "low",
  "session_id": "uuid-here",
  "crisis_msg": null,
  "crisis_numbers": []
}
```

#### GET /api/chat_stream
Server-Sent Events stream for chat.

**Query Parameters:**
- `message` (required): User's message
- `session_id` (optional): Session ID
- `country` (optional): Country code for crisis resources

**Response:** SSE stream
```
data: {"type": "meta", "risk_level": "low", ...}
data: {"type": "token", "text": "I understand..."}
data: {"type": "done"}
```

#### GET /api/chat_history
Get chat history for session.

**Headers:**
- `X-Session-ID`: Required

**Response:**
```json
[
  {
    "content": "Hello",
    "is_user": true,
    "timestamp": "2025-01-01T00:00:00"
  },
  {
    "content": "Hello! How can I help?",
    "is_user": false,
    "timestamp": "2025-01-01T00:00:01"
  }
]
```

---

### 😊 Mood Tracking

#### POST /api/mood_entry
Add a mood entry.

**Request:**
```json
{
  "mood_level": 4,
  "note": "Feeling good after exercise",
  "timestamp": "2025-01-01T00:00:00"
}
```

**Response:**
```json
{
  "message": "Mood entry added successfully",
  "mood_level": 4,
  "note": "Feeling good after exercise",
  "timestamp": "2025-01-01T00:00:00"
}
```

#### GET /api/mood_history
Get mood history.

**Headers:**
- `X-Session-ID`: Required

**Response:**
```json
[
  {
    "mood_level": 4,
    "note": "Feeling good",
    "timestamp": "2025-01-01T00:00:00"
  }
]
```

#### GET /api/mood_analytics
Get mood analytics and trends.

**Headers:**
- `X-Session-ID`: Required

**Response:**
```json
{
  "analytics": {
    "average_mood": 3.5,
    "mood_trend": "improving",
    "total_entries": 25,
    "weekly_average": 3.8,
    "mood_distribution": {
      "level_1": 2,
      "level_2": 5,
      "level_3": 8,
      "level_4": 7,
      "level_5": 3
    }
  }
}
```

---

### 📋 Self-Assessment

#### POST /api/self_assessment
Submit daily self-assessment (once per day).

**Request:**
```json
{
  "mood": "good",
  "energy": "high",
  "sleep": "well",
  "stress": "low",
  "notes": "Had a productive day",
  "tz_offset_minutes": -330
}
```

**Response:**
```json
{
  "success": true,
  "already_completed_today": false,
  "xp_awarded": 10,
  "completed_at": "2025-01-01T00:00:00"
}
```

---

### 🚨 Crisis Detection

#### POST /api/crisis_detection
Analyze message for crisis indicators.

**Request:**
```json
{
  "message": "I'm struggling with dark thoughts"
}
```

**Response:**
```json
{
  "risk_level": "high",
  "risk_score": 0.85,
  "keywords": ["struggling", "dark thoughts"],
  "response": "I'm very concerned about what you're sharing...",
  "immediate_action_required": true,
  "resources": [
    {
      "name": "National Suicide Prevention Lifeline",
      "number": "988",
      "available": "24/7"
    }
  ]
}
```

---

### 🌟 Wellness

#### GET /api/wellness_recommendations
Get personalized wellness recommendations.

**Headers:**
- `X-Session-ID`: Required

**Response:**
```json
{
  "recommendations": [
    {
      "category": "mindfulness",
      "title": "5-Minute Breathing Exercise",
      "description": "A simple breathing technique...",
      "difficulty": "beginner"
    }
  ],
  "current_mood_average": 3.5,
  "analysis": "Your mood has been improving..."
}
```

---

### 👥 Community (Phase 0)

#### GET /api/community/feed
Get community feed (curated content).

**Query Parameters:**
- `limit` (optional): Number of items (default: 10, max: 50)
- `offset` (optional): Pagination offset
- `topic` (optional): Filter by topic

**Response:**
```json
{
  "items": [
    {
      "id": 1,
      "topic": "Mindfulness",
      "body": "Taking 5 minutes to breathe...",
      "created_at": "2025-01-01T00:00:00",
      "reactions": {
        "helped": 12,
        "relate": 8,
        "strength": 5
      }
    }
  ],
  "count": 10,
  "has_more": true
}
```

#### POST /api/community/react/:post_id
React to a community post.

**Request:**
```json
{
  "kind": "helped"
}
```

**Response:**
```json
{
  "success": true,
  "reactions": {
    "helped": 13,
    "relate": 8,
    "strength": 5
  }
}
```

#### POST /api/community/report
Report inappropriate content.

**Request:**
```json
{
  "target_type": "post",
  "target_id": 123,
  "reason": "inappropriate",
  "notes": "Contains triggering content"
}
```

**Response:**
```json
{
  "success": true,
  "report_id": "uuid-here"
}
```

---

### 📊 Analytics

#### POST /api/analytics/log
Log analytics event (requires consent).

**Headers:**
- `X-Session-ID`: Required
- `X-Analytics-Consent`: "true" (required for logging)

**Request:**
```json
{
  "event_type": "quest_complete",
  "metadata": {
    "quest_id": "mindfulness_1",
    "duration_ms": 180000,
    "xp_earned": 50
  }
}
```

**Response:**
```json
{
  "ok": true
}
```

#### GET /api/analytics/recent
Get recent analytics events (debug).

**Query Parameters:**
- `event_prefix` (optional): Filter by event type prefix
- `limit` (optional): Max results (default: 50, max: 200)

**Response:**
```json
{
  "events": [
    {
      "event_type": "quest_complete",
      "metadata": {...},
      "timestamp": "2025-01-01T00:00:00"
    }
  ],
  "count": 10,
  "elapsed_ms": 45
}
```

---

### 🔐 Session Management

#### GET /api/get_or_create_session
Get or create a session.

**Response:**
```json
{
  "session_id": "uuid-here"
}
```

---

### 🛠️ Admin Endpoints

#### POST /api/admin/purge
Purge old data (requires admin token).

**Headers:**
- `X-Admin-Token`: Admin API token

**Response:**
```json
{
  "success": true,
  "purged": {
    "messages_deleted": 150,
    "sessions_deleted": 30,
    "analytics_deleted": 500
  }
}
```

#### GET /api/admin/retention_config
View retention configuration.

**Headers:**
- `X-Admin-Token`: Admin API token

**Response:**
```json
{
  "message_retention_days": 30,
  "session_retention_days": 14,
  "analytics_retention_days": 90
}
```

---

## Error Codes

| Code | Description |
|------|-------------|
| 200 | Success |
| 201 | Created |
| 202 | Accepted (no consent) |
| 400 | Bad Request |
| 401 | Unauthorized |
| 404 | Not Found |
| 405 | Method Not Allowed |
| 429 | Rate Limit Exceeded |
| 500 | Internal Server Error |

## Error Response Format

```json
{
  "error": "Error message here",
  "details": "Additional context (optional)"
}
```

## SDKs and Examples

### JavaScript/TypeScript
```javascript
const API_BASE = 'https://gentlequest.onrender.com';
let sessionId = null;

async function initSession() {
  const response = await fetch(`${API_BASE}/api/get_or_create_session`);
  const data = await response.json();
  sessionId = data.session_id;
  return sessionId;
}

async function sendMessage(message) {
  const response = await fetch(`${API_BASE}/api/chat`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-Session-ID': sessionId
    },
    body: JSON.stringify({ message })
  });
  return response.json();
}
```

### Python
```python
import requests

class GentleQuestClient:
    def __init__(self, base_url='https://gentlequest.onrender.com'):
        self.base_url = base_url
        self.session_id = None
        
    def init_session(self):
        response = requests.get(f'{self.base_url}/api/get_or_create_session')
        self.session_id = response.json()['session_id']
        return self.session_id
        
    def send_message(self, message):
        response = requests.post(
            f'{self.base_url}/api/chat',
            json={'message': message},
            headers={'X-Session-ID': self.session_id}
        )
        return response.json()
```

### cURL
```bash
# Get session
SESSION_ID=$(curl -s https://gentlequest.onrender.com/api/get_or_create_session | jq -r .session_id)

# Send message
curl -X POST https://gentlequest.onrender.com/api/chat \
  -H "Content-Type: application/json" \
  -H "X-Session-ID: $SESSION_ID" \
  -d '{"message": "Hello"}'
```

---

## WebSocket Support (Coming Soon)

Future support for real-time features:
- Live chat streaming
- Real-time mood updates
- Community reactions
- Notification push

---

## Rate Limiting Best Practices

1. **Implement exponential backoff** on 429 responses
2. **Honor Retry-After header** when present
3. **Use session-based rate limiting** (pass X-Session-ID)
4. **Cache responses** when appropriate
5. **Batch requests** when possible

## Security

- All endpoints use HTTPS in production
- Session IDs expire after 14 days of inactivity
- Rate limiting prevents abuse
- Input validation on all endpoints
- SQL injection protection
- XSS prevention in responses

## Support

- GitHub: https://github.com/yourusername/gentlequest
- Email: support@gentlequest.app
- Status: https://status.gentlequest.app
