#!/usr/bin/env node
import { build } from "esbuild";
import { rm } from "node:fs/promises";

await rm("index.js", { force: true });
await rm("index.js.map", { force: true });
await build({
  entryPoints: ["index.ts"],
  outfile: "index.js",
  bundle: true,
  platform: "node",
  target: "node22",
  format: "esm",
  sourcemap: true,
  treeShaking: true,
  external: ["openclaw/*"],
  logLevel: "info",
});
console.log("AFFiNE plugin build complete.");
