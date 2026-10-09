# AFFiNE OpenClaw plugin

This plugin exposes five tools: list workspaces, list documents, read a document as Markdown, update Markdown, and create a Markdown document. It targets the custom REST API implemented in the AFFiNE source bundled in this repository (`/api/docs/workspaces/...`).

The plugin is built against the public OpenClaw plugin SDK for the pinned 2026.9.9 runtime. It is installed but disabled by default because the AFFiNE backend is not running in the current deployment and no agent account credentials are configured.

Configure `AFFINE_URL`, `AFFINE_AGENT_EMAIL`, and `AFFINE_AGENT_PASSWORD` through the deployment's secret/environment settings after starting the matching AFFiNE service. Then enable the `affine` plugin in OpenClaw. Do not put credentials in Git or expose them in logs.
