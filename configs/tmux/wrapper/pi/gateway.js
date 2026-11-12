import { readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { googleGenerativeAIApi } from "@earendil-works/pi-ai";

export default function (pi) {
  const cfg = JSON.parse(readFileSync(join(homedir(), ".config/llm/gateways.local.json"), "utf8")).pi;
  const adaptedModels = [cfg.model, ...(cfg.aliases ?? [])];
  const google = googleGenerativeAIApi();
  pi.registerProvider(cfg.provider, {
    api: "google-generative-ai",
    streamSimple(model, context, options = {}) {
      if (!adaptedModels.includes(model.id)) return google.streamSimple(model, context, options);
      // Pi 0.84 identifies Gemini 3 by name; custom gateway model IDs otherwise
      // receive a thinkingBudget, which the gateway rejects. Adapt at provider
      // level so compaction and branch summaries get the same fix as chat.
      const level = { off: "LOW", minimal: "LOW", low: "LOW", medium: "MEDIUM", high: "HIGH", xhigh: "HIGH", max: "HIGH" };
      return google.streamSimple(model, context, {
        ...options,
        async onPayload(payload, requestModel) {
          const thinking = payload.config.thinkingConfig;
          delete thinking.thinkingBudget;
          thinking.thinkingLevel = level[options.reasoning ?? "off"];
          const next = await options.onPayload?.(payload, requestModel);
          return next === undefined ? payload : next;
        },
      });
    },
  });
}
