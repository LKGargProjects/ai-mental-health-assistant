"""
Comprehensive Test Suite for GentleQuest Backend
"""

import pytest
import json
import time
from datetime import datetime, timedelta
from unittest.mock import patch, MagicMock
from app import create_app
from models import db, UserSession, Message, SelfAssessmentEntry
from crisis_detection import detect_crisis_level

@pytest.fixture
def app():
    """Create test application"""
    app = create_app()
    app.config.update({
        'TESTING': True,
        'SQLALCHEMY_DATABASE_URI': 'sqlite:///:memory:',
        'WTF_CSRF_ENABLED': False,
        'SECRET_KEY': 'test-secret-key',
        'RATE_LIMIT_ENABLED': False
    })
    
    with app.app_context():
        db.create_all()
        yield app
        db.session.remove()
        db.drop_all()

@pytest.fixture
def client(app):
    """Create test client"""
    return app.test_client()

@pytest.fixture
def authenticated_client(client):
    """Create authenticated test client with session"""
    response = client.get('/api/get_or_create_session')
    session_id = json.loads(response.data)['session_id']
    
    class AuthClient:
        def __init__(self, client, session_id):
            self.client = client
            self.session_id = session_id
            
        def get(self, *args, **kwargs):
            kwargs.setdefault('headers', {})['X-Session-ID'] = self.session_id
            return self.client.get(*args, **kwargs)
            
        def post(self, *args, **kwargs):
            kwargs.setdefault('headers', {})['X-Session-ID'] = self.session_id
            return self.client.post(*args, **kwargs)
            
        def put(self, *args, **kwargs):
            kwargs.setdefault('headers', {})['X-Session-ID'] = self.session_id
            return self.client.put(*args, **kwargs)
            
        def delete(self, *args, **kwargs):
            kwargs.setdefault('headers', {})['X-Session-ID'] = self.session_id
            return self.client.delete(*args, **kwargs)
    
    return AuthClient(client, session_id)


class TestHealthEndpoints:
    """Test health and monitoring endpoints"""
    
    def test_health_endpoint(self, client):
        """Test /api/health endpoint"""
        response = client.get('/api/health')
        assert response.status_code == 200
        
        data = json.loads(response.data)
        assert 'status' in data
        assert 'timestamp' in data
        assert 'environment' in data
        assert 'endpoints' in data
        
    def test_ping_endpoint(self, client):
        """Test /api/ping endpoint"""
        response = client.get('/api/ping')
        assert response.status_code == 200
        
        data = json.loads(response.data)
        assert data['ok'] is True
        assert 'ts' in data
        
    def test_ping_head_method(self, client):
        """Test /api/ping with HEAD method"""
        response = client.head('/api/ping')
        assert response.status_code == 200
        
    def test_deploy_test_endpoint(self, client):
        """Test /api/deploy-test endpoint"""
        response = client.get('/api/deploy-test')
        assert response.status_code == 200
        
        data = json.loads(response.data)
        assert data['ok'] is True
        assert 'version' in data
        assert 'environment' in data
        
    def test_metrics_endpoint(self, client):
        """Test /api/metrics endpoint"""
        response = client.get('/api/metrics')
        assert response.status_code == 200
        assert 'text/plain' in response.content_type
        
        # Check for Prometheus format
        metrics = response.data.decode('utf-8')
        assert '# HELP' in metrics
        assert '# TYPE' in metrics
        assert 'app_cpu_usage' in metrics


class TestSessionManagement:
    """Test session management functionality"""
    
    def test_get_or_create_session(self, client):
        """Test session creation"""
        response = client.get('/api/get_or_create_session')
        assert response.status_code == 200
        
        data = json.loads(response.data)
        assert 'session_id' in data
        assert len(data['session_id']) > 0
        
    def test_session_persistence(self, client):
        """Test session persistence across requests"""
        # Create session
        response1 = client.get('/api/get_or_create_session')
        session_id1 = json.loads(response1.data)['session_id']
        
        # Use same session in another request
        headers = {'X-Session-ID': session_id1}
        response2 = client.get('/api/chat_history', headers=headers)
        assert response2.status_code == 200
        
    def test_invalid_session_id(self, client):
        """Test handling of invalid session ID"""
        headers = {'X-Session-ID': 'invalid-session-id'}
        response = client.post('/api/mood_entry',
                              headers=headers,
                              json={'mood_level': 3})
        # Should still work by creating new session
        assert response.status_code in [200, 201]


class TestChatEndpoints:
    """Test chat-related endpoints"""
    
    @patch('app._get_ai_response_with_failover')
    def test_chat_endpoint(self, mock_ai, authenticated_client):
        """Test /api/chat endpoint"""
        mock_ai.return_value = ("Hello! How can I help you today?", "gemini")
        
        response = authenticated_client.post(
            '/api/chat',
            json={'message': 'Hello'}
        )
        
        assert response.status_code == 200
        data = json.loads(response.data)
        assert 'response' in data
        assert 'risk_level' in data
        assert 'session_id' in data
        
    def test_chat_without_message(self, authenticated_client):
        """Test chat endpoint without message"""
        response = authenticated_client.post('/api/chat', json={})
        assert response.status_code == 400
        
    def test_chat_empty_message(self, authenticated_client):
        """Test chat endpoint with empty message"""
        response = authenticated_client.post('/api/chat', json={'message': '  '})
        assert response.status_code == 400
        
    @patch('app._get_ai_response_with_failover')
    def test_chat_stream_endpoint(self, mock_ai, client):
        """Test /api/chat_stream SSE endpoint"""
        mock_ai.return_value = ("Test response", "gemini")
        
        response = client.get('/api/chat_stream?message=Hello')
        assert response.status_code == 200
        assert response.content_type == 'text/event-stream'
        
    def test_chat_history(self, authenticated_client):
        """Test /api/chat_history endpoint"""
        response = authenticated_client.get('/api/chat_history')
        assert response.status_code == 200
        assert isinstance(json.loads(response.data), list)


class TestCrisisDetection:
    """Test crisis detection functionality"""
    
    def test_crisis_detection_high_risk(self):
        """Test detection of high-risk content"""
        message = "I want to end it all"
        risk_level = detect_crisis_level(message)
        assert risk_level in ['high', 'crisis']
        
    def test_crisis_detection_medium_risk(self):
        """Test detection of medium-risk content"""
        message = "I feel really hopeless lately"
        risk_level = detect_crisis_level(message)
        assert risk_level in ['low', 'medium', 'high']
        
    def test_crisis_detection_low_risk(self):
        """Test detection of low-risk content"""
        message = "I'm having a good day today"
        risk_level = detect_crisis_level(message)
        assert risk_level in ['none', 'low']
        
    @patch('app._get_ai_response_with_failover')
    def test_crisis_response_in_chat(self, mock_ai, authenticated_client):
        """Test crisis response in chat"""
        mock_ai.return_value = ("I understand you're going through a difficult time...", "gemini")
        
        response = authenticated_client.post(
            '/api/chat',
            json={'message': 'I want to hurt myself'}
        )
        
        assert response.status_code == 200
        data = json.loads(response.data)
        assert data['risk_level'] in ['high', 'crisis']
        assert 'crisis_msg' in data
        assert 'crisis_numbers' in data


class TestMoodTracking:
    """Test mood tracking functionality"""
    
    def test_add_mood_entry(self, authenticated_client):
        """Test adding mood entry"""
        response = authenticated_client.post(
            '/api/mood_entry',
            json={
                'mood_level': 4,
                'note': 'Feeling good today'
            }
        )
        
        assert response.status_code in [200, 201]
        data = json.loads(response.data)
        assert 'mood_level' in data or 'message' in data
        
    def test_add_mood_invalid_level(self, authenticated_client):
        """Test adding mood with invalid level"""
        response = authenticated_client.post(
            '/api/mood_entry',
            json={'mood_level': 10}
        )
        
        assert response.status_code == 400
        
    def test_mood_history(self, authenticated_client):
        """Test getting mood history"""
        # Add some mood entries first
        for i in range(3):
            authenticated_client.post(
                '/api/mood_entry',
                json={'mood_level': i + 2}
            )
            
        response = authenticated_client.get('/api/mood_history')
        assert response.status_code == 200
        
        data = json.loads(response.data)
        assert isinstance(data, list)
        
    def test_mood_analytics(self, authenticated_client):
        """Test mood analytics endpoint"""
        # Add mood entries
        for i in range(5):
            authenticated_client.post(
                '/api/mood_entry',
                json={'mood_level': (i % 5) + 1}
            )
            
        response = authenticated_client.get('/api/mood_analytics')
        assert response.status_code == 200
        
        data = json.loads(response.data)
        assert 'analytics' in data
        analytics = data['analytics']
        assert 'average_mood' in analytics
        assert 'mood_trend' in analytics
        assert 'mood_distribution' in analytics


class TestSelfAssessment:
    """Test self-assessment functionality"""
    
    def test_submit_self_assessment(self, authenticated_client):
        """Test submitting self-assessment"""
        response = authenticated_client.post(
            '/api/self_assessment',
            json={
                'mood': 'good',
                'energy': 'high',
                'sleep': 'well',
                'stress': 'low',
                'notes': 'Feeling great today'
            }
        )
        
        assert response.status_code in [200, 201]
        data = json.loads(response.data)
        assert data['success'] is True
        
    def test_self_assessment_missing_fields(self, authenticated_client):
        """Test self-assessment with missing fields"""
        response = authenticated_client.post(
            '/api/self_assessment',
            json={'mood': 'good'}
        )
        
        assert response.status_code == 400
        
    def test_self_assessment_once_per_day(self, authenticated_client):
        """Test once-per-day restriction"""
        # First submission
        response1 = authenticated_client.post(
            '/api/self_assessment',
            json={
                'mood': 'good',
                'energy': 'high',
                'sleep': 'well',
                'stress': 'low'
            }
        )
        assert response1.status_code in [200, 201]
        
        # Second submission same day
        response2 = authenticated_client.post(
            '/api/self_assessment',
            json={
                'mood': 'great',
                'energy': 'medium',
                'sleep': 'okay',
                'stress': 'medium'
            }
        )
        
        data = json.loads(response2.data)
        assert data.get('already_completed_today') is True
        assert data.get('xp_awarded') == 0


class TestAnalytics:
    """Test analytics functionality"""
    
    def test_log_analytics_with_consent(self, authenticated_client):
        """Test logging analytics with consent"""
        response = authenticated_client.client.post(
            '/api/analytics/log',
            headers={
                'X-Session-ID': authenticated_client.session_id,
                'X-Analytics-Consent': 'true'
            },
            json={
                'event_type': 'quest_start',
                'metadata': {
                    'quest_id': 'test_quest_1',
                    'surface': 'wellness_dashboard'
                }
            }
        )
        
        assert response.status_code == 201
        data = json.loads(response.data)
        assert data['ok'] is True
        
    def test_log_analytics_without_consent(self, authenticated_client):
        """Test logging analytics without consent"""
        response = authenticated_client.post(
            '/api/analytics/log',
            json={'event_type': 'test_event'}
        )
        
        assert response.status_code == 202
        data = json.loads(response.data)
        assert 'skipped' in data
        
    def test_analytics_recent(self, authenticated_client):
        """Test fetching recent analytics"""
        # Log some events first
        for i in range(3):
            authenticated_client.client.post(
                '/api/analytics/log',
                headers={
                    'X-Session-ID': authenticated_client.session_id,
                    'X-Analytics-Consent': 'true'
                },
                json={
                    'event_type': f'test_event_{i}',
                    'metadata': {'value': i}
                }
            )
            
        response = authenticated_client.get('/api/analytics/recent?limit=10')
        assert response.status_code == 200
        
        data = json.loads(response.data)
        assert 'events' in data
        assert 'count' in data


class TestCommunityEndpoints:
    """Test community features"""
    
    def test_community_feed(self, client):
        """Test /api/community/feed endpoint"""
        response = client.get('/api/community/feed?limit=5')
        assert response.status_code == 200
        
        data = json.loads(response.data)
        assert 'items' in data
        assert 'count' in data
        
    def test_community_react(self, authenticated_client):
        """Test reacting to community post"""
        # Get a post from feed
        feed_response = authenticated_client.get('/api/community/feed?limit=1')
        feed_data = json.loads(feed_response.data)
        
        if feed_data['items']:
            post_id = feed_data['items'][0]['id']
            
            response = authenticated_client.post(
                f'/api/community/react/{post_id}',
                json={'kind': 'helped'}
            )
            
            assert response.status_code in [200, 201]


class TestRateLimiting:
    """Test rate limiting functionality"""
    
    def test_rate_limiting_enforcement(self, app):
        """Test that rate limiting is enforced"""
        # Enable rate limiting for this test
        app.config['RATE_LIMIT_ENABLED'] = True
        client = app.test_client()
        
        # Make many requests quickly
        responses = []
        for i in range(35):  # Exceeds 30 per minute limit
            response = client.post(
                '/api/chat',
                json={'message': 'test'},
                headers={'X-Session-ID': f'test-session-{i}'}
            )
            responses.append(response.status_code)
            
        # At least one should be rate limited
        assert 429 in responses
        
    def test_rate_limit_exempt_endpoints(self, app):
        """Test that certain endpoints are exempt from rate limiting"""
        app.config['RATE_LIMIT_ENABLED'] = True
        client = app.test_client()
        
        # These should never be rate limited
        for i in range(100):
            response = client.get('/api/health')
            assert response.status_code == 200
            
            response = client.get('/api/ping')
            assert response.status_code == 200


class TestErrorHandling:
    """Test error handling"""
    
    def test_404_error(self, client):
        """Test 404 error handling"""
        response = client.get('/api/nonexistent')
        assert response.status_code == 404
        
    def test_database_error_recovery(self, app, authenticated_client):
        """Test recovery from database errors"""
        with patch('app.db.session.execute') as mock_execute:
            mock_execute.side_effect = Exception("Database error")
            
            response = authenticated_client.get('/api/mood_history')
            assert response.status_code == 500
            
            data = json.loads(response.data)
            assert 'error' in data


class TestSecurity:
    """Test security features"""
    
    def test_sql_injection_protection(self, authenticated_client):
        """Test SQL injection protection"""
        malicious_input = "'; DROP TABLE users; --"
        
        response = authenticated_client.post(
            '/api/chat',
            json={'message': malicious_input}
        )
        
        # Should handle safely without executing SQL
        assert response.status_code in [200, 400, 500]
        
    def test_xss_protection(self, authenticated_client):
        """Test XSS protection"""
        xss_attempt = "<script>alert('XSS')</script>"
        
        response = authenticated_client.post(
            '/api/mood_entry',
            json={
                'mood_level': 3,
                'note': xss_attempt
            }
        )
        
        # Should handle safely
        assert response.status_code in [200, 201]
        
        # Verify stored data is escaped/safe
        history = authenticated_client.get('/api/mood_history')
        data = json.loads(history.data)
        
        if data:
            # Check that script tags are not in raw form
            for entry in data:
                if 'note' in entry:
                    assert '<script>' not in entry['note']


class TestAdminEndpoints:
    """Test admin functionality"""
    
    def test_admin_purge_unauthorized(self, client):
        """Test admin purge without token"""
        response = client.post('/api/admin/purge')
        assert response.status_code == 401
        
    def test_admin_purge_with_token(self, app, client):
        """Test admin purge with valid token"""
        app.config['ADMIN_API_TOKEN'] = 'test-admin-token'
        
        response = client.post(
            '/api/admin/purge',
            headers={'X-Admin-Token': 'test-admin-token'}
        )
        
        assert response.status_code == 200
        data = json.loads(response.data)
        assert data['success'] is True
        assert 'purged' in data
        
    def test_retention_config(self, app, client):
        """Test retention configuration endpoint"""
        app.config['ADMIN_API_TOKEN'] = 'test-admin-token'
        
        response = client.get(
            '/api/admin/retention_config',
            headers={'X-Admin-Token': 'test-admin-token'}
        )
        
        assert response.status_code == 200
        data = json.loads(response.data)
        assert 'message_retention_days' in data
        assert 'session_retention_days' in data


class TestIntegration:
    """Integration tests for full workflows"""
    
    @patch('app._get_ai_response_with_failover')
    def test_full_chat_workflow(self, mock_ai, client):
        """Test complete chat workflow"""
        mock_ai.return_value = ("Test response", "gemini")
        
        # 1. Create session
        session_response = client.get('/api/get_or_create_session')
        session_id = json.loads(session_response.data)['session_id']
        
        headers = {'X-Session-ID': session_id}
        
        # 2. Send chat message
        chat_response = client.post(
            '/api/chat',
            headers=headers,
            json={'message': 'Hello, I need help'}
        )
        assert chat_response.status_code == 200
        
        # 3. Check chat history
        history_response = client.get('/api/chat_history', headers=headers)
        assert history_response.status_code == 200
        
        # 4. Add mood entry
        mood_response = client.post(
            '/api/mood_entry',
            headers=headers,
            json={'mood_level': 3}
        )
        assert mood_response.status_code in [200, 201]
        
        # 5. Submit self-assessment
        assessment_response = client.post(
            '/api/self_assessment',
            headers=headers,
            json={
                'mood': 'okay',
                'energy': 'medium',
                'sleep': 'fair',
                'stress': 'medium'
            }
        )
        assert assessment_response.status_code in [200, 201]
        
        # 6. Get wellness recommendations
        wellness_response = client.get(
            '/api/wellness_recommendations',
            headers=headers
        )
        assert wellness_response.status_code == 200


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
