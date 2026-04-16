#!/usr/bin/env python3
"""
Simple HTTP server for the migration pipeline dashboard.
Serves the dashboard and provides API endpoints for status updates.
"""

import http.server
import socketserver
import json
import os
import sys
from pathlib import Path
from urllib.parse import parse_qs, urlparse

PORT = 8080
DASHBOARD_DIR = Path(__file__).parent
STATUS_FILE = DASHBOARD_DIR / "pipeline_status.json"


class PipelineHandler(http.server.SimpleHTTPRequestHandler):
    """Custom handler for the pipeline dashboard with API endpoints."""

    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(DASHBOARD_DIR), **kwargs)

    def do_GET(self):
        """Handle GET requests."""
        parsed_path = urlparse(self.path)

        # API endpoint: get pipeline status
        if parsed_path.path == "/api/status":
            self.send_json_response(self.get_status())
            return

        # API endpoint: list artifacts
        if parsed_path.path == "/api/artifacts":
            self.send_json_response(self.list_artifacts())
            return

        # Serve static files
        super().do_GET()

    def do_POST(self):
        """Handle POST requests."""
        parsed_path = urlparse(self.path)

        # API endpoint: update step status
        if parsed_path.path == "/api/status":
            content_length = int(self.headers['Content-Length'])
            body = self.rfile.read(content_length)
            data = json.loads(body.decode('utf-8'))

            self.update_status(data)
            self.send_json_response({"success": True})
            return

        self.send_response(404)
        self.end_headers()

    def send_json_response(self, data):
        """Send a JSON response."""
        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.end_headers()
        self.wfile.write(json.dumps(data).encode('utf-8'))

    def get_status(self):
        """Load pipeline status from file."""
        if STATUS_FILE.exists():
            with open(STATUS_FILE, 'r') as f:
                return json.load(f)
        return {}

    def update_status(self, data):
        """Update pipeline status."""
        current = self.get_status()
        current.update(data)
        with open(STATUS_FILE, 'w') as f:
            json.dump(current, f, indent=2)

    def list_artifacts(self):
        """List all generated artifacts in the data directory."""
        data_dir = DASHBOARD_DIR.parent / "data"
        artifacts = []

        if data_dir.exists():
            for file in data_dir.iterdir():
                if file.is_file():
                    artifacts.append({
                        "name": file.name,
                        "size": file.stat().st_size,
                        "modified": file.stat().st_mtime
                    })

        return {"artifacts": artifacts}


def main():
    """Start the dashboard server."""
    os.chdir(DASHBOARD_DIR)

    with socketserver.TCPServer(("", PORT), PipelineHandler) as httpd:
        print(f"""
╔══════════════════════════════════════════════════════════════╗
║  🤖 Bot-to-NGA Agent Migration Dashboard                    ║
╚══════════════════════════════════════════════════════════════╝

Dashboard running at:

    👉 http://localhost:{PORT}

The dashboard will auto-update as pipeline steps complete.

Press Ctrl+C to stop the server.
""")

        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\n\n✓ Dashboard server stopped.")
            sys.exit(0)


if __name__ == "__main__":
    main()
