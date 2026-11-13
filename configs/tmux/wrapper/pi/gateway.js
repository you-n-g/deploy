import { readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { googleGenerativeAIApi } from "@earendil-works/pi-ai";

export default function (pi) {
  const cfg = JSON.parse(readFileSync(join(homedir(), ".config/llm/gateways.local.json"), "utf8")).pi;
  const adaptedModels = new Set([cfg.model, ...(cfg.aliases ?? [])]);
  const google = googleGenerativeAIApi();
  pi.registerProvider(cfg.provider, {
    api: "google-generative-ai",
    streamSimple(model, context, options = {}) {
      if (!adaptedModels.has(model.id)) return google.streamSimple(model, context, options);
      // Gateway aliases pointing at the same underlying model share thought
      // signatures; normalize assistant message model IDs in the request copy.
      const requestContext = {
        ...context,
        messages: context.messages.map((message) =>
          message.role === "assistant" && message.provider === model.provider &&
          message.api === model.api && adaptedModels.has(message.model)
            ? { ...message, model: model.id }
            : message),
      };
      // Pi 0.84 identifies Gemini 3 by name; custom gateway model IDs otherwise
      // receive a thinkingBudget, which the gateway rejects. Adapt at provider
      // level so compaction and branch summaries get the same fix as chat.
      const level = { off: "LOW", minimal: "LOW", low: "LOW", medium: "MEDIUM", high: "HIGH", xhigh: "HIGH", max: "HIGH" };
      return google.streamSimple(model, requestContext, {
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
