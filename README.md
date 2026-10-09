# BKG Claw

Self-hosted OpenClaw dashboard backed by the `claude-code-free` Anthropic-compatible API proxy and NVIDIA NIM.

## Local Docker Compose

Requirements: Docker Engine with the Compose plugin, and an NVIDIA NIM API key from https://build.nvidia.com/settings/api-keys.

1. Clone this repository with its OpenClaw submodule: `git clone --recurse-submodules https://github.com/soniaschu/bkg-claw.git`.
2. Enter `bkg-claw` and copy `.env.example` to `.env`.
3. Set `NVIDIA_NIM_API_KEY` and a long random `OPENCLAW_GATEWAY_TOKEN` in `.env`. Keep `.env` private.
4. Start the stack with `docker compose up -d --build`.
5. Open `http://localhost:18789/` and authenticate with the configured gateway token.

The root `docker-compose.yml` is the maintained local/server configuration. It expects an external Docker network named `bkg_net`; for a standalone deployment, create it with `docker network create bkg_net` first, or adapt the network declaration for your own environment.

## Railway deployment

Railway does not deploy this Docker Compose stack as one service. Create two Railway services from this repository, in the same Railway project and environment.

### Service 1: claude-code-free (private model proxy)

- Set the service's **Config as Code file path** to `railway.claude-code-free.json`.
- Set `NVIDIA_NIM_API_KEY` to your NVIDIA NIM API key.
- Set `PORT` to `8082`.
- Do not enable a public domain for this service. OpenClaw reaches it over Railway's private network.

### Service 2: openclaw (public dashboard)

- Use `railway.json` as the Config as Code file.
- Set `PROXY_URL` to `http://claude-code-free.railway.internal:8082` (replace `claude-code-free` if you name the proxy service differently).
- Set `NVIDIA_API_KEY` to the same NVIDIA key used by the proxy service. This enables the NVIDIA Magpie speech plugin without putting the key in the config file.
- Set `OPENCLAW_GATEWAY_TOKEN` to a long, unique random secret.
- Set `MODEL` to the model ID used by your proxy, for example `z-ai/glm-5.3`.
- Generate a public domain in Railway. Railway provides `RAILWAY_PUBLIC_DOMAIN`; the entrypoint uses it to allow the dashboard's browser origin.
- Attach a persistent Railway volume mounted at `/home/node/.openclaw`. Without this volume, gateway settings and device-pairing state can be lost on redeploy.

The Railway config files build each service from its matching Dockerfile. OpenClaw uses the official version-pinned `ghcr.io/openclaw/openclaw:2026.9.9` runtime; the NVIDIA speech plugin is installed from GitHub on a fresh volume and configured for German Magpie TTS. The plugin's current Parakeet STT endpoint is English-only, so this setup does not pretend German transcription is supported. The proxy service should stay private; only the OpenClaw dashboard needs public ingress. Store all credentials in Railway's Variables UI, never in Git.

## Configuration and security

- `.env` is ignored by Git. Do not commit API keys, gateway tokens, wallet keys, OAuth credentials, or passwords.
- `openclaw-config/openclaw.json` is a template; runtime credentials are supplied through environment variables.
- `scripts/affine-users.json` is local-only and intentionally excluded from this repository.
- Device pairing is a separate OpenClaw security step. Approve only devices you recognize.

## Updating

Pull changes, initialize/update the OpenClaw submodule if needed (`git submodule update --init --recursive`), then rebuild with `docker compose up -d --build`.
