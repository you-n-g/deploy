import {
  BorderedLoader,
  BranchSummaryMessageComponent,
  collectEntriesForBranchSummary,
  DynamicBorder,
  generateBranchSummary,
  prepareBranchEntries,
} from "@earendil-works/pi-coding-agent";
import { Key, matchesKey, truncateToWidth } from "@earendil-works/pi-tui";

const CUSTOM_TYPE = "branch-pull";

function formatContextSummary(fromIds, summary) {
  const target = fromIds.length === 1 ? `another branch (${fromIds[0]})` : `other branches (${fromIds.join(", ")})`;
  return `The following is a summary of ${target} pulled into this conversation:\n\n<summary>\n${summary}\n</summary>`;
}

function contentToSingleLine(content) {
  const raw =
    typeof content === "string"
      ? content
      : Array.isArray(content)
        ? content
            .filter((block) => block?.type === "text" && typeof block.text === "string")
            .map((block) => block.text)
            .join(" ")
        : "";
  return raw.replace(/\s+/g, " ").trim();
}

function entrySnippet(entry) {
  if (entry.type === "message" && (entry.message.role === "user" || entry.message.role === "assistant")) {
    return contentToSingleLine(entry.message.content);
  }
  if (entry.type === "custom_message") return contentToSingleLine(entry.content);
  if (entry.type === "branch_summary" || entry.type === "compaction") {
    return contentToSingleLine(entry.summary);
  }
  return "";
}

function collectMergedLeafIds(activePath) {
  const merged = new Set();
  for (const entry of activePath) {
    if (entry.type === "branch_summary" && entry.fromId) {
      merged.add(entry.fromId);
    } else if (entry.type === "custom_message" && entry.customType === CUSTOM_TYPE && entry.details) {
      if (entry.details.fromId) merged.add(entry.details.fromId);
      if (Array.isArray(entry.details.fromIds)) {
        for (const id of entry.details.fromIds) {
          if (id) merged.add(id);
        }
      }
    }
  }
  return merged;
}

export function collectSiblingBranchLeaves(sessionManager) {
  const currentLeafId = sessionManager.getLeafId();
  const activePath = currentLeafId ? sessionManager.getBranch(currentLeafId) : [];
  const activeIds = new Set(activePath.map((entry) => entry.id));
  const mergedIds = collectMergedLeafIds(activePath);

  const leaves = [];
  const visit = (nodes) => {
    for (const node of nodes) {
      if (node.children.length === 0) {
        if (!activeIds.has(node.entry.id)) leaves.push(node);
      } else {
        visit(node.children);
      }
    }
  };
  visit(sessionManager.getTree());

  const candidates = [];
  for (const node of leaves) {
    const leafId = node.entry.id;
    const { entries, commonAncestorId } =
      currentLeafId === null
        ? { entries: sessionManager.getBranch(leafId), commonAncestorId: null }
        : collectEntriesForBranchSummary(sessionManager, leafId, currentLeafId);
    if (entries.length === 0 || prepareBranchEntries(entries, 0).messages.length === 0) continue;

    let branchLabel = node.label;
    let firstUser = "";
    let firstAny = "";
    let lastSnippet = "";
    let turns = 0;

    for (const entry of entries) {
      const lbl = sessionManager.getLabel?.(entry.id);
      if (lbl) branchLabel = lbl;
      const text = entrySnippet(entry);
      if (entry.type === "message" && entry.message.role === "user") {
        turns += 1;
        if (!firstUser && text) firstUser = text;
      }
      if (!firstAny && text) firstAny = text;
      if (text) lastSnippet = text;
    }

    const head = firstUser || firstAny || `Branch ${leafId}`;
    const title = `${branchLabel ? `[${branchLabel}] ` : ""}${head.slice(0, 60)}`;
    const turnPart = turns > 0 ? `${turns} turn${turns === 1 ? "" : "s"}` : `${entries.length} entries`;
    const lastPart = lastSnippet && lastSnippet !== head ? ` · last: ${lastSnippet.slice(0, 44)}` : "";
    const merged = mergedIds.has(leafId);

    candidates.push({
      leafId,
      commonAncestorId,
      entries,
      merged,
      title,
      meta: `${turnPart}${lastPart} (#${leafId})`,
      timestamp: Date.parse(node.entry.timestamp) || 0,
    });
  }

  candidates.sort((a, b) => b.timestamp - a.timestamp);
  return candidates;
}

class SiblingBranchPicker {
  constructor(candidates, theme, onConfirm, onCancel) {
    this.candidates = candidates;
    this.theme = theme;
    this.onConfirm = onConfirm;
    this.onCancel = onCancel;
    const firstUnmerged = candidates.findIndex((c) => !c.merged);
    this.cursor = firstUnmerged >= 0 ? firstUnmerged : 0;
    this.selected = new Set();
    this.maxVisible = 10;
    this.border = new DynamicBorder((s) => this.theme.fg("accent", s));
  }

  invalidate() {}

  toggle(index) {
    const id = this.candidates[index]?.leafId;
    if (!id) return;
    if (this.selected.has(id)) this.selected.delete(id);
    else this.selected.add(id);
  }

  toggleAllUnmerged() {
    const targets = this.candidates.filter((c) => !c.merged);
    const pool = targets.length > 0 ? targets : this.candidates;
    const allSelected = pool.every((c) => this.selected.has(c.leafId));
    if (allSelected) {
      for (const c of pool) this.selected.delete(c.leafId);
    } else {
      for (const c of pool) this.selected.add(c.leafId);
    }
  }

  handleInput(data) {
    const n = this.candidates.length;
    if (matchesKey(data, Key.up) || data === "k") {
      this.cursor = (this.cursor - 1 + n) % n;
    } else if (matchesKey(data, Key.down) || data === "j") {
      this.cursor = (this.cursor + 1) % n;
    } else if (matchesKey(data, Key.space)) {
      this.toggle(this.cursor);
    } else if (matchesKey(data, Key.tab)) {
      this.toggle(this.cursor);
      this.cursor = (this.cursor + 1) % n;
    } else if (data === "a") {
      this.toggleAllUnmerged();
    } else if (matchesKey(data, Key.enter)) {
      const picked =
        this.selected.size > 0
          ? this.candidates.filter((c) => this.selected.has(c.leafId)).map((c) => c.leafId)
          : [this.candidates[this.cursor].leafId];
      this.onConfirm(picked);
    } else if (matchesKey(data, Key.escape) || matchesKey(data, Key.ctrl("c"))) {
      this.onCancel();
    }
  }

  render(width) {
    const safeWidth = Math.max(1, width);
    const lines = [];
    lines.push(...this.border.render(safeWidth));
    lines.push(
      truncateToWidth(
        " " + this.theme.fg("accent", this.theme.bold("Pull Sibling Branch Summary")),
        safeWidth,
      ),
    );

    const total = this.candidates.length;
    const visible = Math.min(total, this.maxVisible);
    let start = Math.max(0, this.cursor - Math.floor(visible / 2));
    if (start + visible > total) start = Math.max(0, total - visible);

    for (let i = start; i < start + visible; i++) {
      const c = this.candidates[i];
      const active = i === this.cursor;
      const checked = this.selected.has(c.leafId);
      const pointer = active ? this.theme.fg("accent", "❯ ") : "  ";
      const box = checked ? this.theme.fg("accent", "[x] ") : this.theme.fg("dim", "[ ] ");
      const badge = c.merged ? this.theme.fg("success", "✓ merged ") : "";
      const title = active
        ? this.theme.fg("accent", this.theme.bold(c.title))
        : c.merged
          ? this.theme.fg("muted", c.title)
          : c.title;
      const meta = this.theme.fg("dim", "  " + c.meta);
      lines.push(truncateToWidth(` ${pointer}${box}${badge}${title}${meta}`, safeWidth));
    }

    if (total > visible) {
      lines.push(
        truncateToWidth(
          " " + this.theme.fg("dim", `(${start + 1}-${start + visible} of ${total})`),
          safeWidth,
        ),
      );
    }

    const countHint = this.selected.size > 0 ? ` (${this.selected.size} selected)` : "";
    lines.push(
      truncateToWidth(
        " " +
          this.theme.fg(
            "dim",
            `↑↓/jk move • space/tab select • a all unmerged • enter merge${countHint} • esc cancel`,
          ),
        safeWidth,
      ),
    );
    lines.push(...this.border.render(safeWidth));
    return lines;
  }
}

export default function (pi) {
  pi.registerMessageRenderer(CUSTOM_TYPE, (message, { expanded }) => {
    const component = new BranchSummaryMessageComponent({
      role: "branchSummary",
      summary: message.details?.summary ?? (typeof message.content === "string" ? message.content : ""),
      fromId: message.details?.fromId ?? "",
      timestamp: message.timestamp,
    });
    component.setExpanded(expanded);
    return component;
  });

  pi.registerCommand("pull", {
    description: "Summarize one or more sibling branch leaves into the current branch",
    handler: async (args, ctx) => {
      if (!ctx.hasUI) return;
      if (ctx.mode && ctx.mode !== "tui") {
        ctx.ui.notify("/pull requires interactive TUI mode", "warning");
        return;
      }
      if (!ctx.isIdle()) {
        ctx.ui.notify("Wait for the current turn to finish before /pull", "warning");
        return;
      }
      if (!ctx.model) {
        ctx.ui.notify("No model selected", "error");
        return;
      }

      const candidates = collectSiblingBranchLeaves(ctx.sessionManager);
      if (candidates.length === 0) {
        ctx.ui.notify("No sibling branches to pull", "info");
        return;
      }

      const selectedIds = await ctx.ui.custom((tui, theme, _kb, done) => {
        const picker = new SiblingBranchPicker(
          candidates,
          theme,
          (ids) => done(ids),
          () => done(null),
        );
        return {
          render: (width) => picker.render(width),
          invalidate: () => picker.invalidate(),
          handleInput: (data) => {
            picker.handleInput(data);
            tui.requestRender();
          },
        };
      });

      if (!selectedIds || selectedIds.length === 0) return;
      const byId = new Map(candidates.map((c) => [c.leafId, c]));
      const chosen = selectedIds.map((id) => byId.get(id)).filter(Boolean);
      if (chosen.length === 0) return;

      const customInstructions = args.trim() || undefined;
      const model = ctx.model;
      const label =
        chosen.length === 1 ? "Summarizing branch..." : `Summarizing ${chosen.length} branches...`;

      const outcome = await ctx.ui.custom((tui, theme, _kb, done) => {
        const loader = new BorderedLoader(tui, theme, label);
        let finished = false;
        const finish = (value) => {
          if (finished) return;
          finished = true;
          loader.dispose();
          done(value);
        };
        loader.onAbort = () => finish({ aborted: true });
        Promise.all(
          chosen.map((branch) =>
            generateBranchSummary(branch.entries, {
              model,
              signal: loader.signal,
              customInstructions,
              streamFn: (m, context, options) => ({
                result: () => ctx.modelRegistry.complete(m, context, options),
              }),
            }),
          ),
        )
          .then((results) => finish({ results }))
          .catch((err) => finish({ error: err instanceof Error ? err.message : String(err) }));
        return loader;
      });

      if (!outcome || outcome.aborted || outcome.results?.some((r) => r.aborted)) {
        ctx.ui.notify("Branch pull cancelled", "info");
        return;
      }
      const failed = outcome.error || outcome.results?.find((r) => r.error)?.error;
      if (failed) {
        ctx.ui.notify(failed, "error");
        return;
      }

      const results = outcome.results;
      const combinedSummary =
        chosen.length === 1
          ? results[0].summary
          : chosen
              .map((branch, idx) => `### Branch: ${branch.title} (#${branch.leafId})\n\n${results[idx].summary}`)
              .join("\n\n---\n\n");
      const fromIds = chosen.map((branch) => branch.leafId);
      const readFiles = [...new Set(results.flatMap((r) => r.readFiles ?? []))];
      const modifiedFiles = [...new Set(results.flatMap((r) => r.modifiedFiles ?? []))];

      pi.sendMessage({
        customType: CUSTOM_TYPE,
        content: formatContextSummary(fromIds, combinedSummary),
        display: true,
        details: {
          fromId: fromIds[0],
          fromIds,
          commonAncestorIds: chosen.map((branch) => branch.commonAncestorId),
          summary: combinedSummary,
          readFiles,
          modifiedFiles,
        },
      });
      ctx.ui.notify(
        fromIds.length === 1
          ? `Pulled summary from branch ${fromIds[0]}`
          : `Pulled summaries from ${fromIds.length} branches (${fromIds.join(", ")})`,
        "info",
      );
    },
  });
}
