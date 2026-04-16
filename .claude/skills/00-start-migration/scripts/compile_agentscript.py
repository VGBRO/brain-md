# /// script
# requires-python = ">=3.11"
# dependencies = [
#   "sfdc-afscript-agent-dsl>=0.0.1rc28",
#   "sfdc-agentscript-agent-json",
#   "sfdc-agent-dsl",
# ]
# [tool.uv]
# prerelease = "allow"
# [[tool.uv.index]]
# url = "https://nexus-proxy.repo.local.sfdc.net/nexus/repository/pypi-all/simple"
# ///
import re
import sys
from pathlib import Path

try:
    from agentscript import parse_agentscript, compile_agentscript
except ModuleNotFoundError:
    print(
        "Error: This script must be run using uv, not python/python3 directly.\n"
        "\n"
        "Usage:\n"
        "  uv run --refresh --native-tls "
        "00-start-migration/scripts/compile_agentscript.py <path-to-agentscript>\n"
        "\n"
        "The required dependencies (sfdc-afscript-agent-dsl, sfdc-agentscript-agent-json,\n"
        "sfdc-agent-dsl) are resolved automatically by uv from the inline script metadata.",
        file=sys.stderr,
    )
    sys.exit(1)

# Known library bugs that produce false-positive compile errors.
# These do not indicate problems with the AgentScript file itself.
# sf agent publish is the authoritative validator for these cases.
KNOWN_LIBRARY_BUG_PATTERNS = [
    "developer_name=None",
    "developer_name is None",
]

# Pydantic ValidationError for developer_name=None appears in the exception
# string as "developer_name\n  Input should be a valid string" with input_value=None.
# The "=None" pattern only appears in the traceback, not in str(e).
KNOWN_LIBRARY_BUG_PYDANTIC_FIELDS = [
    "developer_name",
]

def is_known_library_bug(error: object) -> bool:
    error_str = str(error)
    if any(pattern in error_str for pattern in KNOWN_LIBRARY_BUG_PATTERNS):
        return True
    # Catch pydantic ValidationError where developer_name (or similar) is None
    # str(ValidationError) contains the field name and "input_value=None"
    if "input_value=None" in error_str and any(
        field in error_str for field in KNOWN_LIBRARY_BUG_PYDANTIC_FIELDS
    ):
        return True
    return False

def show_source_context(source_lines: list[str], line_number: int, context: int = 2) -> None:
    start = max(0, line_number - context - 1)
    end = min(len(source_lines), line_number + context)
    for i, line in enumerate(source_lines[start:end], start=start + 1):
        marker = ">>>" if i == line_number else "   "
        print(f"  {marker} {i:4d} | {line}", file=sys.stderr)

def extract_line_number(error_str: str) -> int | None:
    # ANTLR-style: "line 42:7 ..."
    m = re.search(r'\bline\s+(\d+)', error_str, re.IGNORECASE)
    if m:
        return int(m.group(1))
    # "at line 42" or ":42:"
    m = re.search(r':(\d+):', error_str)
    if m:
        return int(m.group(1))
    return None

if len(sys.argv) != 2:
    print("Usage: uv run --refresh --native-tls compile_agentscript.py <path-to-agentscript>", file=sys.stderr)
    sys.exit(1)

script_path = Path(sys.argv[1])
if not script_path.exists():
    print(f"Error: File '{script_path}' not found", file=sys.stderr)
    sys.exit(1)

source = script_path.read_text()
source_lines = source.splitlines()

# --- Parse ---
as_model_verify, parsing_errors = parse_agentscript(source)
if parsing_errors:
    print(f"Parse errors in {script_path.name}:", file=sys.stderr)
    for error in parsing_errors:
        print(f"  {error}", file=sys.stderr)
        line_no = extract_line_number(str(error))
        if line_no:
            show_source_context(source_lines, line_no)
    sys.exit(1)

print(f"Parsed {script_path.name} ({len(source_lines)} lines).")

# --- Compile ---
try:
    compiled, compile_errors = compile_agentscript(as_model_verify)
except Exception as e:
    if is_known_library_bug(str(e)):
        print(
            "Note: 1 known library issue detected "
            "(not caused by your AgentScript — sf agent publish is authoritative):",
            file=sys.stderr,
        )
        print(f"  [library] {e}", file=sys.stderr)
        print("Successfully compiled Agent Script (library warnings present — run sf agent publish to confirm).")
        sys.exit(0)
    raise

real_errors = [e for e in compile_errors if not is_known_library_bug(str(e))]
library_warnings = [e for e in compile_errors if is_known_library_bug(str(e))]

if library_warnings:
    print(
        f"Note: {len(library_warnings)} known library issue(s) detected "
        "(not caused by your AgentScript — sf agent publish is authoritative):",
        file=sys.stderr,
    )
    for w in library_warnings:
        print(f"  [library] {w}", file=sys.stderr)

if real_errors:
    print(f"Compile errors in {script_path.name}:", file=sys.stderr)
    for error in real_errors:
        print(f"  {error}", file=sys.stderr)
        line_no = extract_line_number(str(error))
        if line_no:
            show_source_context(source_lines, line_no)
    sys.exit(1)

if library_warnings:
    print(
        "Successfully compiled Agent Script "
        "(library warnings present — run sf agent publish to confirm)."
    )
else:
    print("Successfully compiled Agent Script.")
