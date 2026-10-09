#!/usr/bin/env node
// ComfyUI Cloud — LTX-2 Text-to-Video generator
// Usage: node generate-video.js "your prompt here" [--output video.mp4] [--seed 42]

const BASE_URL = "https://cloud.comfy.org";
const API_KEY = process.env.COMFY_UI_API_KEY;

function buildWorkflow(prompt, { seed = Math.floor(Math.random() * 2 ** 32), frames = 121, fps = 24 } = {}) {
  return {
    "75": {
      inputs: { filename_prefix: "video/LTX-2", format: "mp4", codec: "auto", video: ["92:97", 0] },
      class_type: "SaveVideo"
    },
    "92:9": {
      inputs: { steps: 20, max_shift: 2.05, base_shift: 0.95, stretch: true, terminal: 0.1, latent: ["92:56", 0] },
      class_type: "LTXVScheduler"
    },
    "92:60": {
      inputs: { text_encoder: "gemma_3_12B_it_fp4_mixed.safetensors", ckpt_name: "ltx-2-19b-dev-fp4.safetensors", device: "default" },
      class_type: "LTXAVTextEncoderLoader"
    },
    "92:73": {
      inputs: { sigmas: "0.909375, 0.725, 0.421875, 0.0" },
      class_type: "ManualSigmas"
    },
    "92:76": {
      inputs: { model_name: "ltx-2-spatial-upscaler-x2-1.0.safetensors" },
      class_type: "LatentUpscaleModelLoader"
    },
    "92:81": {
      inputs: { positive: ["92:22", 0], negative: ["92:22", 1], latent: ["92:80", 0] },
      class_type: "LTXVCropGuides"
    },
    "92:82": {
      inputs: { cfg: 1, model: ["92:68", 0], positive: ["92:81", 0], negative: ["92:81", 1] },
      class_type: "CFGGuider"
    },
    "92:90": {
      inputs: { upscale_method: "lanczos", scale_by: 0.5, image: ["92:89", 0] },
      class_type: "ImageScaleBy"
    },
    "92:91": {
      inputs: { image: ["92:90", 0] },
      class_type: "GetImageSize"
    },
    "92:51": {
      inputs: { frames_number: ["92:62", 0], frame_rate: ["92:99", 0], batch_size: 1, audio_vae: ["92:48", 0] },
      class_type: "LTXVEmptyLatentAudio"
    },
    "92:22": {
      inputs: { frame_rate: ["92:102", 0], positive: ["92:3", 0], negative: ["92:4", 0] },
      class_type: "LTXVConditioning"
    },
    "92:43": {
      inputs: { width: ["92:91", 0], height: ["92:91", 1], length: ["92:62", 0], batch_size: 1 },
      class_type: "EmptyLTXVLatentVideo"
    },
    "92:56": {
      inputs: { video_latent: ["92:43", 0], audio_latent: ["92:51", 0] },
      class_type: "LTXVConcatAVLatent"
    },
    "92:4": {
      inputs: { text: "blurry, low quality, still frame, frames, watermark, overlay, titles, has blurbox, has subtitles", clip: ["92:60", 0] },
      class_type: "CLIPTextEncode"
    },
    "92:89": {
      inputs: { width: 512, height: 512, batch_size: 1, color: 0 },
      class_type: "EmptyImage"
    },
    "92:62": {
      inputs: { value: frames },
      class_type: "PrimitiveInt"
    },
    "92:41": {
      inputs: { noise: ["92:11", 0], guider: ["92:47", 0], sampler: ["92:8", 0], sigmas: ["92:9", 0], latent_image: ["92:56", 0] },
      class_type: "SamplerCustomAdvanced"
    },
    "92:67": {
      inputs: { noise_seed: seed + 1 },
      class_type: "RandomNoise"
    },
    "92:11": {
      inputs: { noise_seed: seed },
      class_type: "RandomNoise"
    },
    "92:80": {
      inputs: { av_latent: ["92:41", 0] },
      class_type: "LTXVSeparateAVLatent"
    },
    "92:83": {
      inputs: { video_latent: ["92:84", 0], audio_latent: ["92:80", 1] },
      class_type: "LTXVConcatAVLatent"
    },
    "92:84": {
      inputs: { samples: ["92:81", 2], upscale_model: ["92:76", 0], vae: ["92:1", 2] },
      class_type: "LTXVLatentUpsampler"
    },
    "92:70": {
      inputs: { noise: ["92:67", 0], guider: ["92:82", 0], sampler: ["92:66", 0], sigmas: ["92:73", 0], latent_image: ["92:83", 0] },
      class_type: "SamplerCustomAdvanced"
    },
    "92:3": {
      inputs: { text: prompt, clip: ["92:60", 0] },
      class_type: "CLIPTextEncode"
    },
    "92:97": {
      inputs: { fps: ["92:102", 0], images: ["92:98", 0], audio: ["92:96", 0] },
      class_type: "CreateVideo"
    },
    "92:48": {
      inputs: { ckpt_name: "ltx-2-19b-dev-fp4.safetensors" },
      class_type: "LTXVAudioVAELoader"
    },
    "92:94": {
      inputs: { av_latent: ["92:70", 1] },
      class_type: "LTXVSeparateAVLatent"
    },
    "92:98": {
      inputs: { tile_size: 512, overlap: 64, temporal_size: 4096, temporal_overlap: 8, samples: ["92:94", 0], vae: ["92:1", 2] },
      class_type: "VAEDecodeTiled"
    },
    "92:96": {
      inputs: { samples: ["92:94", 1], audio_vae: ["92:48", 0] },
      class_type: "LTXVAudioVAEDecode"
    },
    "92:47": {
      inputs: { cfg: 4, model: ["92:1", 0], positive: ["92:22", 0], negative: ["92:22", 1] },
      class_type: "CFGGuider"
    },
    "92:102": {
      inputs: { value: fps },
      class_type: "PrimitiveFloat"
    },
    "92:99": {
      inputs: { value: fps },
      class_type: "PrimitiveInt"
    },
    "92:68": {
      inputs: { lora_name: "ltx-2-19b-distilled-lora-384.safetensors", strength_model: 1, model: ["92:1", 0] },
      class_type: "LoraLoaderModelOnly"
    },
    "92:8": {
      inputs: { sampler_name: "euler_ancestral" },
      class_type: "KSamplerSelect"
    },
    "92:66": {
      inputs: { sampler_name: "euler_ancestral" },
      class_type: "KSamplerSelect"
    },
    "92:1": {
      inputs: { ckpt_name: "ltx-2-19b-dev-fp4.safetensors" },
      class_type: "CheckpointLoaderSimple"
    }
  };
}

async function request(method, path, body) {
  const opts = {
    method,
    headers: { "X-API-Key": API_KEY, "Content-Type": "application/json" },
  };
  if (body) opts.body = JSON.stringify(body);
  const res = await fetch(`${BASE_URL}${path}`, opts);
  if (!res.ok) throw new Error(`${res.status} ${res.statusText}: ${await res.text()}`);
  return res;
}

async function submitPrompt(workflow) {
  const res = await request("POST", "/api/prompt", {
    prompt: workflow,
    extra_data: { api_key_comfy_org: API_KEY },
  });
  const data = await res.json();
  if (data.node_errors && Object.keys(data.node_errors).length > 0) {
    throw new Error("Node errors: " + JSON.stringify(data.node_errors));
  }
  return data.prompt_id;
}

async function pollStatus(promptId, intervalMs = 5000, maxWaitMs = 600000) {
  const start = Date.now();
  while (Date.now() - start < maxWaitMs) {
    const res = await request("GET", `/api/job/${promptId}/status`);
    const data = await res.json();
    process.stderr.write(`[${data.status}] ${((Date.now() - start) / 1000).toFixed(0)}s\n`);
    if (data.status === "success") return data;
    if (data.status === "error" || data.status === "failed") {
      throw new Error(`Job ${data.status}: ${data.error_message || "unknown"}`);
    }
    await new Promise((r) => setTimeout(r, intervalMs));
  }
  throw new Error("Timed out waiting for job");
}

async function getOutputFilename(promptId) {
  const res = await request("GET", `/api/history_v2/${promptId}`);
  const data = await res.json();
  const job = data[promptId];
  for (const nodeOut of Object.values(job.outputs)) {
    for (const img of nodeOut.images || []) {
      if (img.filename) return img.filename;
    }
  }
  throw new Error("No output file found");
}

async function downloadVideo(filename, outputPath) {
  const res = await fetch(
    `${BASE_URL}/api/view?filename=${encodeURIComponent(filename)}&type=output`,
    { headers: { "X-API-Key": API_KEY }, redirect: "follow" }
  );
  if (!res.ok) throw new Error(`Download failed: ${res.status}`);
  const fs = require("fs");
  const buffer = Buffer.from(await res.arrayBuffer());
  fs.writeFileSync(outputPath, buffer);
  return buffer.length;
}

function parseArgs(argv) {
  const args = { prompt: "", output: "output.mp4", seed: Math.floor(Math.random() * 2 ** 32), frames: 121, fps: 24 };
  const positional = [];
  for (let i = 2; i < argv.length; i++) {
    if (argv[i] === "--output" || argv[i] === "-o") args.output = argv[++i];
    else if (argv[i] === "--seed") args.seed = parseInt(argv[++i], 10);
    else if (argv[i] === "--frames") args.frames = parseInt(argv[++i], 10);
    else if (argv[i] === "--fps") args.fps = parseInt(argv[++i], 10);
    else positional.push(argv[i]);
  }
  args.prompt = positional.join(" ");
  return args;
}

async function main() {
  if (!API_KEY) {
    console.error("Error: set COMFY_UI_API_KEY environment variable");
    process.exit(1);
  }

  const args = parseArgs(process.argv);
  if (!args.prompt) {
    console.error("Usage: node generate-video.js \"prompt\" [--output file.mp4] [--seed N] [--frames N] [--fps N]");
    process.exit(1);
  }

  console.error(`Prompt:  ${args.prompt}`);
  console.error(`Seed:    ${args.seed}`);
  console.error(`Frames:  ${args.frames} (${(args.frames / args.fps).toFixed(1)}s @ ${args.fps}fps)`);
  console.error(`Output:  ${args.output}`);

  const workflow = buildWorkflow(args.prompt, { seed: args.seed, frames: args.frames, fps: args.fps });
  const promptId = await submitPrompt(workflow);
  console.error(`Job submitted: ${promptId}`);

  await pollStatus(promptId);

  const filename = await getOutputFilename(promptId);
  console.error(`Downloading: ${filename}`);
  const bytes = await downloadVideo(filename, args.output);
  console.error(`Saved ${(bytes / 1024 / 1024).toFixed(1)} MB to ${args.output}`);

  // Print JSON result to stdout for programmatic use
  console.log(JSON.stringify({ prompt_id: promptId, filename, output: args.output, bytes }));
}

main().catch((err) => {
  console.error("Error:", err.message);
  process.exit(1);
});
