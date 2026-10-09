#!/usr/bin/env bash
#
# Test the AFFiNE REST docs API (/api/docs/*).
#
# Usage:
#   bash scripts/test-affine-docs-api.sh
#   AFFINE_URL=http://host:3010 EMAIL=admin@affine.local PASSWORD=AffineAdmin123 bash scripts/test-affine-docs-api.sh
#
# Requires: curl, jq

set -euo pipefail

AFFINE_URL="${AFFINE_URL:-http://localhost:3010}"
EMAIL="${EMAIL:-admin@affine.local}"
PASSWORD="${PASSWORD:-AffineAdmin123}"
COOKIE_JAR="$(mktemp)"
trap 'rm -f "$COOKIE_JAR"' EXIT

PASS=0
FAIL=0

# --- helpers ---

die() { echo "FATAL: $*" >&2; exit 1; }

ok()   { PASS=$((PASS + 1)); echo "  PASS: $*"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $*" >&2; }

# Pretty-print a section header
section() { echo ""; echo "=== $* ==="; }

# Make an authenticated request, print status + body, store body in $BODY
api() {
  local method="$1" path="$2"
  shift 2
  local resp http_code body

  resp=$(curl -s -w '\n%{http_code}' \
    -X "$method" \
    -b "$COOKIE_JAR" \
    -H "Content-Type: application/json" \
    "${AFFINE_URL}${path}" \
    "$@")

  http_code=$(echo "$resp" | tail -1)
  body=$(echo "$resp" | sed '$d')

  echo "  ${method} ${path} -> ${http_code}"
  BODY="$body"
  HTTP_CODE="$http_code"
}

# --- sign in ---

section "Sign In"
echo "  Authenticating as ${EMAIL} ..."

resp=$(curl -s -w '\n%{http_code}' \
  -X POST "${AFFINE_URL}/api/auth/sign-in" \
  -H "Content-Type: application/json" \
  -c "$COOKIE_JAR" \
  -d "$(jq -n --arg e "$EMAIL" --arg p "$PASSWORD" '{email: $e, password: $p}')")

http_code=$(echo "$resp" | tail -1)
if [ "$http_code" = "200" ] || [ "$http_code" = "201" ]; then
  ok "Signed in (HTTP ${http_code})"
else
  die "Sign-in failed (HTTP ${http_code}). Is the server running? Are credentials correct?"
fi

# --- list workspaces ---

section "List Workspaces"
api GET /api/docs/workspaces

if [ "$HTTP_CODE" = "200" ]; then
  ws_count=$(echo "$BODY" | jq 'length')
  ok "Got ${ws_count} workspace(s)"
  echo "$BODY" | jq '.'
else
  fail "Expected 200, got ${HTTP_CODE}"
  echo "$BODY"
fi

# Grab first workspace ID for subsequent tests
WS_ID=$(echo "$BODY" | jq -r '.[0].id // empty')
if [ -z "$WS_ID" ]; then
  echo ""
  echo "No workspaces found — skipping doc tests."
  echo "(Create a workspace in AFFiNE first, then re-run.)"
  echo ""
  echo "Results: ${PASS} passed, ${FAIL} failed"
  exit 0
fi
echo "  Using workspace: ${WS_ID}"

# --- list docs ---

section "List Docs"
api GET "/api/docs/workspaces/${WS_ID}/docs"

if [ "$HTTP_CODE" = "200" ]; then
  doc_count=$(echo "$BODY" | jq 'length')
  ok "Got ${doc_count} doc(s)"
  echo "$BODY" | jq '[.[] | {id, title, summary}]'
else
  fail "Expected 200, got ${HTTP_CODE}"
  echo "$BODY"
fi

# --- create doc ---

section "Create Doc"
api POST "/api/docs/workspaces/${WS_ID}/docs" \
  -d '{"title":"API Test Doc","markdown":"# Hello from the API\n\nThis doc was created by the test script."}'

if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "201" ]; then
  NEW_DOC_ID=$(echo "$BODY" | jq -r '.docId // empty')
  if [ -n "$NEW_DOC_ID" ]; then
    ok "Created doc: ${NEW_DOC_ID}"
  else
    fail "Response missing docId"
    echo "$BODY"
  fi
else
  fail "Expected 200/201, got ${HTTP_CODE}"
  echo "$BODY"
  NEW_DOC_ID=""
fi

# --- read doc markdown ---

if [ -n "${NEW_DOC_ID:-}" ]; then
  section "Read Doc Markdown"
  api GET "/api/docs/workspaces/${WS_ID}/docs/${NEW_DOC_ID}/markdown"

  if [ "$HTTP_CODE" = "200" ]; then
    title=$(echo "$BODY" | jq -r '.title // empty')
    md_len=$(echo "$BODY" | jq -r '.markdown // ""' | wc -c)
    ok "Read doc — title=\"${title}\", markdown=${md_len} bytes"
    echo "$BODY" | jq '.'
  else
    fail "Expected 200, got ${HTTP_CODE}"
    echo "$BODY"
  fi

  # --- update doc ---

  section "Update Doc"
  api PUT "/api/docs/workspaces/${WS_ID}/docs/${NEW_DOC_ID}/markdown" \
    -d '{"markdown":"# Updated Title\n\nThis content was updated by the test script.\n\n- item 1\n- item 2"}'

  if [ "$HTTP_CODE" = "200" ]; then
    success=$(echo "$BODY" | jq -r '.success // empty')
    if [ "$success" = "true" ]; then
      ok "Updated doc successfully"
    else
      fail "Response success != true"
      echo "$BODY"
    fi
  else
    fail "Expected 200, got ${HTTP_CODE}"
    echo "$BODY"
  fi

  # --- read back updated doc ---

  section "Read Updated Doc"
  api GET "/api/docs/workspaces/${WS_ID}/docs/${NEW_DOC_ID}/markdown"

  if [ "$HTTP_CODE" = "200" ]; then
    ok "Read updated doc"
    echo "$BODY" | jq '.'
  else
    fail "Expected 200, got ${HTTP_CODE}"
    echo "$BODY"
  fi
fi

# --- read non-existent doc (expect 404) ---

section "Read Non-Existent Doc (expect 404)"
api GET "/api/docs/workspaces/${WS_ID}/docs/does-not-exist-xyz/markdown"

if [ "$HTTP_CODE" = "404" ]; then
  ok "Got expected 404"
else
  fail "Expected 404, got ${HTTP_CODE}"
  echo "$BODY"
fi

# --- summary ---

echo ""
echo "================================"
echo "Results: ${PASS} passed, ${FAIL} failed"
echo "================================"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
