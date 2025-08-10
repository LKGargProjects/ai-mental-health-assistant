#!/usr/bin/env python3
"""
Minimal Consciousness CLI - A simplified interface for the consciousness system
"""
import json
import sys
import time
from pathlib import Path
from typing import Dict, List, Any, Optional
from datetime import datetime
import subprocess
import re

class SimpleConsciousnessCLI:
    def __init__(self, data_dir: Path = None):
        """Initialize with default or custom data directory."""
        self.data_dir = data_dir or Path("~/.consciousness").expanduser()
        self.data_dir.mkdir(parents=True, exist_ok=True)
        self.ideas_file = self.data_dir / "ideas.json"
        self._ensure_data_files()
    
    def _ensure_data_files(self):
        """Ensure required data files exist with proper structure."""
        if not self.ideas_file.exists():
            self.ideas_file.write_text('{"ideas": [], "version": "1.0"}')
    
    def list_ideas(self, status: str = None, priority: int = None) -> List[Dict[str, Any]]:
        """List ideas with optional filtering."""
        try:
            with open(self.ideas_file, 'r') as f:
                data = json.load(f)
            
            ideas = data.get("ideas", [])
            
            # Apply filters
            if status:
                ideas = [i for i in ideas if i.get("status") == status]
            if priority is not None:
                ideas = [i for i in ideas if i.get("priority") == priority]
            
            return ideas
            
        except Exception as e:
            print(f"Error reading ideas: {e}", file=sys.stderr)
            return []
    
    def add_idea(self, title: str, description: str, category: str, 
                priority: int = 3, tags: List[str] = None) -> bool:
        """Add a new idea to the system."""
        try:
            with open(self.ideas_file, 'r+') as f:
                data = json.load(f)
                new_idea = {
                    "id": str(int(time.time() * 1000)),
                    "title": title,
                    "description": description,
                    "category": category,
                    "priority": priority,
                    "tags": tags or [],
                    "status": "new",
                    "created_at": datetime.now().isoformat()
                }
                data["ideas"].append(new_idea)
                f.seek(0)
                json.dump(data, f, indent=2)
                f.truncate()
            return True
        except Exception as e:
            print(f"Error adding idea: {e}", file=sys.stderr)
            return False
    
    def update_idea(self, idea_id: str, **updates) -> bool:
        """Update an existing idea."""
        try:
            with open(self.ideas_file, 'r+') as f:
                data = json.load(f)
                for idea in data["ideas"]:
                    if str(idea.get("id")) == str(idea_id):
                        idea.update(updates)
                        idea["updated_at"] = datetime.now().isoformat()
                        f.seek(0)
                        json.dump(data, f, indent=2)
                        f.truncate()
                        return True
            return False
        except Exception as e:
            print(f"Error updating idea: {e}", file=sys.stderr)
            return False

    # --- One-file context generator ---
    def generate_context(self, out_path: Path, max_lines: int = 150) -> Path:
        """Generate a single-file CONTEXT.md for LLM upload.

        - Auto-detect repo root from this script's path.
        - Collect small, safe excerpts; degrade gracefully when files are missing.
        - Do not require extra dependencies; keep simple.
        """
        repo_root = Path(__file__).resolve().parents[1]

        # Pre-refresh lightweight docs so CONTEXT.md is always in sync
        freshness = self._refresh_docs(repo_root)

        def read_head(path: Path, n: int) -> str:
            try:
                with open(path, 'r', encoding='utf-8', errors='ignore') as f:
                    lines = f.readlines()[:n]
                return ''.join(lines).strip()
            except Exception:
                return ""

        def git_rev() -> str:
            try:
                return subprocess.check_output(["git", "rev-parse", "--short", "HEAD"], cwd=repo_root).decode().strip()
            except Exception:
                return "unknown"

        def flask_routes(app_py: Path, n: int) -> str:
            try:
                content = app_py.read_text(encoding='utf-8', errors='ignore').splitlines()
                routes = [f"{i+1}: {line}" for i, line in enumerate(content) if re.search(r"@app\.(route|get|post|put|delete)", line)]
                return "\n".join(routes[:n])
            except Exception:
                return ""

        def dart_public_api(dart_path: Path, n: int) -> str:
            try:
                content = dart_path.read_text(encoding='utf-8', errors='ignore')
                # crude extraction of class and public method lines
                snippet = []
                for line in content.splitlines():
                    if re.search(r"^\s*class\s+\w+", line) or re.search(r"^\s*(?:[A-Za-z_][\w<>?]*)\s+[A-Za-z_][\w]*\s*\(.*\)\s*\{?\s*$", line):
                        snippet.append(line)
                return "\n".join(snippet[:n])
            except Exception:
                return ""

        def sample_quests(json_path: Path, m: int = 3) -> str:
            try:
                data = json.loads(json_path.read_text(encoding='utf-8', errors='ignore'))
                # support either top-level list or {items: []}
                items = data.get('items') if isinstance(data, dict) else data
                if not isinstance(items, list):
                    return ""
                sample = items[:m]
                return json.dumps(sample, indent=2)[:3000]
            except Exception:
                return ""

        now = datetime.now().isoformat()
        sha = git_rev()

        arch_md = read_head(repo_root / "docs/ARCHITECTURE.md", max_lines)
        adrs_md = read_head(repo_root / "docs/ADRS.md", max_lines)
        status_yml = read_head(repo_root / "docs/status.yml", 200)
        quests_md = read_head(repo_root / "docs/frontend/QUESTS_ENGINE.md", max_lines) or read_head(repo_root / "WEEK0.md", max_lines)

        quests_dart = dart_public_api(repo_root / "ai_buddy_web/lib/quests/quests_engine.dart", max_lines)
        flask_api = flask_routes(repo_root / "app.py", 200)
        quests_sample = sample_quests(repo_root / "ai_buddy_web/assets/quests/quests.json", 3)

        # Build sources freshness summary
        freshness_lines = []
        for item in freshness:
            freshness_lines.append(f"- {item['path']} (modified: {item['last_modified']})")

        # Helper to read recent LLM insights from the log
        def read_recent_insights(log_path: Path, max_entries: int = 3) -> str:
            if not log_path.exists():
                return ""
            try:
                raw = log_path.read_text(encoding='utf-8', errors='ignore')
                chunks = raw.split("\n---\n")
                chunks = [c.strip() for c in chunks if c.strip()]
                tail = chunks[-max_entries:]
                return "\n\n".join(tail)
            except Exception:
                return ""

        llm_insights = read_recent_insights(repo_root / "docs/context/llm_insights.md", 3)

        sections = [
            f"# CONTEXT.md (LLM One-Pager)\n\n",
            f"## 0. Snapshot\n- Repo: {repo_root.name}\n- Git rev: {sha}\n- Last updated: {now}\n\n",
            ("## 0.1 Sources freshness\n" + "\n".join(freshness_lines) + "\n\n") if freshness_lines else "",
            "## 1. Architecture (TL;DR)\n" + (arch_md or "(docs/ARCHITECTURE.md not found)") + "\n\n",
            "## 2. ADRs (Decisions)\n" + (adrs_md or "(docs/ADRS.md not found)") + "\n\n",
            "## 3. Current Status\n" + (status_yml or "(docs/status.yml not found)") + "\n\n",
            "## 4. Quests Engine\n" + (quests_md or "(docs/frontend/QUESTS_ENGINE.md not found)") + "\n\n",
            "## 5. Key Interfaces (excerpts)\n### quests_engine.dart\n" + (quests_dart or "(ai_buddy_web/lib/quests/quests_engine.dart not found)") + "\n\n",
            "### app.py routes (partial)\n" + (flask_api or "(app.py not found or no routes detected)") + "\n\n",
            "## 6. Quests sample (redacted)\n" + (quests_sample or "(ai_buddy_web/assets/quests/quests.json sample unavailable)") + "\n",
            ("## 7. Recent LLM Insights (tail)\n" + llm_insights + "\n\n") if llm_insights else "",
        ]

        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_path.write_text("".join(sections), encoding='utf-8')
        return out_path

    def _refresh_docs(self, repo_root: Path) -> List[Dict[str, Any]]:
        """Lightweight refresh before generating context.
        - Ensure docs/ exists.
        - Update docs/status.yml last_updated to now (create minimal if missing).
        - Rebuild docs/context/context_index.json with basic metadata.
        Returns a list of file freshness info for inclusion.
        """
        docs_dir = repo_root / "docs"
        ctx_dir = docs_dir / "context"
        docs_dir.mkdir(parents=True, exist_ok=True)
        ctx_dir.mkdir(parents=True, exist_ok=True)

        # Update or create status.yml
        status_path = docs_dir / "status.yml"
        now_iso = datetime.now().isoformat()
        try:
            if status_path.exists():
                lines = status_path.read_text(encoding='utf-8', errors='ignore').splitlines()
                updated = False
                for i, line in enumerate(lines):
                    if line.strip().startswith("last_updated:"):
                        lines[i] = f"last_updated: {now_iso}"
                        updated = True
                        break
                if not updated:
                    lines.append(f"last_updated: {now_iso}")
                status_path.write_text("\n".join(lines) + "\n", encoding='utf-8')
            else:
                status_path.write_text(
                    "\n".join([
                        "version: 0.1",
                        "frontend:",
                        "  app: ai_buddy_web",
                        "backend:",
                        "  app: flask",
                        f"last_updated: {now_iso}",
                        ""
                    ]),
                    encoding='utf-8'
                )
        except Exception:
            pass

        # Build a minimal context index
        candidates = [
            "docs/ARCHITECTURE.md",
            "docs/ADRS.md",
            "docs/TESTING.md",
            "docs/frontend/QUESTS_ENGINE.md",
            "docs/backend/CRISIS_DETECTION.md",
            "docs/schemas/quests.schema.json",
        ]
        index: List[Dict[str, Any]] = []
        for rel in candidates:
            p = repo_root / rel
            if not p.exists():
                continue
            summary = ""
            try:
                with open(p, 'r', encoding='utf-8', errors='ignore') as f:
                    for _ in range(20):
                        line = f.readline()
                        if not line:
                            break
                        if line.strip():
                            summary = line.strip()
                            break
            except Exception:
                summary = ""
            try:
                mtime = datetime.fromtimestamp(p.stat().st_mtime).isoformat()
            except Exception:
                mtime = "unknown"
            index.append({
                "path": rel,
                "summary": summary,
                "last_modified": mtime,
                "size": p.stat().st_size if p.exists() else 0
            })

        try:
            (repo_root / "docs/context/context_index.json").write_text(
                json.dumps(index, indent=2), encoding='utf-8')
        except Exception:
            pass

        return index

    # --- External LLM insights ingestion ---
    def ingest_llm_insight(self, repo_root: Path, source: str, text: str) -> Path:
        """Append an external LLM brainstorming note to docs/context/llm_insights.md.
        Each entry is timestamped and prefixed with the source (e.g., chatgpt, perplexity, windsurf).
        """
        log_path = repo_root / "docs/context/llm_insights.md"
        log_path.parent.mkdir(parents=True, exist_ok=True)
        now_iso = datetime.now().isoformat()
        entry = (
            f"\n---\n"
            f"timestamp: {now_iso}\n"
            f"source: {source}\n"
            f"content:\n\n{text.strip()}\n"
        )
        with open(log_path, "a", encoding="utf-8") as f:
            f.write(entry)
        return log_path

def main():
    """Main entry point for the CLI."""
    import argparse
    
    # Use the project's consciousness directory
    data_dir = Path("/Users/lokeshgarg/ai-mvp-backend/consciousness/.consciousness")
    cli = SimpleConsciousnessCLI(data_dir)
    
    parser = argparse.ArgumentParser(description="Simple Consciousness CLI")
    subparsers = parser.add_subparsers(dest="command", required=True)
    
    # List command
    list_parser = subparsers.add_parser("list", help="List ideas")
    list_parser.add_argument("--status", help="Filter by status")
    list_parser.add_argument("--priority", type=int, help="Filter by priority")
    
    # Add command
    add_parser = subparsers.add_parser("add", help="Add a new idea")
    add_parser.add_argument("title", help="Idea title")
    add_parser.add_argument("description", help="Idea description")
    add_parser.add_argument("category", help="Idea category")
    add_parser.add_argument("--priority", type=int, default=3, help="Priority (1-5, 1=highest)")
    add_parser.add_argument("--tags", help="Comma-separated list of tags")
    
    # Update command
    update_parser = subparsers.add_parser("update", help="Update an idea")
    update_parser.add_argument("idea_id", help="ID of the idea to update")
    update_parser.add_argument("--status", help="New status")
    update_parser.add_argument("--priority", type=int, help="New priority")

    # Context command
    context_parser = subparsers.add_parser("context", help="Generate single-file CONTEXT.md for LLM upload")
    context_parser.add_argument("--out", help="Output path (default: <repo>/CONTEXT.md)")
    context_parser.add_argument("--max-lines", type=int, default=150, help="Max lines per included section (default: 150)")

    # Ingest command
    ingest_parser = subparsers.add_parser("ingest", help="Append external LLM insight into docs/context/llm_insights.md")
    ingest_parser.add_argument("--source", type=str, default='external', help='chatgpt|perplexity|windsurf|cursor|other')
    grp = ingest_parser.add_mutually_exclusive_group(required=True)
    grp.add_argument("--text", type=str, help='Raw insight text to append')
    grp.add_argument("--file", type=str, help='Path to a file whose contents will be appended')

    args = parser.parse_args()
    
    try:
        if args.command == "list":
            ideas = cli.list_ideas(status=args.status, priority=args.priority)
            if not ideas:
                print("No ideas found.")
            else:
                for idea in ideas:
                    print(f"ID: {idea['id']}")
                    print(f"Title: {idea['title']}")
                    print(f"Status: {idea.get('status', 'unknown')}")
                    print(f"Priority: {idea.get('priority', 'N/A')}")
                    print("-" * 40)
                    
        elif args.command == "add":
            tags = args.tags.split(",") if args.tags else None
            if cli.add_idea(
                title=args.title,
                description=args.description,
                category=args.category,
                priority=args.priority,
                tags=tags
            ):
                print("Idea added successfully.")
            else:
                print("Failed to add idea.", file=sys.stderr)
                sys.exit(1)
                
        elif args.command == "update":
            updates = {}
            if args.status:
                updates["status"] = args.status
            if args.priority is not None:
                updates["priority"] = args.priority
                
            if not updates:
                print("No updates specified.", file=sys.stderr)
                sys.exit(1)
                
            if cli.update_idea(args.idea_id, **updates):
                print("Idea updated successfully.")
            else:
                print("Failed to update idea. Make sure the ID is correct.", file=sys.stderr)
                sys.exit(1)

        elif args.command == "context":
            # Determine repo root two levels up from this file
            repo_root = Path(__file__).resolve().parents[1]
            out = Path(args.out) if args.out else (repo_root / "CONTEXT.md")
            path = cli.generate_context(out_path=out, max_lines=args.max_lines)
            print(str(path))
                
        elif args.command == "ingest":
            if args.text is not None:
                text = args.text
            else:
                text = Path(args.file).read_text(encoding='utf-8', errors='ignore')
            repo_root = Path(__file__).resolve().parents[1]
            path = cli.ingest_llm_insight(repo_root, args.source, text)
            print(str(path))
    
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
        print(f"\nDescription:\n{idea.get('description')}")
        
        if 'tags' in idea and idea['tags']:
            print(f"\nTags: {', '.join(idea['tags'])}")
        
        print("=" * 60 + "\n")
    
    else:
        parser.print_help()

if __name__ == "__main__":
    main()
