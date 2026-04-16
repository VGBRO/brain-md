# 🎨 Migration Pipeline Dashboard

An interactive web-based dashboard for tracking your Einstein Bot to NGA Agent migration progress in real-time.

## 🚀 Quick Start

### Option 1: Start Dashboard Only

```bash
python3 dashboard/server.py
```

Then open your browser to: **http://localhost:8080**

### Option 2: Start Dashboard in Background

```bash
# macOS/Linux
python3 dashboard/server.py &
open http://localhost:8080

# Or with nohup to keep it running
nohup python3 dashboard/server.py > dashboard/server.log 2>&1 &
open http://localhost:8080
```

## 📊 Features

### Visual Pipeline Tracker
- **6 interactive steps** with real-time status indicators
- **Progress bar** showing overall migration completion
- **Color-coded status**: Pending (gray), In Progress (orange), Completed (green), Error (red)

### Step Details
- Clear descriptions of what each step does
- Checkpoint indicators for steps requiring user confirmation
- Estimated time and complexity

### Interactive Controls
- **Start/Resume buttons** for each step
- **Re-run** completed steps if needed
- **View logs** for debugging

### Artifact Management
- **Auto-discovery** of generated files
- **Quick access** to bot.json, architecture docs, AgentScript files
- **File metadata** (size, modified time)

### Auto-Refresh
- Dashboard polls for updates every 5 seconds
- No manual refresh needed
- Real-time progress tracking

## 🔧 Updating Dashboard from CLI

The dashboard can be updated programmatically as each skill runs:

### Mark Step as Started
```bash
python3 dashboard/update_status.py start 1
```

### Mark Step as Completed
```bash
python3 dashboard/update_status.py complete 1
```

### Add Generated Artifact
```bash
python3 dashboard/update_status.py artifact bot.json
```

### Mark Step as Errored
```bash
python3 dashboard/update_status.py error 2 "Failed to parse metadata"
```

### View Current Status
```bash
python3 dashboard/update_status.py show
```

### Reset All Progress
```bash
python3 dashboard/update_status.py reset
```

## 🔗 Integration with Skills

Each skill can update the dashboard by calling the update script:

```python
# At the start of a skill
import subprocess
subprocess.run(["python3", "dashboard/update_status.py", "start", "1"])

# When generating an artifact
subprocess.run(["python3", "dashboard/update_status.py", "artifact", "bot.json"])

# On completion
subprocess.run(["python3", "dashboard/update_status.py", "complete", "1"])

# On error
subprocess.run(["python3", "dashboard/update_status.py", "error", "1", "Error message"])
```

## 📁 File Structure

```
dashboard/
├── index.html              # Main dashboard UI (with master control)
├── server.py              # HTTP server with API endpoints
├── update_status.py       # CLI tool for updating status
├── orchestrator.py        # Master orchestrator script (NEW!)
├── pipeline_status.json   # Status persistence (auto-generated)
├── server.log            # Server logs (if running with nohup)
└── README.md             # This file
```

## 🚀 Master Control

The dashboard now includes a **"Start Full Migration"** button that orchestrates all 6 steps sequentially.

### Running Full Migration

**Option 1: Via Dashboard Button**
1. Open http://localhost:8080
2. Click "Start Full Migration"
3. Execute the shown command in Claude Code CLI
4. Watch progress update automatically

**Option 2: Via Orchestrator Script**
```bash
python3 dashboard/orchestrator.py
```

This interactive script guides you through each step and updates the dashboard in real-time.

## 🎯 Pipeline Steps

Step names now match the actual skill commands:

1. **01-retrieve-bots-metadata** - Pre-process bot structure and filter noise
2. **02-process-and-build-inventory** - Generate complete inventory from metadata
3. **03-map-dialogs-actions-to-topics** - Map dialogs/actions to AgentScript topics
4. **04-generate-agentscript** - Generate complete agentscript from topics
5. **05-compile-agentscript** - Self-healing compilation with auto-fix
6. **06-deploy-agent-to-org** - Deploy to Salesforce org with confirmation

Each step card shows:
- Display name (e.g., "Step 1: Retrieve Bot Metadata")
- Skill command (e.g., "/01-retrieve-bots-metadata")
- Full description
- Checkpoint warnings where applicable

## 🌐 API Endpoints

The dashboard server provides REST API endpoints:

### GET /api/status
Returns current pipeline status as JSON.

```bash
curl http://localhost:8080/api/status
```

### POST /api/status
Update pipeline status.

```bash
curl -X POST http://localhost:8080/api/status \
  -H "Content-Type: application/json" \
  -d '{"1": "completed", "artifacts": ["bot.json"]}'
```

### GET /api/artifacts
List all generated artifacts in the data directory.

```bash
curl http://localhost:8080/api/artifacts
```

## 🛠️ Troubleshooting

### Port Already in Use
If port 8080 is busy, edit `server.py` and change the `PORT` constant:

```python
PORT = 8081  # Or any available port
```

### Dashboard Not Updating
1. Check that `pipeline_status.json` is being written to
2. Look for browser console errors
3. Verify the server is running: `ps aux | grep server.py`

### Server Won't Start
Ensure you have Python 3.6+ installed:

```bash
python3 --version
```

## 💡 Tips

- **Keep dashboard open** in a browser tab while running migration steps
- **Use the reset button** to start fresh if testing
- **Check artifacts** after each step to verify outputs
- **Monitor logs** if a step fails for debugging clues

## 🔮 Future Enhancements

- WebSocket support for instant updates (no polling)
- Detailed logs viewer in the UI
- Step execution time tracking
- Export progress report as PDF
- Integration with Slack/Teams for notifications
