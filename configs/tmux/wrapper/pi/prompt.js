import { copyToClipboard, DynamicBorder, parseSkillBlock } from "@earendil-works/pi-coding-agent";
import {
  Key,
  matchesKey,
  sliceByColumn,
  stripTerminalSequences,
  truncateToWidth,
  visibleWidth,
  wrapTextWithAnsi,
} from "@earendil-works/pi-tui";

function formatPrompt(text, hasImages = false) {
  let raw = stripTerminalSequences(text ?? "");
  const skill = parseSkillBlock(raw);
  if (skill) {
    raw = `/skill:${skill.name}${skill.userMessage ? `\n\n${skill.userMessage}` : ""}`;
  }
  const full = raw.trim();
  const summary = full.replace(/\s+/g, " ");
  if (!summary) {
    return hasImages ? { summary: "[image]", full: "[image]" } : undefined;
  }
  return { summary, full };
}

function formatUserMessage(message) {
  if (!message || message.role !== "user") return undefined;
  if (typeof message.content === "string") return formatPrompt(message.content);
  if (!Array.isArray(message.content)) return undefined;
  const text = message.content
    .filter((part) => part?.type === "text" && typeof part.text === "string")
    .map((part) => part.text)
    .join("\n");
  const hasImages = message.content.some((part) => part?.type === "image");
  return formatPrompt(text, hasImages);
}

function latestBranchPrompt(sessionManager) {
  const branch = sessionManager.getBranch();
  for (let i = branch.length - 1; i >= 0; i--) {
    const entry = branch[i];
    if (entry.type === "message" && entry.message?.role === "user") {
      return formatUserMessage(entry.message);
    }
  }
  return undefined;
}

export default function (pi) {
  let currentPrompt;
  let enabled = true;
  let requestRender;

  function setPrompt(prompt) {
    currentPrompt = prompt;
    requestRender?.();
  }

  function mountWidget(ctx) {
    if (!ctx.hasUI) return;
    ctx.ui.setWidget("prompt", (tui, theme) => {
      requestRender = () => tui.requestRender();
      return {
        render(width) {
          if (!enabled || !currentPrompt || width <= 0) return [];
          const prefix = "❯ ";
          const bodyWidth = Math.max(1, width - 2);
          const body = visibleWidth(currentPrompt.summary) <= bodyWidth
            ? currentPrompt.summary
            : `${sliceByColumn(currentPrompt.summary, 0, Math.max(1, bodyWidth - 1), true)}…`;
          return [truncateToWidth(theme.fg("accent", prefix) + theme.fg("muted", body), width, "")];
        },
        invalidate() {},
      };
    });
  }

  pi.on("session_start", (_event, ctx) => {
    currentPrompt = latestBranchPrompt(ctx.sessionManager);
    mountWidget(ctx);
  });

  pi.on("before_agent_start", (event) => {
    setPrompt(formatPrompt(event.prompt, (event.images?.length ?? 0) > 0));
  });

  pi.on("message_start", (event) => {
    if (event.message?.role === "user") {
      setPrompt(formatUserMessage(event.message));
    }
  });

  pi.on("session_tree", (_event, ctx) => {
    setPrompt(latestBranchPrompt(ctx.sessionManager));
  });

  pi.on("session_shutdown", () => {
    requestRender = undefined;
    currentPrompt = undefined;
  });

  pi.registerCommand("prompt", {
    description: "View full latest user message (or `/prompt toggle` to hide/show bar)",
    handler: async (args, ctx) => {
      if (!ctx.hasUI) return;
      const sub = args.trim().toLowerCase();
      if (sub === "toggle" || sub === "on" || sub === "off") {
        enabled = sub === "on" ? true : sub === "off" ? false : !enabled;
        requestRender?.();
        return;
      }
      const prompt = currentPrompt ?? latestBranchPrompt(ctx.sessionManager);
      if (!prompt) {
        ctx.ui.notify("No previous user message in this session", "info");
        return;
      }
      await ctx.ui.custom(
        (tui, theme, _kb, done) => {
          let scroll = 0;
          const border = new DynamicBorder((s) => theme.fg("accent", s));
          return {
            render(width) {
              const innerWidth = Math.max(10, width - 2);
              const wrapped = wrapTextWithAnsi(prompt.full, innerWidth);
              const maxBody = Math.max(3, Math.floor((tui.terminal?.rows || 24) * 0.7) - 4);
              const maxScroll = Math.max(0, wrapped.length - maxBody);
              if (scroll > maxScroll) scroll = maxScroll;
              const visible = wrapped.slice(scroll, scroll + maxBody);
              const pos = maxScroll > 0
                ? theme.fg("dim", ` (${scroll + 1}-${scroll + visible.length}/${wrapped.length})`)
                : "";
              const pad = (line) => ` ${line}${" ".repeat(Math.max(0, width - 1 - visibleWidth(line)))}`;
              return [
                ...border.render(width),
                truncateToWidth(` ${theme.fg("accent", theme.bold("Latest Input"))}${pos}`, width),
                ...visible.map((line) => truncateToWidth(pad(theme.fg("text", line)), width, "")),
                truncateToWidth(` ${theme.fg("dim", "↑↓/jk scroll • c copy • esc/enter/q close")}`, width),
                ...border.render(width),
              ];
            },
            handleInput(data) {
              if (matchesKey(data, Key.escape) || matchesKey(data, Key.enter) || data === "q") {
                done(undefined);
                return;
              }
              if (data === "c") {
                copyToClipboard(prompt.full).then(() => ctx.ui.notify("Copied latest input", "info"));
                return;
              }
              if (matchesKey(data, Key.up) || data === "k") scroll = Math.max(0, scroll - 1);
              else if (matchesKey(data, Key.down) || data === "j") scroll += 1;
              else if (matchesKey(data, Key.pageUp)) scroll = Math.max(0, scroll - 10);
              else if (matchesKey(data, Key.pageDown)) scroll += 10;
              tui.requestRender();
            },
            invalidate() {
              border.invalidate();
            },
          };
        },
        {
          overlay: true,
          overlayOptions: { width: "80%", minWidth: 40, maxHeight: "80%" },
        },
      );
    },
  });
}
