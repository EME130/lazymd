#!/bin/bash
# PostToolUse hook: auto-format .zig files after Edit/Write
# Reads tool_input from stdin JSON to get the file path

set -euo pipefail

# Read JSON from stdin
input=$(cat)

# Extract file_path from tool_input using python3 (available on macOS)
filepath=$(echo "$input" | python3 -c "
import sys, json
data = json.load(sys.stdin)
print(data.get('tool_input', {}).get('file_path', ''))
" 2>/dev/null || true)

# Skip if no file path or not a .zig file
if [ -z "$filepath" ] || [[ "$filepath" != *.zig ]]; then
    exit 0
fi

# Skip if file doesn't exist
if [ ! -f "$filepath" ]; then
    exit 0
fi

# Run zig fmt
zig fmt "$filepath" 2>/dev/null || true

exit 0
