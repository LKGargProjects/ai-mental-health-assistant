# Data Inventory Snapshot — AI Mental Health Assistant

Snapshot time: 2025-08-24 13:40 IST

## Render resources
- __Backend (primary)__: `ai-mental-health-backend-3w4b` (ID `srv-d2fak0ogjchc73fd8r60`)
  - Type: Web service (Docker)
  - Region: Oregon (US)
  - URL: https://ai-mental-health-backend-3w4b.onrender.com
- __Backend (older)__: `ai-mental-health-assistant-tddc` (ID `srv-d193plvfte5s73bv8os0`)
  - Type: Web service (Python)
  - Region: Singapore
  - Auto-deploy: disabled
- __Postgres__: `ai-mvp-db` (ID `dpg-d22ifsh5pdvs7391j5f0-a`)
  - Version: 16, Region: Singapore
  - Size: 8.0 MB

Relevant code references:
- Backend app config in `app.py` and `render.yaml`
- ORM models in `models.py`

## Redis status
- No managed Redis instance on Render (likely external via `REDIS_URL`).
- Production health logs confirm active Redis connectivity:
  - Example: `redis=healthy redis_ms=127` (multiple samples 126–130ms)
  - Source: service logs for `srv-d2fak0ogjchc73fd8r60`.

## Postgres tables — exact row counts
| Table                      | Rows | Status   |
|---------------------------|-----:|----------|
| conversation_logs         |   81 | Active   |
| messages                  |   14 | Active   |
| user_sessions             |   62 | Active   |
| self_assessment_entries   |    3 | Active   |
| crisis_events             |    0 | Active   |
| mood_entries              |   35 | Legacy   |
| sessions                  |   68 | Legacy   |
| analytics_events          |    1 | Legacy   |
| self_assessments          |    0 | Legacy   |
| chat_messages             |    0 | Legacy   |
| crisis_detections         |    0 | Legacy   |

Model-to-table mapping (from `models.py`):
- Active models: `user_sessions`, `messages`, `conversation_logs`, `crisis_events`, `self_assessment_entries`.
- Tables marked Legacy are not defined by current models and appear unused.

## Table size estimates (pretty)
- conversation_logs — table: 16 kB, index: 16 kB, total: 56 kB
- messages — table: 8192 bytes, index: 16 kB, total: 32 kB
- user_sessions — table: 8192 bytes, index: 16 kB, total: 24 kB
- self_assessment_entries — table: 8192 bytes, index: 16 kB, total: 32 kB
- crisis_events — table: 0 bytes, index: 8192 bytes, total: 8192 bytes
- mood_entries — table: 8192 bytes, index: 16 kB, total: 64 kB
- sessions — table: 8192 bytes, index: 16 kB, total: 56 kB
- analytics_events — table: 8192 bytes, index: 16 kB, total: 32 kB
- self_assessments — table: 0 bytes, index: 8192 bytes, total: 16 kB
- chat_messages — table: 0 bytes, index: 8192 bytes, total: 16 kB
- crisis_detections — table: 0 bytes, index: 8192 bytes, total: 16 kB

Database size: 8.0 MB

## Queries used (reproducible)

Row counts per table:
```sql
select 'analytics_events' as name, count(*)::bigint as rows from analytics_events
union all
select 'chat_messages', count(*) from chat_messages
union all
select 'conversation_logs', count(*) from conversation_logs
union all
select 'crisis_detections', count(*) from crisis_detections
union all
select 'crisis_events', count(*) from crisis_events
union all
select 'messages', count(*) from messages
union all
select 'mood_entries', count(*) from mood_entries
union all
select 'self_assessment_entries', count(*) from self_assessment_entries
union all
select 'self_assessments', count(*) from self_assessments
union all
select 'sessions', count(*) from sessions
union all
select 'user_sessions', count(*) from user_sessions
order by name;
```

Table and index size estimates:
```sql
with stats as (
  select schemaname, relname, n_live_tup
  from pg_stat_user_tables
),
 sizes as (
  select n.nspname as schemaname, c.relname,
         pg_total_relation_size(c.oid) as total_size_bytes,
         pg_relation_size(c.oid) as table_size_bytes,
         pg_indexes_size(c.oid) as index_size_bytes
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where c.relkind='r' and n.nspname not in ('pg_catalog','information_schema')
)
select s.schemaname, s.relname as table,
       s.n_live_tup as row_estimate,
       pg_size_pretty(sz.table_size_bytes) as table_size,
       pg_size_pretty(sz.index_size_bytes) as index_size,
       pg_size_pretty(sz.total_size_bytes) as total_size
from stats s
join sizes sz on s.schemaname=sz.schemaname and s.relname=sz.relname
order by sz.total_size_bytes desc;
```

Database size:
```sql
select pg_size_pretty(pg_database_size(current_database())) as database_size;
```

## Risks and observations
- __Cross-region latency__: Backend is in Oregon while Postgres is in Singapore; health checks show DB latency ~0.48–0.80s. Consider co-locating services (move backend to Singapore or DB to Oregon) to reduce p95.
- __Redis latency__: Redis health ~126–130ms suggests non-local/external Redis. Align Redis region/provider with backend to cut session/rate-limit overhead.
- __Legacy tables__: The legacy tables likely come from earlier iterations. Plan archival and eventual drop after retention window.

## Next steps (recommended)
- Decide on co-location plan (backend ↔ DB ↔ Redis) for latency reduction.
- Confirm external Redis provider/region and HA/backups.
- Create a deprecation+archival plan for legacy tables.
