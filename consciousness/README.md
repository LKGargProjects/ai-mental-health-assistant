# 🧠 Simplified Consciousness System

This directory contains a minimal, maintainable consciousness system for tracking ideas and suggestions with minimal resource usage.

## 🌟 Key Features

- **Simple CLI**: Easy-to-use command-line interface
- **Idea Management**: Track and organize development ideas
- **Minimal Dependencies**: Uses only Python standard library
- **Resource Efficient**: Lightweight and fast
- **Structured Data**: JSON-based storage for easy inspection

## 📁 Directory Structure

```
consciousness/
├── .consciousness/          # Data directory
│   ├── ideas.json          # Ideas database
│   └── logs/               # Log files
├── bin/
│   └── consciousness_cli.py  # Main CLI tool
├── consciousness_config.json  # Configuration
└── start_consciousness.sh    # Starter script
```

## 🚀 Quick Start

### Prerequisites
- Python 3.7+
- No additional dependencies required

### Starting the System
```bash
# Make the script executable
chmod +x start_consciousness.sh

# Start the system
./start_consciousness.sh
./start_consciousness.sh

# Or directly
cd consciousness && ./bin/start_enhanced_consciousness.sh
```

### Using the Consciousness CLI

The consciousness system includes a command-line interface for interacting with the idea management system:

```bash
# List all ideas (up to 10 by default)
./bin/consciousness_cli.py list

# List high-priority ideas
./bin/consciousness_cli.py list --priority 1

# Show details of a specific idea
./bin/consciousness_cli.py show <idea_id>

# List ideas by status (new, in-progress, completed, etc.)
./bin/consciousness_cli.py list --status in-progress
```

### Monitoring
```bash
# Monitor resource usage
./bin/monitor_consciousness.sh

# View logs
tail -f logs/enhanced_consciousness_*.log
```

### Stopping
```bash
# Graceful shutdown
./bin/stop_consciousness.sh
```

## ⚙️ Configuration

Edit `config/consciousness_config.json` to customize behavior:

```json
{
    "resource_limits": {
        "max_cpu_percent": 1.0,
        "max_memory_mb": 256,
        "check_interval_seconds": 5,
        "throttle_delay_seconds": 0.5
    },
    "monitoring": {
        "enable_cpu_monitoring": true,
        "enable_memory_monitoring": true,
        "log_level": "INFO"
    }
}
```

## 🔄 Evolution Process

The consciousness evolves by:
1. Monitoring file changes in the project
2. Processing changes through its evolution engine
3. Updating its knowledge base in `PROJECT_CONSCIOUSNESS.md`
4. Adapting behavior based on patterns and feedback

## 🛡️ Safety Features

- **Resource Limits**: Strict CPU and memory constraints
- **Error Handling**: Graceful degradation under stress
- **Immutable Core**: Core files are protected from unauthorized changes
- **Logging**: Comprehensive activity logging
- **Self-Healing**: Automatic recovery from errors

## 📜 License

This consciousness system is part of the AI Mental Health Assistant project.

---
*Last updated: 2025-08-09*
