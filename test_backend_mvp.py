#!/usr/bin/env python3
"""
Backend MVP Readiness Test
- Validates /api/health
- Validates /api/chat_stream (SSE) safely using provider fallback (no external AI calls required)

Usage:
  BASE_URL=http://localhost:5055 python3 test_backend_mvp.py

Exit codes:
  0 on success, 1 on failure
"""
import os
import sys
import json
import time
import uuid
import requests
from typing import List, Dict, Any

BASE_URL = os.environ.get("BASE_URL", "http://localhost:5055").rstrip("/")

OK = "✅"
FAIL = "❌"
INFO = "ℹ️"


def print_info(msg: str) -> None:
    print(f"{INFO} {msg}")


def print_ok(msg: str) -> None:
    print(f"{OK} {msg}")


def print_fail(msg: str) -> None:
    print(f"{FAIL} {msg}")


def test_health() -> bool:
    print_info(f"Testing /api/health at {BASE_URL} ...")
    try:
        r = requests.get(f"{BASE_URL}/api/health", timeout=8)
        if r.status_code != 200:
            print_fail(f"/api/health HTTP {r.status_code}")
            return False
        data = r.json()
        # Required keys
        required = ["status", "environment", "deployment", "endpoints"]
        missing = [k for k in required if k not in data]
        if missing:
            print_fail(f"/api/health missing keys: {missing}")
            return False
        if data.get("status") != "healthy":
            print_fail(f"/api/health status != healthy: {data.get('status')}")
            return False
        endpoints = data.get("endpoints", []) or []
        if "/api/chat_stream" not in endpoints:
            print_fail("/api/health endpoints does not list /api/chat_stream")
            return False
        # Optional: show DB/Redis status for visibility
        print_ok("/api/health returned healthy with required fields")
        print_info(f"Environment: {data.get('environment')}, Provider: {data.get('provider')}")
        print_info(f"DB: {data.get('database')}, Redis: {data.get('redis')}")
        return True
    except Exception as e:
        print_fail(f"/api/health error: {e}")
        return False


def test_chat_stream_missing_message() -> bool:
    print_info("Testing /api/chat_stream missing message (should 400) ...")
    try:
        r = requests.get(f"{BASE_URL}/api/chat_stream", timeout=5)
        if r.status_code == 400:
            try:
                err = r.json().get("error")
            except Exception:
                err = None
            print_ok("/api/chat_stream returns 400 when 'message' is missing")
            return True
        else:
            print_fail(f"/api/chat_stream expected 400, got {r.status_code}")
            return False
    except Exception as e:
        print_fail(f"/api/chat_stream (missing message) error: {e}")
        return False


def _read_sse_events(resp, max_seconds: int = 12) -> List[Dict[str, Any]]:
    """Read SSE events from a requests Response (stream=True)
    Returns list of parsed JSON objects extracted from 'data:' lines.
    """
    events: List[Dict[str, Any]] = []
    start = time.time()
    buffer = ""
    for raw in resp.iter_lines(decode_unicode=True):
        if raw is None:
            continue
        line = raw.strip()
        if line.startswith("data:"):
            payload = line[len("data:"):].strip()
            try:
                obj = json.loads(payload)
                events.append(obj)
                if obj.get("type") == "done":
                    break
            except Exception:
                # ignore invalid lines
                pass
        if time.time() - start > max_seconds:
            break
    return events


def test_chat_stream_sse() -> bool:
    print_info("Testing /api/chat_stream SSE ...")
    try:
        # Create/get a session for consistent state
        sid_resp = requests.get(f"{BASE_URL}/api/get_or_create_session", timeout=5)
        if sid_resp.status_code != 200:
            print_fail(f"/api/get_or_create_session HTTP {sid_resp.status_code}")
            return False
        session_id = sid_resp.json().get("session_id")
        if not session_id:
            print_fail("Missing session_id from /api/get_or_create_session")
            return False

        params = {
            "message": "Hello there!",
            "country": "us",
            "session_id": session_id,
        }
        with requests.get(f"{BASE_URL}/api/chat_stream", params=params, stream=True, timeout=(5, 15)) as r:
            if r.status_code != 200:
                print_fail(f"/api/chat_stream HTTP {r.status_code}")
                return False
            ctype = r.headers.get("Content-Type", "")
            if "text/event-stream" not in ctype:
                print_fail(f"/api/chat_stream unexpected Content-Type: {ctype}")
                return False

            events = _read_sse_events(r, max_seconds=12)
            if not events:
                print_fail("No SSE events received from /api/chat_stream")
                return False

            # Validate first 'meta' event
            meta = next((e for e in events if e.get("type") == "meta"), None)
            if not meta:
                print_fail("Missing initial 'meta' event")
                return False
            required_meta = ["session_id", "risk_level", "crisis_msg", "crisis_numbers"]
            if any(k not in meta for k in required_meta):
                print_fail(f"'meta' event missing fields: {required_meta}")
                return False

            # Validate at least one token and a done
            has_token = any(e.get("type") == "token" for e in events)
            has_done = any(e.get("type") == "done" for e in events)
            if not has_token:
                print_fail("No 'token' events received")
                return False
            if not has_done:
                print_fail("No 'done' event received")
                return False

            # Log a preview of the first few events
            preview = [e.get("type") for e in events[:6]]
            print_ok(f"/api/chat_stream SSE ok. Events: {preview}")
            return True

    except Exception as e:
        print_fail(f"/api/chat_stream SSE error: {e}")
        return False


def test_analytics_log_requires_consent() -> bool:
    print_info("Testing /api/analytics/log without consent (should 202) ...")
    try:
        # Create/get a session
        sid_resp = requests.get(f"{BASE_URL}/api/get_or_create_session", timeout=5)
        if sid_resp.status_code != 200:
            print_fail(f"/api/get_or_create_session HTTP {sid_resp.status_code}")
            return False
        session_id = sid_resp.json().get("session_id")
        if not session_id:
            print_fail("Missing session_id from /api/get_or_create_session")
            return False

        payload = {
            "event_type": "quest_start",
            "metadata": {
                "quest_id": "q_breath_1",
                "tag": "breath",
                "surface": "wellness_dashboard",
                "variant": "today",
                "ts": int(time.time() * 1000),
            },
        }
        headers = {
            "X-Session-ID": session_id,
            # Intentionally omit X-Analytics-Consent
            "X-Request-ID": str(uuid.uuid4()),
            "Content-Type": "application/json",
        }
        r = requests.post(f"{BASE_URL}/api/analytics/log", json=payload, headers=headers, timeout=8)
        if r.status_code != 202:
            print_fail(f"/api/analytics/log expected 202 without consent, got {r.status_code}")
            return False
        print_ok("/api/analytics/log no-ops with 202 when consent is missing")
        return True
    except Exception as e:
        print_fail(f"/api/analytics/log (no consent) error: {e}")
        return False


def test_analytics_log_quest_event() -> bool:
    print_info("Testing /api/analytics/log quest_start with consent (should 201) ...")
    try:
        # Create/get a session
        sid_resp = requests.get(f"{BASE_URL}/api/get_or_create_session", timeout=5)
        if sid_resp.status_code != 200:
            print_fail(f"/api/get_or_create_session HTTP {sid_resp.status_code}")
            return False
        session_id = sid_resp.json().get("session_id")
        if not session_id:
            print_fail("Missing session_id from /api/get_or_create_session")
            return False

        payload = {
            "event_type": "quest_start",
            "metadata": {
                "quest_id": "q_breath_1",
                "tag": "breath",
                "surface": "wellness_dashboard",
                "variant": "today",
                "ts": int(time.time() * 1000),
            },
        }
        headers = {
            "X-Session-ID": session_id,
            "X-Analytics-Consent": "true",
            "X-Request-ID": str(uuid.uuid4()),
            "Content-Type": "application/json",
        }
        r = requests.post(f"{BASE_URL}/api/analytics/log", json=payload, headers=headers, timeout=8)
        if r.status_code != 201:
            print_fail(f"/api/analytics/log expected 201 with consent, got {r.status_code}")
            try:
                print_info(f"Body: {r.text}")
            except Exception:
                pass
            return False
        data = {}
        try:
            data = r.json()
        except Exception:
            pass
        if not data or not data.get("ok"):
            print_fail("/api/analytics/log did not return ok: true")
            return False
        print_ok("/api/analytics/log accepted quest_start with consent (201)")
        return True
    except Exception as e:
        print_fail(f"/api/analytics/log (quest_start) error: {e}")
        return False


def main() -> int:
    print("🚀 Backend MVP Readiness Test")
    print("=" * 50)
    print_info(f"Base URL: {BASE_URL}")

    results = []
    results.append(("/api/health", test_health()))
    results.append(("/api/chat_stream 400", test_chat_stream_missing_message()))
    results.append(("/api/chat_stream SSE", test_chat_stream_sse()))
    results.append(("/api/analytics/log without consent", test_analytics_log_requires_consent()))
    results.append(("/api/analytics/log quest_start", test_analytics_log_quest_event()))

    print("\n📊 Summary")
    print("=" * 50)
    passed = sum(1 for _, ok in results if ok)
    total = len(results)
    for name, ok in results:
        print(f"{OK if ok else FAIL} {name}")
    print(f"Success Rate: {passed}/{total}")

    return 0 if passed == total else 1


if __name__ == "__main__":
    sys.exit(main())
