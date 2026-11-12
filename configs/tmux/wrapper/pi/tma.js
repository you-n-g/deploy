import { execFileSync } from "node:child_process";
import { realpathSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

export default function (pi) {
  const directory = dirname(realpathSync(fileURLToPath(import.meta.url)));
  const pane = process.env.TMUX_PANE;
  const enabled = (ctx) => pane && ctx.hasUI;
  function bind(ctx) {
    const manager = ctx.sessionManager;
    execFileSync("python3", [join(directory, "session.py"), "record", pane, String(process.pid)], {
      input: JSON.stringify({
        session_id: manager.getSessionId(),
        transcript_path: manager.getSessionFile() ?? "",
        leaf_id: manager.getLeafId() ?? null,
        name: manager.getSessionName() ?? "",
      }),
    });
  }
  function state(ctx, value, event, prompt) {
    if (!enabled(ctx)) return;
    bind(ctx);
    const env = { ...process.env, AI_AGENT_STATE_SOURCE: `pi-extension:${event}` };
    delete env.AI_AGENT_PROMPT;
    if (prompt !== undefined) {
      env.AI_AGENT_PROMPT = prompt;
      env.AI_AGENT_SESSION_ID = ctx.sessionManager.getSessionId();
      env.AI_AGENT_CWD = ctx.cwd;
    }
    execFileSync(join(directory, "../../script/track_ai_agent_state.sh"), [value, pane], { env });
  }
  pi.on("session_start", (event, ctx) => state(ctx, ctx.isIdle() ? "init" : "running", event.type));
  pi.on("before_agent_start", (event, ctx) => state(ctx, "running", event.type, event.prompt));
  pi.on("agent_start", (event, ctx) => state(ctx, "running", event.type));
  // agent_end can still be followed by automatic retries/compaction. Pi's
  // settled event is emitted after these and after all queued continuations.
  pi.on("agent_settled", (event, ctx) => state(ctx, ctx.isIdle() ? "idle" : "running", event.type));
  pi.on("session_before_compact", (event, ctx) => state(ctx, "running", event.type));
  for (const event of ["session_compact", "session_compact_failed"]) {
    pi.on(event, (event, ctx) => state(ctx, ctx.isIdle() && !event.willRetry ? "idle" : "running", event.type));
  }
  // message_end precedes persistence in Pi. Bind at the next message start
  // and turn boundary, when preceding entries are already in the session tree.
  for (const event of ["message_start", "turn_end", "agent_end", "session_tree", "session_info_changed", "model_select", "thinking_level_select"]) {
    pi.on(event, (_event, ctx) => { if (enabled(ctx)) bind(ctx); });
  }
  pi.on("session_shutdown", (event, ctx) => {
    if (!enabled(ctx)) return;
    state(ctx, "init", event.type);
    execFileSync("tmux", ["set-option", "-pu", "-t", pane, "@tma_pi_session"]);
  });
}
