# tmux state trackers

State trackers are small long-running scripts that infer AI pane state from a
source outside normal hooks, then repair tmux pane attributes when the inferred
state and recorded state diverge.

## Interface

Every tracker should use this command shape:

```bash
tracker-name.sh PANE
```

- `PANE` is a tmux pane target. Prefer a stable pane id such as `%123`, but
  normal tmux targets like `session:window.pane` are accepted.
- The tracker resolves `PANE` to `#{pane_id}` at startup and uses that pane id
  for the rest of the run.
- The tracker runs until the pane no longer exists or the parent process kills
  it.
- The tracker should not write to the pane. It should only update tmux state
  through `../script/track_ai_agent_state.sh`.

## State Contract

Trackers should call:

```bash
../script/track_ai_agent_state.sh STATE PANE_ID
```

Only call it when the current pane attributes do not already match the inferred
state. This keeps status refreshes and auto-switch events quiet.

Common states:

- `running`: the TUI is actively working on a foreground turn.
- `idle`: the TUI has stopped, completed, or blocked.
- `pending`: the TUI is intentionally waiting and should not be auto-selected.

## Existing Trackers

- `tui-output.sh`: captures recent TUI output only to supplement transitions
  normal Codex/Claude hooks cannot see. It repairs goal-mode `running` state
  when goal text and foreground-working text appear together. It also marks a
  stuck foreground `running` pane idle after 10 seconds without tmux window
  activity, which covers interrupt paths such as ESC where the Stop hook does
  not fire. It never converts `background` to `idle`. TUI-observed idle edges
  use `AI_AGENT_STATE_SOURCE=tui-output:busy-to-idle` or
  `AI_AGENT_STATE_SOURCE=tui-output:stale-running-idle`; orchestrator
  notification code uses those sources to distinguish TUI-observed idle from
  normal Stop-hook idle.
