import {
  BorderedLoader,
  BranchSummaryMessageComponent,
  collectEntriesForBranchSummary,
  copyToClipboard,
  generateBranchSummary,
  TreeSelectorComponent,
} from "@earendil-works/pi-coding-agent";

const CUSTOM_TYPE = "branch-pull";

function formatContextSummary(fromId, summary) {
  return (
    `The following is a summary of another branch (${fromId}) pulled into this conversation:\n\n<summary>\n` +
    summary +
    `\n</summary>`
  );
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
    description: "Summarize another branch from /tree into the current branch without leaving here",
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

      const tree = ctx.sessionManager.getTree();
      if (tree.length === 0) {
        ctx.ui.notify("No entries in session", "warning");
        return;
      }

      const currentLeafId = ctx.sessionManager.getLeafId();
      const argInstructions = args.trim() || undefined;
      let initialSelectedId;
      let selectedId;
      let entries;
      let commonAncestorId;
      let customInstructions = argInstructions;

      while (true) {
        selectedId = await ctx.ui.custom((tui, _theme, _kb, done) => {
          const selector = new TreeSelectorComponent(
            tree,
            currentLeafId,
            tui.terminal.rows,
            (entryId) => done(entryId),
            () => done(null),
            (entryId, label) => {
              pi.setLabel(entryId, label);
              tui.requestRender();
            },
            initialSelectedId,
          );
          selector.onCopy = async (text) => {
            if (!text) {
              ctx.ui.notify("Selected entry has no text to copy", "warning");
              return;
            }
            await copyToClipboard(text);
            ctx.ui.notify("Copied to clipboard", "info");
          };
          return selector;
        });

        if (!selectedId) return;
        initialSelectedId = selectedId;

        ({ entries, commonAncestorId } =
          currentLeafId === null
            ? { entries: ctx.sessionManager.getBranch(selectedId), commonAncestorId: null }
            : collectEntriesForBranchSummary(ctx.sessionManager, selectedId, currentLeafId));

        if (entries.length === 0) {
          ctx.ui.notify("Selected entry is already on the current branch", "warning");
          continue;
        }

        if (argInstructions !== undefined) break;

        let chosen = false;
        while (true) {
          const choice = await ctx.ui.select("Pull branch summary?", [
            "Summarize",
            "Summarize with custom prompt",
          ]);
          if (choice === undefined) break;
          if (choice === "Summarize with custom prompt") {
            const input = await ctx.ui.editor("Custom summarization instructions", "");
            if (input === undefined) continue;
            customInstructions = input.trim() || undefined;
          } else {
            customInstructions = undefined;
          }
          chosen = true;
          break;
        }
        if (chosen) break;
      }

      const model = ctx.model;
      const result = await ctx.ui.custom((tui, theme, _kb, done) => {
        const loader = new BorderedLoader(tui, theme, "Summarizing branch...");
        let finished = false;
        const finish = (value) => {
          if (finished) return;
          finished = true;
          loader.dispose();
          done(value);
        };
        loader.onAbort = () => finish({ aborted: true });
        generateBranchSummary(entries, {
          model,
          signal: loader.signal,
          customInstructions,
          streamFn: (m, context, options) => ({
            result: () => ctx.modelRegistry.complete(m, context, options),
          }),
        })
          .then(finish)
          .catch((err) => finish({ error: err instanceof Error ? err.message : String(err) }));
        return loader;
      });

      if (!result || result.aborted) {
        ctx.ui.notify("Branch pull cancelled", "info");
        return;
      }
      if (result.error) {
        ctx.ui.notify(result.error, "error");
        return;
      }

      pi.sendMessage({
        customType: CUSTOM_TYPE,
        content: formatContextSummary(selectedId, result.summary),
        display: true,
        details: {
          fromId: selectedId,
          commonAncestorId,
          summary: result.summary,
          readFiles: result.readFiles ?? [],
          modifiedFiles: result.modifiedFiles ?? [],
        },
      });
      ctx.ui.notify(`Pulled summary from branch ${selectedId}`, "info");
    },
  });
}
