"""
Advanced Encryption and Security Module for GentleQuest
Implements field-level encryption, key rotation, and secure data handling
"""

import os
import base64
import hashlib
import hmac
import secrets
from typing import Optional, Dict, Tuple, Any
from datetime import datetime, timedelta
from cryptography.fernet import Fernet
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2
from cryptography.hazmat.backends import default_backend
import json


class SecurityManager:
    """Comprehensive security manager for sensitive data"""
    
    def __init__(self, master_key: Optional[str] = None):
        """Initialize with master key from environment or generate"""
        self.master_key = master_key or os.getenv('ENCRYPTION_MASTER_KEY')
        if not self.master_key:
            raise ValueError("ENCRYPTION_MASTER_KEY must be set for production")
            
        # Derive encryption keys for different data types
        self.conversation_key = self._derive_key(self.master_key, b"conversations")
        self.pii_key = self._derive_key(self.master_key, b"pii_data")
        self.crisis_key = self._derive_key(self.master_key, b"crisis_data")
        
        # Initialize ciphers
        self.conversation_cipher = Fernet(self.conversation_key)
        self.pii_cipher = Fernet(self.pii_key)
        self.crisis_cipher = Fernet(self.crisis_key)
        
        # Session token settings
        self.token_lifetime = timedelta(hours=24)
        self.token_secrets = {}
        
    def _derive_key(self, master_key: str, purpose: bytes) -> bytes:
        """Derive a purpose-specific key from master key"""
        kdf = PBKDF2(
            algorithm=hashes.SHA256(),
            length=32,
            salt=purpose,
            iterations=100000,
            backend=default_backend()
        )
        key = base64.urlsafe_b64encode(kdf.derive(master_key.encode()))
        return key
        
    def encrypt_conversation(self, message: str) -> str:
        """Encrypt conversation messages"""
        if not message:
            return ""
        encrypted = self.conversation_cipher.encrypt(message.encode())
        return base64.urlsafe_b64encode(encrypted).decode()
        
    def decrypt_conversation(self, encrypted: str) -> str:
        """Decrypt conversation messages"""
        if not encrypted:
            return ""
        try:
            data = base64.urlsafe_b64decode(encrypted.encode())
            decrypted = self.conversation_cipher.decrypt(data)
            return decrypted.decode()
        except Exception:
            # Log decryption failure without exposing data
            return "[DECRYPTION_FAILED]"
            
    def encrypt_pii(self, data: Dict[str, Any]) -> str:
        """Encrypt PII data as JSON"""
        json_data = json.dumps(data, ensure_ascii=False)
        encrypted = self.pii_cipher.encrypt(json_data.encode())
        return base64.urlsafe_b64encode(encrypted).decode()
        
    def decrypt_pii(self, encrypted: str) -> Dict[str, Any]:
        """Decrypt PII data from JSON"""
        try:
            data = base64.urlsafe_b64decode(encrypted.encode())
            decrypted = self.pii_cipher.decrypt(data)
            return json.loads(decrypted.decode())
        except Exception:
            return {}
            
    def encrypt_crisis_data(self, data: str) -> str:
        """Encrypt crisis-related data with highest security"""
        if not data:
            return ""
        # Add timestamp to prevent replay attacks
        timestamped = f"{datetime.utcnow().isoformat()}|{data}"
        encrypted = self.crisis_cipher.encrypt(timestamped.encode())
        return base64.urlsafe_b64encode(encrypted).decode()
        
    def decrypt_crisis_data(self, encrypted: str) -> Tuple[Optional[datetime], Optional[str]]:
        """Decrypt crisis data and validate timestamp"""
        if not encrypted:
            return None, None
        try:
            data = base64.urlsafe_b64decode(encrypted.encode())
            decrypted = self.crisis_cipher.decrypt(data).decode()
            parts = decrypted.split('|', 1)
            if len(parts) == 2:
                timestamp = datetime.fromisoformat(parts[0])
                # Check if data is not too old (7 days)
                if datetime.utcnow() - timestamp > timedelta(days=7):
                    return timestamp, "[EXPIRED]"
                return timestamp, parts[1]
        except Exception:
            return None, "[DECRYPTION_FAILED]"
        return None, None
        
    def generate_secure_session_token(self) -> str:
        """Generate cryptographically secure session token"""
        # Generate 32 bytes of random data
        random_bytes = secrets.token_bytes(32)
        # Add timestamp for expiration
        timestamp = int(datetime.utcnow().timestamp())
        # Create HMAC for integrity
        h = hmac.new(self.master_key.encode(), digestmod=hashlib.sha256)
        h.update(random_bytes)
        h.update(str(timestamp).encode())
        signature = h.digest()
        
        # Combine components
        token_data = random_bytes + timestamp.to_bytes(8, 'big') + signature
        token = base64.urlsafe_b64encode(token_data).decode().rstrip('=')
        
        # Store for validation
        self.token_secrets[token] = {
            'created': datetime.utcnow(),
            'expires': datetime.utcnow() + self.token_lifetime
        }
        
        return token
        
    def validate_session_token(self, token: str) -> Tuple[bool, Optional[str]]:
        """Validate and check session token expiration"""
        try:
            # Decode token
            padded = token + '=' * (4 - len(token) % 4)
            token_data = base64.urlsafe_b64decode(padded)
            
            if len(token_data) < 72:  # 32 + 8 + 32 bytes minimum
                return False, "Invalid token format"
                
            # Extract components
            random_bytes = token_data[:32]
            timestamp_bytes = token_data[32:40]
            provided_signature = token_data[40:72]
            
            # Verify HMAC
            h = hmac.new(self.master_key.encode(), digestmod=hashlib.sha256)
            h.update(random_bytes)
            h.update(timestamp_bytes)
            expected_signature = h.digest()
            
            if not hmac.compare_digest(provided_signature, expected_signature):
                return False, "Invalid signature"
                
            # Check timestamp
            timestamp = int.from_bytes(timestamp_bytes, 'big')
            token_time = datetime.fromtimestamp(timestamp)
            
            if datetime.utcnow() - token_time > self.token_lifetime:
                return False, "Token expired"
                
            return True, None
            
        except Exception as e:
            return False, f"Validation error: {str(e)}"
            
    def sanitize_input(self, text: str, max_length: int = 5000) -> str:
        """Sanitize user input to prevent injection attacks"""
        if not text:
            return ""
            
        # Remove null bytes
        text = text.replace('\x00', '')
        
        # Limit length
        text = text[:max_length]
        
        # Remove potential SQL injection patterns
        dangerous_patterns = [
            r';\s*DROP\s+TABLE',
            r';\s*DELETE\s+FROM',
            r';\s*UPDATE\s+SET',
            r'<script[^>]*>.*?</script>',
            r'javascript:',
            r'on\w+\s*=',
        ]
        
        import re
        for pattern in dangerous_patterns:
            text = re.sub(pattern, '', text, flags=re.IGNORECASE)
            
        return text
        
    def hash_identifier(self, identifier: str) -> str:
        """Create consistent hash for identifiers (non-reversible)"""
        h = hashlib.sha256()
        h.update(self.master_key.encode())
        h.update(identifier.encode())
        return h.hexdigest()[:16]
        
    def redact_pii(self, text: str) -> str:
        """Redact potential PII from text"""
        import re
        
        # Email addresses
        text = re.sub(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b', '[EMAIL]', text)
        
        # Phone numbers (various formats)
        text = re.sub(r'\b\d{3}[-.]?\d{3}[-.]?\d{4}\b', '[PHONE]', text)
        text = re.sub(r'\b\(\d{3}\)\s*\d{3}[-.]?\d{4}\b', '[PHONE]', text)
        
        # SSN
        text = re.sub(r'\b\d{3}-\d{2}-\d{4}\b', '[SSN]', text)
        
        # Credit card numbers
        text = re.sub(r'\b\d{4}[\s-]?\d{4}[\s-]?\d{4}[\s-]?\d{4}\b', '[CARD]', text)
        
        # IP addresses
        text = re.sub(r'\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b', '[IP]', text)
        
        # Names (heuristic - consecutive capitalized words)
        text = re.sub(r'\b[A-Z][a-z]+\s+[A-Z][a-z]+(?:\s+[A-Z][a-z]+)?\b', '[NAME]', text)
        
        return text


class AuditLogger:
    """Secure audit logging for compliance"""
    
    def __init__(self, security_manager: SecurityManager):
        self.security = security_manager
        self.audit_file = os.getenv('AUDIT_LOG_FILE', 'audit.log')
        
    def log_data_access(self, 
                       user_id: str,
                       action: str,
                       resource: str,
                       details: Dict = None,
                       success: bool = True):
        """Log data access for audit trail"""
        entry = {
            'timestamp': datetime.utcnow().isoformat(),
            'user_hash': self.security.hash_identifier(user_id),
            'action': action,
            'resource': resource,
            'success': success,
            'details': self.security.redact_pii(str(details)) if details else None
        }
        
        # Write to secure audit log
        with open(self.audit_file, 'a') as f:
            f.write(json.dumps(entry) + '\n')
            
    def log_security_event(self,
                          event_type: str,
                          severity: str,
                          description: str,
                          user_id: Optional[str] = None):
        """Log security events"""
        entry = {
            'timestamp': datetime.utcnow().isoformat(),
            'type': 'SECURITY',
            'event': event_type,
            'severity': severity,
            'description': self.security.redact_pii(description),
            'user_hash': self.security.hash_identifier(user_id) if user_id else None
        }
        
        with open(self.audit_file, 'a') as f:
            f.write(json.dumps(entry) + '\n')
            
            
class DataRetentionManager:
    """Manage data retention and automatic deletion"""
    
    def __init__(self, db_session, security_manager: SecurityManager):
        self.db = db_session
        self.security = security_manager
        
    def apply_retention_policies(self):
        """Apply data retention policies for compliance"""
        from sqlalchemy import text
        
        policies = {
            'crisis_events': 30,  # 30 days for crisis events
            'conversation_logs': 90,  # 90 days for conversations
            'mood_entries': 365,  # 1 year for mood data
            'analytics_events': 30,  # 30 days for analytics
            'audit_logs': 2555,  # 7 years for audit logs
        }
        
        for table, days in policies.items():
            cutoff = datetime.utcnow() - timedelta(days=days)
            
            # Delete old records
            try:
                result = self.db.execute(
                    text(f"""
                        DELETE FROM {table}
                        WHERE timestamp < :cutoff
                    """),
                    {'cutoff': cutoff}
                )
                
                if result.rowcount > 0:
                    self.security.log_security_event(
                        'DATA_RETENTION',
                        'INFO',
                        f'Deleted {result.rowcount} records from {table} older than {days} days'
                    )
                    
                self.db.commit()
                
            except Exception as e:
                self.db.rollback()
                self.security.log_security_event(
                    'DATA_RETENTION_ERROR',
                    'ERROR',
                    f'Failed to apply retention to {table}: {str(e)}'
                )


def initialize_security(app):
    """Initialize security for Flask app"""
    # Check for master key
    master_key = os.getenv('ENCRYPTION_MASTER_KEY')
    if not master_key:
        # Generate one for development (DO NOT use in production)
        if app.config.get('ENV') == 'development':
            master_key = Fernet.generate_key().decode()
            os.environ['ENCRYPTION_MASTER_KEY'] = master_key
            app.logger.warning("Generated temporary encryption key for development")
        else:
            raise ValueError("ENCRYPTION_MASTER_KEY must be set in production")
    
    # Initialize security manager
    security = SecurityManager(master_key)
    
    # Initialize audit logger
    audit = AuditLogger(security)
    
    # Store in app context
    app.security_manager = security
    app.audit_logger = audit
    
    return security, audit
