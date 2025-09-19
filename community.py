from __future__ import annotations
import json
import re
from datetime import datetime
from typing import Any, Dict, List, Optional

from flask import Flask, jsonify, request
from sqlalchemy import text

from models import db

SEED_PATH = "data/community_seed.json"

SAFE_REACTION_KINDS = {"relate", "helped", "strength"}


def _dialect() -> str:
    try:
        eng = db.session.bind
        return eng.dialect.name if eng else "unknown"
    except Exception:
        return "unknown"


def _ensure_tables() -> None:
    """Create minimal community tables in a dialect-aware way (sqlite/pg)."""
    d = _dialect()
    try:
        if d == "sqlite":
            db.session.execute(text(
                """
                CREATE TABLE IF NOT EXISTS community_posts (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    topic TEXT,
                    body_redacted TEXT NOT NULL,
                    is_curated INTEGER DEFAULT 1,
                    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                    reactions_relate INTEGER DEFAULT 0,
                    reactions_helped INTEGER DEFAULT 0,
                    reactions_strength INTEGER DEFAULT 0
                )
                """
            ))
            db.session.execute(text(
                """
                CREATE TABLE IF NOT EXISTS community_reactions (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    post_id INTEGER NOT NULL,
                    kind TEXT NOT NULL,
                    user_hash TEXT,
                    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
                )
                """
            ))
            db.session.execute(text(
                """
                CREATE TABLE IF NOT EXISTS community_reports (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    target_type TEXT NOT NULL,
                    target_id INTEGER NOT NULL,
                    reason TEXT NOT NULL,
                    notes TEXT,
                    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
                )
                """
            ))
        else:  # assume postgres-compatible
            db.session.execute(text(
                """
                CREATE TABLE IF NOT EXISTS community_posts (
                    id SERIAL PRIMARY KEY,
                    topic VARCHAR(64),
                    body_redacted TEXT NOT NULL,
                    is_curated BOOLEAN DEFAULT TRUE,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    reactions_relate INTEGER DEFAULT 0,
                    reactions_helped INTEGER DEFAULT 0,
                    reactions_strength INTEGER DEFAULT 0
                )
                """
            ))
            db.session.execute(text(
                """
                CREATE TABLE IF NOT EXISTS community_reactions (
                    id SERIAL PRIMARY KEY,
                    post_id INTEGER NOT NULL,
                    kind VARCHAR(24) NOT NULL,
                    user_hash VARCHAR(64),
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
                """
            ))
            db.session.execute(text(
                """
                CREATE TABLE IF NOT EXISTS community_reports (
                    id SERIAL PRIMARY KEY,
                    target_type VARCHAR(24) NOT NULL,
                    target_id INTEGER NOT NULL,
                    reason VARCHAR(64) NOT NULL,
                    notes TEXT,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
                """
            ))
        db.session.commit()
    except Exception:
        try:
            db.session.rollback()
        except Exception:
            pass
        raise


EMAIL_RE = re.compile(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}")
PHONE_RE = re.compile(r"\b(?:\+\d{1,3}[\s-]?)?(?:\(?\d{2,4}\)?[\s-]?)?\d{3,4}[\s-]?\d{4}\b")
URL_RE = re.compile(r"\bhttps?://\S+\b", re.IGNORECASE)
ADDRESS_HINT_RE = re.compile(r"\b(?:Street|St\.|Avenue|Ave\.|Road|Rd\.|Lane|Ln\.|Block|Apartment|Apt\.)\b", re.IGNORECASE)


def _pii_redact(text_in: str) -> str:
    t = EMAIL_RE.sub("[email]", text_in)
    t = PHONE_RE.sub("[phone]", t)
    t = URL_RE.sub("[link]", t)
    # Light hint-based masking (keeps tone while removing specifics)
    t = ADDRESS_HINT_RE.sub("[address]", t)
    return t


def _load_seed_if_empty(app: Flask) -> None:
    count = db.session.execute(text("SELECT COUNT(*) FROM community_posts")).scalar() or 0
    if count > 0:
        return
    try:
        with app.open_resource(SEED_PATH) as f:
            items = json.load(f)
        for it in items:
            topic = (it.get("topic") or "general").strip()[:64]
            body = _pii_redact(it.get("body", "").strip())
            if not body:
                continue
            db.session.execute(text(
                """
                INSERT INTO community_posts (topic, body_redacted, is_curated)
                VALUES (:topic, :body, :is_curated)
                """
            ), {"topic": topic, "body": body, "is_curated": True})
        db.session.commit()
    except FileNotFoundError:
        # No seed file; skip silently
        pass
    except Exception:
        try:
            db.session.rollback()
        except Exception:
            pass


def register_community_routes(app: Flask) -> None:
    """Registers Phase 0 Community routes on the given app."""
    # Ensure tables exist and seed under an application context
    try:
        with app.app_context():
            _ensure_tables()
            try:
                _load_seed_if_empty(app)
            except Exception as e:
                try:
                    app.logger.warning(f"Community seed load failed: {e}")
                except Exception:
                    pass
    except Exception as e:
        try:
            app.logger.warning(f"Community init skipped: {e}")
        except Exception:
            pass

    def _enabled() -> bool:
        try:
            return str(app.config.get("COMMUNITY_ENABLED", "true")).lower() == "true"
        except Exception:
            return True

    def _posting_enabled() -> bool:
        """Posting is enabled only when COMMUNITY_POSTING_ENABLED=true and TEMPLATES_ONLY!=true"""
        try:
            posting_flag = str(app.config.get('COMMUNITY_POSTING_ENABLED', 'false')).lower() == 'true'
            templates_only = str(app.config.get('TEMPLATES_ONLY', 'false')).lower() == 'true'
            return posting_flag and not templates_only
        except Exception:
            return False

    # Rate limits (can be overridden via env -> app.config)
    limits_feed = str(app.config.get('RATE_LIMITS_COMMUNITY_FEED', '120 per minute'))
    limits_reaction = str(app.config.get('RATE_LIMITS_REACTION', '20 per minute; 200 per day'))
    limits_report = str(app.config.get('RATE_LIMITS_REPORT', '10 per minute; 100 per day'))
    limits_post = str(app.config.get('RATE_LIMITS_COMMUNITY_POST', '6 per minute; 60 per day'))

    @app.route('/api/community/feed', methods=['GET'])
    @app.limiter.limit(limits_feed)
    def community_feed():
        if not _enabled():
            return jsonify({"error": "Community disabled"}), 403
        try:
            topic = (request.args.get('topic') or '').strip()
            try:
                limit = int(request.args.get('limit', '20'))
            except Exception:
                limit = 20
            limit = max(1, min(limit, 50))

            q = "SELECT id, topic, body_redacted, created_at, reactions_relate, reactions_helped, reactions_strength FROM community_posts"
            params: Dict[str, Any] = {}
            if topic:
                q += " WHERE topic = :topic"
                params['topic'] = topic
            q += " ORDER BY created_at DESC, id DESC LIMIT :limit"
            params['limit'] = limit

            rows = db.session.execute(text(q), params).fetchall()
            items: List[Dict[str, Any]] = []
            for r in rows:
                created = r.created_at.isoformat() if getattr(r, 'created_at', None) else None
                items.append({
                    'id': r.id,
                    'topic': r.topic,
                    'body': r.body_redacted,
                    'created_at': created,
                    'reactions': {
                        'relate': r.reactions_relate or 0,
                        'helped': r.reactions_helped or 0,
                        'strength': r.reactions_strength or 0,
                    }
                })
            return jsonify({'items': items, 'count': len(items)}), 200
        except Exception as e:
            try:
                app.logger.error(f"Community feed error: {e}")
            except Exception:
                pass
            return jsonify({'error': 'Failed to fetch feed'}), 500

    @app.route('/api/community/reaction', methods=['POST'])
    @app.limiter.limit(limits_reaction)
    def community_reaction():
        if not _enabled():
            return jsonify({"error": "Community disabled"}), 403
        try:
            data = request.get_json(silent=True) or {}
            post_id = data.get('post_id')
            kind = (data.get('kind') or '').strip().lower()
            if not post_id or kind not in SAFE_REACTION_KINDS:
                return jsonify({'error': 'Invalid post_id or kind'}), 400

            # Optional user hash from session header (no PII)
            sid = (request.headers.get('X-Session-ID') or '').strip()
            user_hash = sid[:12] if sid else None

            # Insert reaction
            db.session.execute(text(
                """
                INSERT INTO community_reactions (post_id, kind, user_hash)
                VALUES (:post_id, :kind, :user_hash)
                """
            ), {'post_id': post_id, 'kind': kind, 'user_hash': user_hash})

            # Increment aggregate counter on post
            col = {
                'relate': 'reactions_relate',
                'helped': 'reactions_helped',
                'strength': 'reactions_strength',
            }[kind]
            db.session.execute(text(f"UPDATE community_posts SET {col} = {col} + 1 WHERE id = :pid"), {'pid': post_id})

            db.session.commit()
            return jsonify({'ok': True}), 201
        except Exception as e:
            try:
                db.session.rollback()
            except Exception:
                pass
            try:
                app.logger.error(f"Community reaction error: {e}")
            except Exception:
                pass
            return jsonify({'error': 'Failed to add reaction'}), 500

    @app.route('/api/community/report', methods=['POST'])
    @app.limiter.limit(limits_report)
    def community_report():
        if not _enabled():
            return jsonify({"error": "Community disabled"}), 403
        try:
            data = request.get_json(silent=True) or {}
            target_type = (data.get('target_type') or 'post').strip().lower()
            target_id = data.get('target_id')
            reason = (data.get('reason') or '').strip().lower()
            notes_raw = (data.get('notes') or '').strip() or None
            notes = _pii_redact(notes_raw) if notes_raw else None

            if target_type not in {'post'} or not target_id or not reason:
                return jsonify({'error': 'Invalid report'}), 400

            db.session.execute(text(
                """
                INSERT INTO community_reports (target_type, target_id, reason, notes)
                VALUES (:tt, :tid, :reason, :notes)
                """
            ), {'tt': target_type, 'tid': target_id, 'reason': reason, 'notes': notes})
            db.session.commit()
            return jsonify({'ok': True}), 201
        except Exception as e:
            try:
                db.session.rollback()
            except Exception:
                pass
            try:
                app.logger.error(f"Community report error: {e}")
            except Exception:
                pass
            return jsonify({'error': 'Failed to submit report'}), 500

    @app.route('/api/community/flags', methods=['GET'])
    @app.limiter.limit(limits_feed)
    def community_flags():
        try:
            return jsonify({
                'enabled': _enabled(),
                'posting_enabled': _posting_enabled(),
                'templates_only': str(app.config.get('TEMPLATES_ONLY', 'false')).lower() == 'true',
            }), 200
        except Exception as e:
            try:
                app.logger.warning(f"Community flags error: {e}")
            except Exception:
                pass
            return jsonify({'enabled': False, 'posting_enabled': False, 'templates_only': False}), 200

    @app.route('/api/community/post', methods=['POST'])
    @app.limiter.limit(limits_post)
    def community_post():
        if not _enabled():
            return jsonify({"error": "Community disabled"}), 403
        if not _posting_enabled():
            return jsonify({"error": "Community posting disabled"}), 403
        try:
            data = request.get_json(silent=True) or {}
            topic = (data.get('topic') or '').strip()[:64]
            body_raw = (data.get('body') or '').strip()
            if not body_raw:
                return jsonify({'error': 'Body is required'}), 400
            if len(body_raw) > 2000:
                # Hard stop on extremely long bodies (frontend uses 280 char soft limit)
                return jsonify({'error': 'Body too long'}), 400

            body = _pii_redact(body_raw)
            d = _dialect()
            created_at: Optional[datetime] = None
            new_id: Optional[int] = None

            if d == 'sqlite':
                db.session.execute(text(
                    """
                    INSERT INTO community_posts (topic, body_redacted, is_curated)
                    VALUES (:topic, :body, :is_curated)
                    """
                ), {"topic": topic or 'general', "body": body, "is_curated": False})
                # Fetch last inserted id and created_at
                new_id = db.session.execute(text("SELECT last_insert_rowid()")).scalar()
                created_at = db.session.execute(text("SELECT created_at FROM community_posts WHERE id = :id"), {"id": new_id}).scalar()
            else:
                res = db.session.execute(text(
                    """
                    INSERT INTO community_posts (topic, body_redacted, is_curated)
                    VALUES (:topic, :body, :is_curated)
                    RETURNING id, created_at
                    """
                ), {"topic": topic or 'general', "body": body, "is_curated": False})
                row = res.first()
                if row is not None:
                    new_id = row.id
                    created_at = row.created_at

            db.session.commit()

            created_iso: Optional[str] = None
            try:
                created_iso = created_at.isoformat() if isinstance(created_at, datetime) else (created_at or None)
            except Exception:
                created_iso = None

            return jsonify({
                'id': new_id,
                'topic': topic or 'general',
                'body': body,
                'created_at': created_iso,
                'reactions': {'relate': 0, 'helped': 0, 'strength': 0},
            }), 201
        except Exception as e:
            try:
                db.session.rollback()
            except Exception:
                pass
            try:
                app.logger.error(f"Community post error: {e}")
            except Exception:
                pass
            return jsonify({'error': 'Failed to create post'}), 500
