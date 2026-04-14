#!/usr/bin/env bash
# Quick smoke-test the xurprise MCP server from the command line.
# Requires: curl, python3 (for pretty-printing).

set -euo pipefail
BASE="${XURPRISE_MCP_URL:-https://xurprise.ai/api/mcp}"

echo "=== GET (human hint) ==="
curl -sS "$BASE"
echo

echo "=== initialize ==="
curl -sS -X POST "$BASE" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"curl","version":"1"}}}' \
  | python3 -m json.tool
echo

echo "=== tools/list ==="
curl -sS -X POST "$BASE" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":2,"method":"tools/list"}' \
  | python3 -m json.tool | head -40
echo

echo "=== search_brands(query='beauty', region='Singapore') ==="
curl -sS -X POST "$BASE" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"search_brands","arguments":{"query":"beauty","region":"Singapore"}}}' \
  | python3 -m json.tool
echo

echo "=== get_click_url(slug='shopee-sg', aff_sub='demo-session-001') ==="
curl -sS -X POST "$BASE" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"get_click_url","arguments":{"slug":"shopee-sg","aff_sub":"demo-session-001"}}}' \
  | python3 -m json.tool
