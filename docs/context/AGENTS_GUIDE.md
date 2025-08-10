# Agents Guide (Windsurf/Cursor/LLMs)

Use this exact workflow to keep CONTEXT.md fresh and bounded:

1) Update single-file context
- Run: `python3 consciousness/consciousness_cli.py context`
- Or: `bash scripts/update_context.sh`
- Output: `CONTEXT.md` at repo root

2) Read order for tools/LLMs
- Start: `docs/INDEX.md`
- Machine index: `docs/context/context_index.json`
- Status snapshot: `docs/status.yml`
- Quests system: `docs/frontend/QUESTS_ENGINE.md` + `docs/schemas/quests.schema.json`
- Backend routes: scan decorators in `app.py`

3) Guardrails
- Do not invent files/paths; cite exact repo paths
- Prefer links to canonical docs over duplicating content
- Keep edits in small PRs and avoid changing schema without validation

4) When asked to “document it”
- Update `CONTEXT.md`
- If decisions changed, append a bullet to `docs/ADRS.md`
- If quests catalog changed, validate against `docs/schemas/quests.schema.json`
