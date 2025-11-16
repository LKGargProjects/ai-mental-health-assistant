"""
Community Phase 1: Database Models and Schema
"""

from enum import Enum
from dataclasses import dataclass
from datetime import datetime
from typing import Dict, Optional


class ContentStatus(Enum):
    """Content moderation status"""
    PENDING = "pending"
    APPROVED = "approved"
    REJECTED = "rejected"
    HIDDEN = "hidden"
    FLAGGED = "flagged"


class ModerationAction(Enum):
    """Moderation actions"""
    APPROVE = "approve"
    REJECT = "reject"
    HIDE = "hide"
    UNHIDE = "unhide"
    DELETE = "delete"
    WARN = "warn"
    BAN = "ban"


@dataclass
class CommunityPost:
    """Community post data model"""
    id: int
    user_hash: str
    topic: str
    title: str
    body: str
    status: ContentStatus
    created_at: datetime
    updated_at: datetime
    reactions: Dict[str, int]
    flags: int
    is_pinned: bool
    is_locked: bool
    reply_count: int
    view_count: int
    
    def to_dict(self, include_sensitive: bool = False) -> Dict:
        """Convert to dictionary for API response"""
        data = {
            'id': self.id,
            'topic': self.topic,
            'title': self.title,
            'body': self.body,
            'created_at': self.created_at.isoformat(),
            'reactions': self.reactions,
            'reply_count': self.reply_count,
            'view_count': self.view_count,
            'is_pinned': self.is_pinned,
            'is_locked': self.is_locked
        }
        
        if include_sensitive:
            data.update({
                'user_hash': self.user_hash,
                'status': self.status.value,
                'flags': self.flags,
                'updated_at': self.updated_at.isoformat()
            })
            
        return data


@dataclass
class CommunityUser:
    """Community user profile"""
    user_hash: str
    session_id: str
    display_name: Optional[str]
    reputation: int
    posts_count: int
    reactions_given: int
    reactions_received: int
    is_banned: bool
    ban_reason: Optional[str]
    ban_until: Optional[datetime]
    created_at: datetime
    last_active: datetime
    
    def to_dict(self) -> Dict:
        """Convert to dictionary"""
        return {
            'display_name': self.display_name or 'Anonymous',
            'reputation': self.reputation,
            'posts_count': self.posts_count,
            'member_since': self.created_at.isoformat(),
            'last_active': self.last_active.isoformat()
        }


# SQL Schema Definitions
SQLITE_SCHEMA = """
CREATE TABLE IF NOT EXISTS community_posts_v1 (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_hash TEXT NOT NULL,
    session_id TEXT NOT NULL,
    topic TEXT NOT NULL,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    status TEXT DEFAULT 'pending',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    reactions_helped INTEGER DEFAULT 0,
    reactions_relate INTEGER DEFAULT 0,
    reactions_strength INTEGER DEFAULT 0,
    reactions_insight INTEGER DEFAULT 0,
    flags INTEGER DEFAULT 0,
    is_pinned INTEGER DEFAULT 0,
    is_locked INTEGER DEFAULT 0,
    reply_count INTEGER DEFAULT 0,
    view_count INTEGER DEFAULT 0,
    parent_id INTEGER,
    metadata TEXT
);

CREATE TABLE IF NOT EXISTS community_reactions_v1 (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    post_id INTEGER NOT NULL,
    user_hash TEXT NOT NULL,
    session_id TEXT NOT NULL,
    reaction_type TEXT NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(post_id, user_hash, reaction_type)
);

CREATE TABLE IF NOT EXISTS community_flags_v1 (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    post_id INTEGER NOT NULL,
    user_hash TEXT NOT NULL,
    session_id TEXT NOT NULL,
    reason TEXT NOT NULL,
    details TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    reviewed INTEGER DEFAULT 0,
    action_taken TEXT
);

CREATE TABLE IF NOT EXISTS community_users_v1 (
    user_hash TEXT PRIMARY KEY,
    session_id TEXT NOT NULL,
    display_name TEXT,
    reputation INTEGER DEFAULT 0,
    posts_count INTEGER DEFAULT 0,
    reactions_given INTEGER DEFAULT 0,
    reactions_received INTEGER DEFAULT 0,
    is_banned INTEGER DEFAULT 0,
    ban_reason TEXT,
    ban_until DATETIME,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    last_active DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS moderation_log_v1 (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    moderator_id TEXT NOT NULL,
    action TEXT NOT NULL,
    target_type TEXT NOT NULL,
    target_id INTEGER NOT NULL,
    reason TEXT,
    details TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
"""

POSTGRESQL_SCHEMA = """
CREATE TABLE IF NOT EXISTS community_posts_v1 (
    id SERIAL PRIMARY KEY,
    user_hash VARCHAR(64) NOT NULL,
    session_id VARCHAR(64) NOT NULL,
    topic VARCHAR(50) NOT NULL,
    title VARCHAR(100) NOT NULL,
    body TEXT NOT NULL,
    status VARCHAR(20) DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    reactions_helped INTEGER DEFAULT 0,
    reactions_relate INTEGER DEFAULT 0,
    reactions_strength INTEGER DEFAULT 0,
    reactions_insight INTEGER DEFAULT 0,
    flags INTEGER DEFAULT 0,
    is_pinned BOOLEAN DEFAULT FALSE,
    is_locked BOOLEAN DEFAULT FALSE,
    reply_count INTEGER DEFAULT 0,
    view_count INTEGER DEFAULT 0,
    parent_id INTEGER REFERENCES community_posts_v1(id),
    metadata JSONB,
    tsv tsvector GENERATED ALWAYS AS (
        setweight(to_tsvector('english', coalesce(title, '')), 'A') ||
        setweight(to_tsvector('english', coalesce(body, '')), 'B')
    ) STORED
);

CREATE INDEX IF NOT EXISTS idx_posts_status ON community_posts_v1(status);
CREATE INDEX IF NOT EXISTS idx_posts_user ON community_posts_v1(user_hash);
CREATE INDEX IF NOT EXISTS idx_posts_created ON community_posts_v1(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_posts_search ON community_posts_v1 USING GIN(tsv);

CREATE TABLE IF NOT EXISTS community_reactions_v1 (
    id SERIAL PRIMARY KEY,
    post_id INTEGER NOT NULL REFERENCES community_posts_v1(id),
    user_hash VARCHAR(64) NOT NULL,
    session_id VARCHAR(64) NOT NULL,
    reaction_type VARCHAR(20) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(post_id, user_hash, reaction_type)
);

CREATE TABLE IF NOT EXISTS community_flags_v1 (
    id SERIAL PRIMARY KEY,
    post_id INTEGER NOT NULL REFERENCES community_posts_v1(id),
    user_hash VARCHAR(64) NOT NULL,
    session_id VARCHAR(64) NOT NULL,
    reason VARCHAR(50) NOT NULL,
    details TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    reviewed BOOLEAN DEFAULT FALSE,
    action_taken VARCHAR(20)
);

CREATE TABLE IF NOT EXISTS community_users_v1 (
    user_hash VARCHAR(64) PRIMARY KEY,
    session_id VARCHAR(64) NOT NULL,
    display_name VARCHAR(50),
    reputation INTEGER DEFAULT 0,
    posts_count INTEGER DEFAULT 0,
    reactions_given INTEGER DEFAULT 0,
    reactions_received INTEGER DEFAULT 0,
    is_banned BOOLEAN DEFAULT FALSE,
    ban_reason TEXT,
    ban_until TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_active TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS moderation_log_v1 (
    id SERIAL PRIMARY KEY,
    moderator_id VARCHAR(64) NOT NULL,
    action VARCHAR(20) NOT NULL,
    target_type VARCHAR(20) NOT NULL,
    target_id INTEGER NOT NULL,
    reason TEXT,
    details JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
"""
