import { parseSkillBlock } from "@earendil-works/pi-coding-agent";
import { sliceByColumn, stripTerminalSequences, visibleWidth } from "@earendil-works/pi-tui";

function summarizePrompt(text, hasImages = false) {
  let summary = text ?? "";
  const skill = parseSkillBlock(summary);
  if (skill) {
    summary = `/skill:${skill.name}${skill.userMessage ? ` ${skill.userMessage}` : ""}`;
  }
  summary = stripTerminalSequences(summary).replace(/\s+/g, " ").trim();
  if (!summary) return hasImages ? "[image]" : undefined;
  return summary;
}

function summarizeUserMessage(message) {
  if (!message || message.role !== "user") return undefined;
  if (typeof message.content === "string") return summarizePrompt(message.content);
  if (!Array.isArray(message.content)) return undefined;
  const text = message.content
    .filter((part) => part?.type === "text" && typeof part.text === "string")
    .map((part) => part.text)
    .join("\n");
  const hasImages = message.content.some((part) => part?.type === "image");
  return summarizePrompt(text, hasImages);
}

function latestBranchPrompt(sessionManager) {
  const branch = sessionManager.getBranch();
  for (let i = branch.length - 1; i >= 0; i--) {
    const entry = branch[i];
    if (entry.type === "message" && entry.message?.role === "user") {
      return summarizeUserMessage(entry.message);
    }
  }
  return undefined;
}

export default function (pi) {
  let currentSummary;
  let activeCtx;

  function apply(ctx, summary) {
    currentSummary = summary;
    activeCtx = ctx;
    if (!ctx.hasUI) return;
    if (!summary) {
      ctx.ui.setWorkingMessage(undefined);
      return;
    }
    const cols = process.stdout.columns || Number(process.env.COLUMNS) || 80;
    const maxWidth = Math.max(16, cols - 5);
    const line = `Working: ${summary}`;
    ctx.ui.setWorkingMessage(visibleWidth(line) <= maxWidth ? line : `${sliceByColumn(line, 0, maxWidth - 1, true)}…`);
  }

  function onResize() {
    if (activeCtx) apply(activeCtx, currentSummary);
  }

  pi.on("session_start", (_event, ctx) => {
    if (!ctx.hasUI) return;
    process.stdout.off("resize", onResize);
    process.stdout.on("resize", onResize);
    apply(ctx, latestBranchPrompt(ctx.sessionManager));
  });

  pi.on("before_agent_start", (event, ctx) => {
    apply(ctx, summarizePrompt(event.prompt, (event.images?.length ?? 0) > 0));
  });

  pi.on("message_start", (event, ctx) => {
    if (event.message?.role === "user") {
      apply(ctx, summarizeUserMessage(event.message));
    }
  });

  pi.on("session_tree", (_event, ctx) => {
    apply(ctx, latestBranchPrompt(ctx.sessionManager));
  });

  pi.on("session_shutdown", () => {
    process.stdout.off("resize", onResize);
    activeCtx = undefined;
    currentSummary = undefined;
  });
}
