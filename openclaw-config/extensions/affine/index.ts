import { definePluginEntry, type AnyAgentTool } from "openclaw/plugin-sdk/plugin-entry";
import { createAffineTools } from "./src/tools.js";

export default definePluginEntry({
  id: "affine",
  name: "AFFiNE",
  description: "Read, create, and update AFFiNE documents using Markdown.",
  register(api) {
    for (const tool of createAffineTools(api)) {
      api.registerTool(tool as unknown as AnyAgentTool, { optional: true });
    }
  },
});
