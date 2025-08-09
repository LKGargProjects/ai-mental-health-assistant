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
                
        elif args.command == "show":
            idea = cli.show_idea(args.idea_id)
            if not idea:
                print(f"Idea with ID {args.idea_id} not found.")
                return
                
            print("\n" + "=" * 60)
            print(f"ID: {idea.get('id')}")
            print(f"Title: {idea.get('title')}")
            print(f"Status: {idea.get('status', 'new')}")
            print(f"Priority: {idea.get('priority')}")
            print(f"Category: {idea.get('category', 'uncategorized')}")
            print(f"Created: {idea.get('created_at')}")
            if 'updated_at' in idea:
                print(f"Updated: {idea.get('updated_at')}")
            print(f"\nDescription:\n{idea.get('description')}")
            
            if 'tags' in idea and idea['tags']:
                print(f"\nTags: {', '.join(idea['tags'])}")
            
            print("=" * 60 + "\n")
    
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
