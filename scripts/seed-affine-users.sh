#!/usr/bin/env bash
#
# Seed users into a self-hosted AFFiNE instance.
#
# Usage:
#   bash scripts/seed-affine-users.sh
#   AFFINE_URL=http://host:3010 USERS_FILE=my-users.json bash scripts/seed-affine-users.sh
#
# Requires: curl, jq

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AFFINE_URL="${AFFINE_URL:-http://localhost:3010}"
USERS_FILE="${USERS_FILE:-${SCRIPT_DIR}/affine-users.json}"
COOKIE_JAR="$(mktemp)"
trap 'rm -f "$COOKIE_JAR"' EXIT

# --- helpers ---

die() { echo "ERROR: $*" >&2; exit 1; }

check_deps() {
  command -v curl >/dev/null || die "curl is required"
  command -v jq   >/dev/null || die "jq is required"
}

# Check if the server is reachable and whether it's already initialized
# (i.e. at least one user exists).
check_initialized() {
  local resp
  resp=$(curl -s -w '\n%{http_code}' "${AFFINE_URL}/api/setup/create-admin-user" \
    -X POST -H "Content-Type: application/json" -d '{"email":"probe@test","password":"x"}' 2>/dev/null) || true

  local body http_code
  http_code=$(echo "$resp" | tail -1)
  body=$(echo "$resp" | sed '$d')

  # If we get a 403 with "First user already created", server is initialized.
  # If we get a 400 (invalid email), server is NOT initialized (the endpoint is active).
  # If we can't connect, bail out.
  if [ -z "$http_code" ] || [ "$http_code" = "000" ]; then
    die "Cannot reach AFFiNE at ${AFFINE_URL}"
  fi

  if echo "$body" | jq -e '.message' 2>/dev/null | grep -qi "first user already created"; then
    return 0  # initialized
  fi

  return 1  # not initialized
}

create_admin() {
  local name="$1" email="$2" password="$3"
  local payload
  payload=$(jq -n --arg n "$name" --arg e "$email" --arg p "$password" \
    '{name: $n, email: $e, password: $p}')

  echo "Creating admin user: ${email} ..."
  local http_code
  http_code=$(curl -s -o /dev/null -w '%{http_code}' \
    -X POST "${AFFINE_URL}/api/setup/create-admin-user" \
    -H "Content-Type: application/json" \
    -c "$COOKIE_JAR" \
    -d "$payload")

  if [ "$http_code" = "200" ] || [ "$http_code" = "201" ]; then
    echo "  -> Admin created successfully."
    return 0
  else
    die "Failed to create admin (HTTP ${http_code}). Is the server already initialized?"
  fi
}

sign_in() {
  local email="$1" password="$2"
  echo "Signing in as ${email} ..."
  local resp http_code body
  resp=$(curl -s -w '\n%{http_code}' \
    -X POST "${AFFINE_URL}/api/auth/sign-in" \
    -H "Content-Type: application/json" \
    -c "$COOKIE_JAR" \
    -d "$(jq -n --arg e "$email" --arg p "$password" '{email: $e, password: $p}')")

  http_code=$(echo "$resp" | tail -1)
  body=$(echo "$resp" | sed '$d')

  if [ "$http_code" = "200" ] || [ "$http_code" = "201" ]; then
    echo "  -> Signed in."
    return 0
  else
    echo "  -> Sign-in response: ${body}" >&2
    die "Failed to sign in as ${email} (HTTP ${http_code})"
  fi
}

create_user_graphql() {
  local name="$1" email="$2" password="$3"
  local query
  query=$(jq -n --arg e "$email" --arg n "$name" --arg p "$password" '{
    query: "mutation CreateUser($input: CreateUserInput!) { createUser(input: $input) { id email name } }",
    variables: { input: { email: $e, name: $n, password: $p } }
  }')

  local resp http_code body
  resp=$(curl -s -w '\n%{http_code}' \
    -X POST "${AFFINE_URL}/graphql" \
    -H "Content-Type: application/json" \
    -b "$COOKIE_JAR" \
    -d "$query")

  http_code=$(echo "$resp" | tail -1)
  body=$(echo "$resp" | sed '$d')

  # Check for GraphQL errors (duplicate email, etc.)
  local errors
  errors=$(echo "$body" | jq -r '.errors[0].message // empty' 2>/dev/null)

  if [ -n "$errors" ]; then
    echo "  -> Skipped (${errors})"
    return 0
  fi

  local created_email
  created_email=$(echo "$body" | jq -r '.data.createUser.email // empty' 2>/dev/null)
  if [ -n "$created_email" ]; then
    echo "  -> Created: ${created_email}"
  else
    echo "  -> Unexpected response: ${body}"
  fi
}

# --- main ---

check_deps

if [ ! -f "$USERS_FILE" ]; then
  die "Users file not found: ${USERS_FILE}"
fi

user_count=$(jq 'length' "$USERS_FILE")
if [ "$user_count" -eq 0 ]; then
  die "No users defined in ${USERS_FILE}"
fi

# Find the admin entry
admin_index=$(jq 'to_entries | map(select(.value.admin == true)) | .[0].key // empty' "$USERS_FILE")
if [ -z "$admin_index" ]; then
  die "No admin user found in ${USERS_FILE} (set \"admin\": true on one entry)"
fi

admin_name=$(jq -r ".[$admin_index].name // \"\"" "$USERS_FILE")
admin_email=$(jq -r ".[$admin_index].email" "$USERS_FILE")
admin_password=$(jq -r ".[$admin_index].password" "$USERS_FILE")

if [ -z "$admin_email" ] || [ -z "$admin_password" ]; then
  die "Admin entry must have email and password"
fi

echo "AFFiNE URL: ${AFFINE_URL}"
echo "Users file: ${USERS_FILE}"
echo "Users to process: ${user_count}"
echo ""

# Step 1: Check initialization and create admin or sign in
if check_initialized; then
  echo "Server already initialized. Signing in as admin..."
  sign_in "$admin_email" "$admin_password"
else
  echo "Server not initialized. Creating admin user..."
  create_admin "$admin_name" "$admin_email" "$admin_password"
fi

echo ""

# Step 2: Create remaining users via GraphQL
created=0
skipped=0
for i in $(seq 0 $((user_count - 1))); do
  # Skip the admin entry
  if [ "$i" -eq "$admin_index" ]; then
    continue
  fi

  name=$(jq -r ".[$i].name // \"\"" "$USERS_FILE")
  email=$(jq -r ".[$i].email" "$USERS_FILE")
  password=$(jq -r ".[$i].password // \"\"" "$USERS_FILE")

  echo "Creating user: ${email} ..."
  create_user_graphql "$name" "$email" "$password"
  created=$((created + 1))
done

echo ""
echo "Done. Admin: ${admin_email}, additional users processed: ${created}"
