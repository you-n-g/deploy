import { execFileSync } from "node:child_process";
import { realpathSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

export const name = "dsh-tma";
export const inject = [];

function isTopLevel(session) {
  return (session?.header?.delegationDepth ?? 0) === 0;
}

function extractPromptText(content) {
  if (typeof content === "string") return content.trim();
  if (!Array.isArray(content)) return "";
  return content
    .filter((part) => part?.type === "text" && typeof part.text === "string")
    .map((part) => part.text)
    .join("\n")
    .trim();
}

export function apply(ctx) {
  const pane = process.env.TMUX_PANE;
  const profile = ctx.get?.("profileContext");
  if (!pane || profile?.name !== "dsh-tui") return;

  const directory = dirname(realpathSync(fileURLToPath(import.meta.url)));
  const trackScript = join(directory, "../../script/track_ai_agent_state.sh");

  let active = true;
  let lastState = "idle";
  let promptGraceUntil = 0;
  let settleTimer = null;
  let detachJobs = null;

  function runTracker(state, source, meta) {
    const env = { ...process.env, AI_AGENT_STATE_SOURCE: `dsh-plugin:${source}` };
    delete env.AI_AGENT_PROMPT;
    if (meta?.prompt) {
      env.AI_AGENT_PROMPT = meta.prompt;
      if (meta.sessionId) env.AI_AGENT_SESSION_ID = meta.sessionId;
      if (meta.cwd) env.AI_AGENT_CWD = meta.cwd;
    }
    try {
      execFileSync(trackScript, [state, pane], { env, stdio: "ignore" });
    } catch {
      // Pane or tmux server may have closed during teardown.
    }
  }

  function computeState() {
    const agents = [...(ctx.get?.("agents")?.list?.() ?? [])];
    const topAgents = agents.filter((agent) => isTopLevel(agent.session));
    if (topAgents.some((agent) => agent.status === "running") || Date.now() < promptGraceUntil) {
      return "running";
    }

    const subAgents = agents.filter((agent) => !isTopLevel(agent.session));
    if (subAgents.some((agent) => agent.status === "running")) {
      return "background";
    }

    const jobs = ctx.get?.("jobs");
    if (jobs?.list) {
      const owners = new Set();
      for (const agent of topAgents) {
        if (agent.id) owners.add(agent.id);
        if (agent.session?.id) owners.add(agent.session.id);
      }
      for (const owner of owners) {
        const list = jobs.list(owner) ?? [];
        if (list.some((job) => job.status === "running" || job.status === "stopping")) {
          return "background";
        }
      }
    }

    return "idle";
  }

  function clearSettleTimer() {
    if (settleTimer !== null) {
      clearTimeout(settleTimer);
      settleTimer = null;
    }
  }

  function syncState(source, meta) {
    if (!active) return;
    clearSettleTimer();
    const next = meta?.prompt ? "running" : computeState();
    if (next === lastState && !meta?.prompt) return;
    lastState = next;
    runTracker(next, source, meta);
  }

  function scheduleSync(source) {
    if (!active) return;
    const immediate = computeState();
    if (immediate === "running") {
      syncState(source);
      return;
    }
    clearSettleTimer();
    settleTimer = setTimeout(() => {
      settleTimer = null;
      syncState(source);
    }, 60);
    settleTimer.unref?.();
  }

  function bindJobs() {
    detachJobs?.();
    detachJobs = null;
    const jobs = ctx.get?.("jobs");
    const subscribe = jobs?.events?.subscribe;
    if (typeof subscribe !== "function") return;
    detachJobs = subscribe.call(jobs.events, { owners: "all" }, (event) => {
      if (event?.type === "output") return;
      scheduleSync(`jobs:${event?.type ?? "change"}`);
    });
  }

  runTracker("init", "startup");
  lastState = "idle";
  bindJobs();
  syncState("startup-sync");

  const disposers = [
    ctx.on("session/event", (session, event) => {
      if (!active || !isTopLevel(session)) return;
      if (event?.type === "user/message" && event?.data?.source?.kind === "user") {
        const prompt = extractPromptText(event.data.content);
        if (prompt) {
          promptGraceUntil = Date.now() + 1000;
          syncState("user/message", {
            prompt,
            sessionId: String(session.id ?? ""),
            cwd: session.header?.cwd ?? process.cwd(),
          });
        }
      }
    }),
    ctx.on("agent/created", () => scheduleSync("agent/created")),
    ctx.on("agent/status", ({ status }) => {
      promptGraceUntil = 0;
      if (status === "running") syncState("agent/status:running");
      else scheduleSync(`agent/status:${status}`);
    }),
    ctx.on("agent/disposed", () => scheduleSync("agent/disposed")),
    ctx.on("internal/service", (serviceName) => {
      if (serviceName === "jobs") {
        bindJobs();
        scheduleSync("service:jobs");
      }
    }),
  ];

  const onProcessExit = () => {
    runTracker("init", "exit");
  };
  process.once("exit", onProcessExit);

  ctx.effect?.(() => () => {
    active = false;
    clearSettleTimer();
    detachJobs?.();
    detachJobs = null;
    for (const dispose of disposers.splice(0)) dispose?.();
    process.removeListener("exit", onProcessExit);
  });
}

export default { name, inject, apply };
