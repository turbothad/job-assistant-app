# Cursor Chat History Recovery Guide

This guide will help you recover lost chat history from Cursor's workspace storage using the provided scripts.

## Quick Start

### 1. Setup Dependencies

For Python script:
```bash
# No additional dependencies required - uses only standard library
python3 export_chats.py --help
```

For Node.js script:
```bash
# Install commander for CLI functionality (optional)
npm install commander

# Or use programmatically without commander
node clean_history.js --help
```

### 2. Basic Recovery Workflow

```bash
# Step 1: List available databases
python3 export_chats.py --list-databases

# Step 2: Export with broad keywords
python3 export_chats.py --keywords "rails,api,ruby" --output-dir ./exports

# Step 3: Clean and process the data
node clean_history.js -i exports/cursor_chats_*.json -o cleaned -p "job-assistant-app"
```

## Detailed Usage

### Export Script (export_chats.py)

The Python script searches through SQLite databases in Cursor's workspace storage and extracts chat-related data.

#### Options:
- `--storage-path`: Custom path to workspace storage (default: Mac default location)
- `--keywords`: Comma-separated keywords to search for
- `--start-date`: Filter by start date (YYYY-MM-DD format)
- `--end-date`: Filter by end date (YYYY-MM-DD format)
- `--output-dir`: Output directory (default: ./exports)
- `--list-databases`: Just list found databases and exit

#### Examples:

```bash
# List all available databases
python3 export_chats.py --list-databases

# Export all chats (be careful - can be very large)
python3 export_chats.py --output-dir ./exports

# Search for Rails/Ruby related chats
python3 export_chats.py --keywords "rails,ruby,api,authentication" --output-dir ./exports

# Search for recent chats (last month)
python3 export_chats.py --start-date "2024-01-01" --keywords "rails" --output-dir ./exports

# Search specific time period
python3 export_chats.py --start-date "2024-01-15" --end-date "2024-02-15" --keywords "job,assistant" --output-dir ./exports
```

### Cleaning Script (clean_history.js)

The Node.js script processes the exported JSON data, cleaning formatting and organizing by relevance.

#### Options:
- `-i, --input <file>`: Input JSON file from export_chats.py (required)
- `-o, --output <dir>`: Output directory (default: ./cleaned)
- `-p, --project <name>`: Project name to filter by
- `--min-length <number>`: Minimum message length (default: 20)
- `--max-length <number>`: Maximum message length (default: 10000)
- `--no-clean-markdown`: Keep markdown formatting
- `--no-filter-project`: Skip project relevance filtering

#### Examples:

```bash
# Basic cleaning with project filter
node clean_history.js -i exports/cursor_chats_rails_20240201_143022.json -o cleaned -p "job-assistant-app"

# Keep markdown formatting
node clean_history.js -i exports/cursor_chats_api_20240201_143022.json -o cleaned --no-clean-markdown

# Process without project filtering
node clean_history.js -i exports/cursor_chats_all_20240201_143022.json -o cleaned --no-filter-project

# Custom message length filtering
node clean_history.js -i exports/cursor_chats_rails_20240201_143022.json -o cleaned --min-length 50 --max-length 5000
```

## Search Strategies

### Phase 1: Broad Discovery

Start with general terms to understand what's available:

```bash
# Technology stack
python3 export_chats.py --keywords "rails,ruby,api" --output-dir ./phase1

# General development terms
python3 export_chats.py --keywords "implement,create,build,add" --output-dir ./phase1

# Problem-solving terms
python3 export_chats.py --keywords "error,fix,debug,issue" --output-dir ./phase1
```

### Phase 2: Specific Features

Based on Phase 1 results, search for specific features:

```bash
# Authentication system
python3 export_chats.py --keywords "auth,login,jwt,session,oauth" --output-dir ./phase2

# Database/models
python3 export_chats.py --keywords "model,migration,database,activerecord" --output-dir ./phase2

# API endpoints
python3 export_chats.py --keywords "endpoint,controller,route,params" --output-dir ./phase2

# Services and business logic
python3 export_chats.py --keywords "service,job,worker,background" --output-dir ./phase2
```

### Phase 3: Time-based Recovery

If you remember approximate timeframes:

```bash
# Last week
python3 export_chats.py --start-date "2024-01-25" --keywords "rails" --output-dir ./recent

# Specific feature development period
python3 export_chats.py --start-date "2024-01-10" --end-date "2024-01-20" --keywords "authentication" --output-dir ./auth_period

# Before a major change
python3 export_chats.py --end-date "2024-01-15" --keywords "api,controller" --output-dir ./before_change
```

## Recommended Keywords by Category

### Rails/Ruby Application
```
Core: rails, ruby, gem, bundle, rake
Models: model, activerecord, migration, schema, database
Controllers: controller, action, params, render, redirect
Views: view, erb, template, partial, helper
Routes: route, routes, namespace, resource, member
Services: service, job, worker, sidekiq, background
Authentication: auth, login, logout, session, jwt, oauth, devise
API: api, json, xml, response, request, endpoint
Testing: test, spec, rspec, minitest, factory, fixture
```

### General Development
```
Implementation: implement, create, build, add, develop, code
Problem Solving: error, exception, bug, fix, debug, issue, problem
Architecture: class, module, method, function, variable, constant
Patterns: service, factory, observer, decorator, strategy
Database: sql, query, join, index, migration, seed
Security: secure, validate, sanitize, authorize, permission
Performance: optimize, cache, index, slow, fast, memory
Deployment: deploy, production, staging, environment, config
```

### Project-Specific
```
Job Assistant: job, assistant, application, resume, career
Features: search, filter, sort, pagination, upload, download
Integration: api, webhook, external, third-party, service
Data: import, export, csv, json, parse, format
UI/UX: interface, design, layout, responsive, mobile
```

## Output Structure

### Export Script Output
- `cursor_chats_<keywords>_<timestamp>.json`: Complete export with metadata
- Contains: workspace info, raw database data, extracted text, timestamps

### Cleaning Script Output
- `cleaned_chats_<timestamp>.json`: Processed and organized data
- `summary_<timestamp>.json`: Analysis summary with statistics
- `summary_<timestamp>.txt`: Human-readable summary report
- `code_snippets_<timestamp>.txt`: Extracted code from conversations
- `workspaces/`: Individual files for most important workspaces

## Analysis Approach

### 1. Start with Summary
Review `summary_<timestamp>.txt` to understand:
- Which workspaces have the most relevant content
- What keywords appear most frequently
- Which conversations contain code

### 2. Check Code Snippets
Review `code_snippets_<timestamp>.txt` for:
- Implementation details
- API endpoint definitions
- Model structures
- Service class patterns

### 3. Deep Dive into Workspaces
Examine individual workspace files for:
- Complete conversation context
- Development decisions and reasoning
- Debugging sessions
- Feature implementation discussions

## Tips for Effective Recovery

### 1. Multiple Search Passes
- Start broad, then narrow down
- Use different keyword combinations
- Try both technical and natural language terms

### 2. Time-based Correlation
- Cross-reference with git commits
- Look at file modification dates
- Consider project milestones

### 3. Reconstruct Context
- Look for conversation threads
- Identify related discussions across workspaces
- Connect code snippets to implementation

### 4. Validate Findings
- Compare recovered code with current implementation
- Check for version differences
- Verify against project requirements

## Troubleshooting

### Common Issues

1. **No databases found**
   - Check storage path: `~/Library/Application Support/Cursor/User/workspaceStorage`
   - Verify Cursor has been used on this machine
   - Try custom path with `--storage-path`

2. **Empty results**
   - Try broader keywords
   - Remove date filters
   - Check different workspaces

3. **Too many results**
   - Add more specific keywords
   - Use date filtering
   - Increase minimum message length

4. **Commander module not found**
   - Install: `npm install commander`
   - Or use programmatically without CLI

### Performance Considerations

- Large exports can take several minutes
- Consider filtering by date to reduce size
- Process in batches for very large datasets
- Use SSD storage for better performance

## Advanced Usage

### Programmatic Usage (Python)
```python
from export_chats import CursorChatExporter

exporter = CursorChatExporter()
databases = exporter.find_databases()
output_file = exporter.export_chats(
    output_dir="./custom_exports",
    keywords=["rails", "api"],
    start_date="2024-01-01"
)
```

### Programmatic Usage (Node.js)
```javascript
const ChatHistoryCleaner = require('./clean_history.js');

const cleaner = new ChatHistoryCleaner();
const processed = cleaner.process('input.json', {
    projectName: 'my-project',
    filterByProject: true
});
cleaner.save(processed, './output');
```

## Next Steps After Recovery

1. **Organize Findings**
   - Create project-specific folders
   - Group related conversations
   - Document key insights

2. **Reconstruct Code**
   - Extract complete code snippets
   - Identify dependencies and relationships
   - Recreate implementation from discussions

3. **Verify and Update**
   - Compare with current codebase
   - Update with any improvements from discussions
   - Document lessons learned

4. **Backup Strategy**
   - Export chat history regularly
   - Use version control for important conversations
   - Document architectural decisions

Remember: Chat recovery is an iterative process. Start broad, refine your searches, and gradually build a complete picture of your lost work.
