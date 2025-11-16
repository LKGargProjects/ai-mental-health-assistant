#!/usr/bin/env python3
"""
Apply Security Hardening to GentleQuest
This script migrates existing data to encrypted format and updates the application
"""

import os
import sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from sqlalchemy import text, create_engine
from datetime import datetime
import logging
from security.encryption import SecurityManager, initialize_security

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class SecurityMigration:
    """Migrate existing data to encrypted format"""
    
    def __init__(self, database_url: str):
        self.engine = create_engine(database_url)
        self.security = SecurityManager()
        
    def add_encrypted_columns(self):
        """Add encrypted columns to existing tables"""
        logger.info("Adding encrypted columns to database...")
        
        with self.engine.connect() as conn:
            # Check dialect
            dialect = self.engine.dialect.name
            
            migrations = []
            
            if dialect == 'postgresql':
                migrations = [
                    # Add encrypted columns for conversations
                    "ALTER TABLE conversation_logs ADD COLUMN IF NOT EXISTS user_message_encrypted TEXT",
                    "ALTER TABLE conversation_logs ADD COLUMN IF NOT EXISTS ai_response_encrypted TEXT",
                    
                    # Add encrypted columns for messages
                    "ALTER TABLE chat_messages ADD COLUMN IF NOT EXISTS content_encrypted TEXT",
                    
                    # Add encrypted columns for mood entries
                    "ALTER TABLE mood_entries ADD COLUMN IF NOT EXISTS note_encrypted TEXT",
                    
                    # Add encrypted columns for crisis events
                    "ALTER TABLE crisis_detections ADD COLUMN IF NOT EXISTS message_encrypted TEXT",
                    
                    # Add hash columns for identifiers
                    "ALTER TABLE user_sessions ADD COLUMN IF NOT EXISTS id_hash VARCHAR(64)",
                    "ALTER TABLE sessions ADD COLUMN IF NOT EXISTS id_hash VARCHAR(64)",
                    
                    # Add security metadata
                    "ALTER TABLE user_sessions ADD COLUMN IF NOT EXISTS encryption_version INTEGER DEFAULT 1",
                    "ALTER TABLE user_sessions ADD COLUMN IF NOT EXISTS last_key_rotation TIMESTAMP",
                ]
            else:  # SQLite
                migrations = [
                    # SQLite doesn't support ADD COLUMN IF NOT EXISTS
                    # Need to check first
                ]
                
            for migration in migrations:
                try:
                    conn.execute(text(migration))
                    conn.commit()
                    logger.info(f"Applied: {migration[:50]}...")
                except Exception as e:
                    logger.warning(f"Migration skipped (may already exist): {e}")
                    
    def encrypt_existing_data(self, batch_size: int = 100):
        """Encrypt existing plaintext data"""
        logger.info("Encrypting existing data...")
        
        with self.engine.connect() as conn:
            # Encrypt conversation logs
            logger.info("Encrypting conversation logs...")
            offset = 0
            while True:
                result = conn.execute(text("""
                    SELECT id, user_message, ai_response 
                    FROM conversation_logs 
                    WHERE user_message_encrypted IS NULL
                    LIMIT :limit OFFSET :offset
                """), {'limit': batch_size, 'offset': offset})
                
                rows = result.fetchall()
                if not rows:
                    break
                    
                for row in rows:
                    encrypted_user = self.security.encrypt_conversation(row.user_message)
                    encrypted_ai = self.security.encrypt_conversation(row.ai_response)
                    
                    conn.execute(text("""
                        UPDATE conversation_logs 
                        SET user_message_encrypted = :user_enc,
                            ai_response_encrypted = :ai_enc
                        WHERE id = :id
                    """), {
                        'user_enc': encrypted_user,
                        'ai_enc': encrypted_ai,
                        'id': row.id
                    })
                    
                conn.commit()
                logger.info(f"Encrypted {len(rows)} conversation logs")
                offset += batch_size
                
            # Encrypt crisis detections
            logger.info("Encrypting crisis detections...")
            offset = 0
            while True:
                result = conn.execute(text("""
                    SELECT id, message 
                    FROM crisis_detections 
                    WHERE message_encrypted IS NULL
                    LIMIT :limit OFFSET :offset
                """), {'limit': batch_size, 'offset': offset})
                
                rows = result.fetchall()
                if not rows:
                    break
                    
                for row in rows:
                    encrypted = self.security.encrypt_crisis_data(row.message)
                    
                    conn.execute(text("""
                        UPDATE crisis_detections 
                        SET message_encrypted = :encrypted
                        WHERE id = :id
                    """), {
                        'encrypted': encrypted,
                        'id': row.id
                    })
                    
                conn.commit()
                logger.info(f"Encrypted {len(rows)} crisis detections")
                offset += batch_size
                
            # Hash session IDs
            logger.info("Hashing session identifiers...")
            result = conn.execute(text("""
                SELECT DISTINCT id FROM user_sessions WHERE id_hash IS NULL
            """))
            
            for row in result:
                id_hash = self.security.hash_identifier(row.id)
                
                conn.execute(text("""
                    UPDATE user_sessions 
                    SET id_hash = :hash
                    WHERE id = :id
                """), {
                    'hash': id_hash,
                    'id': row.id
                })
                
            conn.commit()
            logger.info("Session hashing complete")
            
    def remove_plaintext_columns(self, confirm: bool = False):
        """Remove plaintext columns after verification"""
        if not confirm:
            logger.warning("Skipping plaintext removal - set confirm=True to proceed")
            return
            
        logger.info("Removing plaintext columns...")
        
        with self.engine.connect() as conn:
            # Verify encryption is complete
            result = conn.execute(text("""
                SELECT COUNT(*) as count 
                FROM conversation_logs 
                WHERE user_message_encrypted IS NULL 
                AND user_message IS NOT NULL
            """))
            
            unencrypted = result.scalar()
            if unencrypted > 0:
                logger.error(f"Cannot remove plaintext - {unencrypted} unencrypted records remain")
                return
                
            # Drop plaintext columns
            dialect = self.engine.dialect.name
            
            if dialect == 'postgresql':
                drops = [
                    "ALTER TABLE conversation_logs DROP COLUMN IF EXISTS user_message",
                    "ALTER TABLE conversation_logs DROP COLUMN IF EXISTS ai_response",
                    "ALTER TABLE crisis_detections DROP COLUMN IF EXISTS message",
                    "ALTER TABLE chat_messages DROP COLUMN IF EXISTS content",
                ]
                
                for drop in drops:
                    try:
                        conn.execute(text(drop))
                        conn.commit()
                        logger.info(f"Dropped: {drop}")
                    except Exception as e:
                        logger.error(f"Failed to drop: {e}")
            else:
                logger.warning("SQLite does not support dropping columns - plaintext remains")
                
    def create_security_tables(self):
        """Create security-specific tables"""
        logger.info("Creating security tables...")
        
        with self.engine.connect() as conn:
            dialect = self.engine.dialect.name
            
            if dialect == 'postgresql':
                tables = [
                    """
                    CREATE TABLE IF NOT EXISTS encryption_keys (
                        id SERIAL PRIMARY KEY,
                        key_id VARCHAR(64) UNIQUE NOT NULL,
                        key_data TEXT NOT NULL,
                        purpose VARCHAR(32) NOT NULL,
                        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                        rotated_at TIMESTAMP,
                        expires_at TIMESTAMP,
                        is_active BOOLEAN DEFAULT TRUE
                    )
                    """,
                    """
                    CREATE TABLE IF NOT EXISTS audit_log (
                        id SERIAL PRIMARY KEY,
                        timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                        user_hash VARCHAR(64),
                        action VARCHAR(100) NOT NULL,
                        resource VARCHAR(200),
                        success BOOLEAN DEFAULT TRUE,
                        details TEXT,
                        ip_address_hash VARCHAR(64),
                        session_hash VARCHAR(64)
                    )
                    """,
                    """
                    CREATE TABLE IF NOT EXISTS security_events (
                        id SERIAL PRIMARY KEY,
                        timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                        event_type VARCHAR(50) NOT NULL,
                        severity VARCHAR(20) NOT NULL,
                        description TEXT,
                        user_hash VARCHAR(64),
                        metadata JSONB
                    )
                    """,
                    """
                    CREATE TABLE IF NOT EXISTS data_access_log (
                        id SERIAL PRIMARY KEY,
                        timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                        accessor_hash VARCHAR(64) NOT NULL,
                        data_type VARCHAR(50) NOT NULL,
                        record_id VARCHAR(100),
                        action VARCHAR(20) NOT NULL,
                        purpose TEXT,
                        legal_basis VARCHAR(100)
                    )
                    """
                ]
            else:  # SQLite
                tables = [
                    """
                    CREATE TABLE IF NOT EXISTS encryption_keys (
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        key_id TEXT UNIQUE NOT NULL,
                        key_data TEXT NOT NULL,
                        purpose TEXT NOT NULL,
                        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                        rotated_at DATETIME,
                        expires_at DATETIME,
                        is_active INTEGER DEFAULT 1
                    )
                    """,
                    """
                    CREATE TABLE IF NOT EXISTS audit_log (
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
                        user_hash TEXT,
                        action TEXT NOT NULL,
                        resource TEXT,
                        success INTEGER DEFAULT 1,
                        details TEXT,
                        ip_address_hash TEXT,
                        session_hash TEXT
                    )
                    """,
                    """
                    CREATE TABLE IF NOT EXISTS security_events (
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
                        event_type TEXT NOT NULL,
                        severity TEXT NOT NULL,
                        description TEXT,
                        user_hash TEXT,
                        metadata TEXT
                    )
                    """,
                    """
                    CREATE TABLE IF NOT EXISTS data_access_log (
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
                        accessor_hash TEXT NOT NULL,
                        data_type TEXT NOT NULL,
                        record_id TEXT,
                        action TEXT NOT NULL,
                        purpose TEXT,
                        legal_basis TEXT
                    )
                    """
                ]
                
            for table in tables:
                try:
                    conn.execute(text(table))
                    conn.commit()
                    logger.info(f"Created table: {table.split('(')[0]}")
                except Exception as e:
                    logger.warning(f"Table creation skipped: {e}")
                    
            # Create indexes for performance
            indexes = [
                "CREATE INDEX IF NOT EXISTS idx_audit_timestamp ON audit_log(timestamp DESC)",
                "CREATE INDEX IF NOT EXISTS idx_audit_user ON audit_log(user_hash)",
                "CREATE INDEX IF NOT EXISTS idx_security_timestamp ON security_events(timestamp DESC)",
                "CREATE INDEX IF NOT EXISTS idx_security_severity ON security_events(severity)",
                "CREATE INDEX IF NOT EXISTS idx_access_timestamp ON data_access_log(timestamp DESC)",
                "CREATE INDEX IF NOT EXISTS idx_access_accessor ON data_access_log(accessor_hash)",
            ]
            
            for index in indexes:
                try:
                    conn.execute(text(index))
                    conn.commit()
                except Exception:
                    pass  # Index may already exist


def generate_security_config():
    """Generate secure configuration file"""
    logger.info("Generating security configuration...")
    
    config = """# Security Configuration for GentleQuest
# CRITICAL: Keep this file secure and never commit to version control

# Encryption Master Key (generate with: python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())")
ENCRYPTION_MASTER_KEY=

# Session Security
SESSION_SECRET_KEY=
SESSION_LIFETIME_HOURS=24
SESSION_SECURE_COOKIE=true
SESSION_HTTPONLY=true
SESSION_SAMESITE=Strict

# Database Encryption
DB_ENCRYPTION_ENABLED=true
DB_ENCRYPTION_KEY_ROTATION_DAYS=90

# Audit Logging
AUDIT_LOG_ENABLED=true
AUDIT_LOG_FILE=/secure/logs/audit.log
AUDIT_LOG_RETENTION_DAYS=2555

# Data Retention (days)
RETENTION_CONVERSATIONS=90
RETENTION_CRISIS_EVENTS=30
RETENTION_MOOD_DATA=365
RETENTION_ANALYTICS=30

# Security Headers
SECURITY_HEADERS_ENABLED=true
CSP_POLICY="default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline';"
HSTS_MAX_AGE=31536000
HSTS_INCLUDE_SUBDOMAINS=true
HSTS_PRELOAD=true

# Rate Limiting
RATE_LIMIT_ENABLED=true
RATE_LIMIT_DEFAULT="1000 per hour"
RATE_LIMIT_CRISIS="unlimited"
RATE_LIMIT_AUTH="20 per hour"

# IP Security
IP_ANONYMIZATION=true
IP_SALT=

# Crisis Protection
CRISIS_ENCRYPTION_LEVEL=maximum
CRISIS_AUTO_ESCALATION=true
CRISIS_RETENTION_DAYS=30

# Compliance
HIPAA_MODE=true
GDPR_MODE=true
DATA_RESIDENCY=US

# Monitoring
SECURITY_MONITORING_ENABLED=true
ANOMALY_DETECTION=true
INTRUSION_DETECTION=true
"""
    
    with open('.env.security', 'w') as f:
        f.write(config)
        
    logger.info("Security configuration saved to .env.security")
    logger.warning("⚠️  IMPORTANT: Set all empty values before deploying!")


def main():
    """Main migration function"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Apply security hardening to GentleQuest')
    parser.add_argument('--database-url', required=True, help='Database connection URL')
    parser.add_argument('--encrypt', action='store_true', help='Encrypt existing data')
    parser.add_argument('--remove-plaintext', action='store_true', help='Remove plaintext columns')
    parser.add_argument('--confirm', action='store_true', help='Confirm dangerous operations')
    parser.add_argument('--generate-config', action='store_true', help='Generate security config')
    
    args = parser.parse_args()
    
    if args.generate_config:
        generate_security_config()
        return
        
    # Initialize migration
    migration = SecurityMigration(args.database_url)
    
    # Create security tables
    migration.create_security_tables()
    
    # Add encrypted columns
    migration.add_encrypted_columns()
    
    # Encrypt existing data
    if args.encrypt:
        migration.encrypt_existing_data()
        
    # Remove plaintext (dangerous!)
    if args.remove_plaintext:
        migration.remove_plaintext_columns(confirm=args.confirm)
        
    logger.info("✅ Security migration complete!")
    logger.warning("⚠️  Remember to:")
    logger.warning("  1. Set ENCRYPTION_MASTER_KEY in production")
    logger.warning("  2. Update app.py to use encrypted columns")
    logger.warning("  3. Enable audit logging")
    logger.warning("  4. Test thoroughly before deploying")


if __name__ == '__main__':
    main()
