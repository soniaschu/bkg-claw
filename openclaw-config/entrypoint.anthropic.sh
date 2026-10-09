#!/bin/sh
# Copy Anthropic config into the named volume, replacing __MODEL__ placeholder
sed -e "s|__MODEL__|${MODEL:-claude-sonnet-4-5-20250929}|g" \
    /openclaw-config/openclaw.anthropic.json \
  > /home/node/.openclaw/openclaw.json 2>/dev/null || true

# Load SOUL.md from GitHub profile README using PAT
if [ -n "$GITHUB_PAT_TOKEN" ]; then
  SOUL_DIR=/home/node/.openclaw/workspace
  GH_USER=$(curl -sfL -H "Authorization: token ${GITHUB_PAT_TOKEN}" \
    "https://api.github.com/user" 2>/dev/null \
    | sed -n 's/.*"login" *: *"\([^"]*\)".*/\1/p')
  if [ -n "$GH_USER" ]; then
    FETCH_URL="https://raw.githubusercontent.com/${GH_USER}/${GH_USER}/main/README.md"
    mkdir -p "$SOUL_DIR"
    echo "Fetching SOUL.md for @${GH_USER}..."
    if wget -q -O "$SOUL_DIR/SOUL.md" --header="Authorization: token ${GITHUB_PAT_TOKEN}" "$FETCH_URL" 2>/dev/null \
    || curl -sfL -H "Authorization: token ${GITHUB_PAT_TOKEN}" -o "$SOUL_DIR/SOUL.md" "$FETCH_URL" 2>/dev/null; then
      echo "SOUL.md loaded for @${GH_USER}"
    else
      echo "Warning: could not fetch SOUL.md from ${FETCH_URL}"
      rm -f "$SOUL_DIR/SOUL.md"
    fi
  else
    echo "Warning: could not determine GitHub username from PAT"
  fi
fi

# Configure GitHub credentials if PAT is available
if [ -n "$GITHUB_PAT_TOKEN" ]; then
  git config --global credential.helper store
  echo "https://x-access-token:${GITHUB_PAT_TOKEN}@github.com" > /home/node/.git-credentials
  chmod 600 /home/node/.git-credentials
  chown node:node /home/node/.git-credentials
  export GH_TOKEN="$GITHUB_PAT_TOKEN"
  export GITHUB_TOKEN="$GITHUB_PAT_TOKEN"
  echo "GitHub credentials configured (git + gh CLI)"
fi

# Configure Twitter/X credentials and fetch scripts if available
if [ -n "$TWITTER_BEARER_TOKEN" ]; then
  export TWITTER_BEARER_TOKEN
  export TWITTER_CLIENT_ID
  export TWITTER_CLIENT_SECRET
  export TWITTER_REFRESH_TOKEN

  TWITTER_DIR=/home/node/twitter
  TWITTER_BASE_URL="https://raw.githubusercontent.com/polats/free-the-claw/main/openclaw-config/twitter"
  mkdir -p "$TWITTER_DIR"
  for script in tweet.js delete-tweet.js mentions.js refresh-token.js; do
    wget -q -O "$TWITTER_DIR/$script" "$TWITTER_BASE_URL/$script" 2>/dev/null \
    || curl -sfL -o "$TWITTER_DIR/$script" "$TWITTER_BASE_URL/$script" 2>/dev/null
  done
  chown -R node:node "$TWITTER_DIR"
  echo "Twitter/X configured — scripts at $TWITTER_DIR/"
fi

# Fetch ComfyUI video generation scripts
if [ -n "$COMFY_UI_API_KEY" ]; then
  export COMFY_UI_API_KEY

  COMFYUI_DIR=/home/node/comfyui
  COMFYUI_BASE_URL="https://raw.githubusercontent.com/polats/free-the-claw/main/openclaw-config/comfyui"
  mkdir -p "$COMFYUI_DIR"
  for script in generate-video.js make-music-video.js; do
    wget -q -O "$COMFYUI_DIR/$script" "$COMFYUI_BASE_URL/$script" 2>/dev/null \
    || curl -sfL -o "$COMFYUI_DIR/$script" "$COMFYUI_BASE_URL/$script" 2>/dev/null
  done
  chown -R node:node "$COMFYUI_DIR"
  echo "ComfyUI configured — scripts at $COMFYUI_DIR/"
fi

chown -R node:node /home/node/.openclaw

exec "$@"
