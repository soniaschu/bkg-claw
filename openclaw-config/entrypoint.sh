#!/bin/sh
# Seed configuration once; the persistent config must retain plugin install metadata.
if [ ! -f /home/node/.openclaw/openclaw.json ]; then
  sed -e "s|__MODEL__|${MODEL:-z-ai/glm-5.3}|g" \
      -e "s|__PROXY_URL__|${PROXY_URL:-http://claude-code-free:8082}|g" \
      -e "s|__AFFINE_URL__|${AFFINE_URL:-http://host.docker.internal:3010}|g" \
      -e "s|__AFFINE_AGENT_EMAIL__|${AFFINE_AGENT_EMAIL:-}|g" \
      -e "s|__AFFINE_AGENT_PASSWORD__|${AFFINE_AGENT_PASSWORD:-}|g" \
      -e "s|__ALLOWED_ORIGIN__|https://${RAILWAY_PUBLIC_DOMAIN:-claw.eysho.info}|g" \
      -e "s|__TRUSTED_PROXY_RANGE__|${TRUSTED_PROXY_RANGE:-172.30.0.3}|g" \
      /openclaw-config/openclaw.json > /home/node/.openclaw/openclaw.json
fi

# Refresh proxy trust and browser origins from deployment variables without replacing other persisted settings.
node -e 'const fs=require("fs");const p="/home/node/.openclaw/openclaw.json";const c=JSON.parse(fs.readFileSync(p,"utf8"));c.gateway=c.gateway||{};c.gateway.trustedProxies=(process.env.TRUSTED_PROXY_RANGE||"172.30.0.3").split(",").map(x=>x.trim()).filter(Boolean);c.gateway.controlUi=c.gateway.controlUi||{};const o=["https://claw.eysho.info",`https://${process.env.RAILWAY_PUBLIC_DOMAIN||"claw.eysho.info"}`];c.gateway.controlUi.allowedOrigins=[...new Set(o)];fs.writeFileSync(p,JSON.stringify(c,null,2)+"\n");'

# Load SOUL.md from GitHub profile README using PAT
if [ -n "$GITHUB_PAT_TOKEN" ]; then
  SOUL_DIR=/home/node/.openclaw/workspace
  GH_USER=$(curl -sfL -H "Authorization: token ${GITHUB_PAT_TOKEN}" \
    "https://api.github.com/user" 2>/dev/null \
    | sed -n 's/.*"login" *: *"\([^"]*\)".*/\1/p')
  if [ -n "$GH_USER" ]; then
    FETCH_URL="https://raw.githubusercontent.com/${GH_USER}/${GH_USER}/main/README.md"
    mkdir -p "$SOUL_DIR"
    echo "Fetching user profile for @${GH_USER}..."
    if wget -q -O "$SOUL_DIR/USER.md" --header="Authorization: token ${GITHUB_PAT_TOKEN}" "$FETCH_URL" 2>/dev/null \
    || curl -sfL -H "Authorization: token ${GITHUB_PAT_TOKEN}" -o "$SOUL_DIR/USER.md" "$FETCH_URL" 2>/dev/null; then
      echo "USER.md loaded for @${GH_USER}"
    else
      echo "Warning: could not fetch user profile from ${FETCH_URL}"
      rm -f "$SOUL_DIR/USER.md"
    fi
  else
    echo "Warning: could not determine GitHub username from PAT"
  fi
fi

# Configure GitHub credentials if PAT is available
if [ -n "$GITHUB_PAT_TOKEN" ]; then
  # Git credential store — authenticates git clone/push/pull to github.com
  git config --global credential.helper store
  echo "https://x-access-token:${GITHUB_PAT_TOKEN}@github.com" > /home/node/.git-credentials
  chmod 600 /home/node/.git-credentials
  chown node:node /home/node/.git-credentials
  # Standard env vars — used by gh CLI, GitHub Actions tools, and many CI integrations
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

# Seed project persona/instructions only when the persistent workspace has no copy yet.
mkdir -p /home/node/.openclaw/workspace
for file in SOUL.md AGENTS.md; do
  if [ ! -f "/home/node/.openclaw/workspace/$file" ] && [ -f "/openclaw-config/workspace/$file" ]; then
    cp "/openclaw-config/workspace/$file" "/home/node/.openclaw/workspace/$file"
  fi
done

# Build the GitHub source first: the repository does not ship dist/ in Git.
# Keep the source in the persistent volume and install only its compiled artifact.
if [ ! -f /home/node/.openclaw/extensions/nvidia-speech/openclaw.plugin.json ]; then
  PLUGIN_SOURCE=/home/node/.openclaw/plugin-sources/nvidia-speech
  mkdir -p /home/node/.openclaw/plugin-sources
  if [ ! -f "$PLUGIN_SOURCE/package.json" ]; then
    rm -rf "$PLUGIN_SOURCE"
    git clone --depth 1 https://github.com/dhiraj-salian/openclaw-nvidia-speech.git "$PLUGIN_SOURCE"
  fi
  (cd "$PLUGIN_SOURCE" && npm install --include=dev --no-audit --no-fund && npm run ci) || {
    echo "ERROR: NVIDIA speech plugin build failed; refusing to claim speech is configured."
    exit 1
  }
  rm -rf "$PLUGIN_SOURCE/node_modules"
  node /app/openclaw.mjs plugins install "$PLUGIN_SOURCE" --force --accept-capabilities
fi

# Gateway runs as root in this image; root-owned plugin sources pass OpenClaw's trust checks.
chown -R root:root /home/node/.openclaw

exec "$@"
