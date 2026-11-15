#!/usr/bin/env node
/**
 * Clone the live DSH session held by PID into an independent V4 session,
 * safely closing any in-flight turn/tool calls via @deepseek-ai/dsh-session/fork.
 */
import { execFileSync } from "node:child_process";
import { randomUUID } from "node:crypto";
import { existsSync, readFileSync, realpathSync, renameSync, writeFileSync } from "node:fs";
import { createRequire } from "node:module";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const pid = process.argv[2];
if (!pid) {
  process.stderr.write("usage: fork.mjs PID\n");
  process.exit(64);
}

const here = dirname(realpathSync(fileURLToPath(import.meta.url)));
const rawLocks = execFileSync("python3", [join(here, "session.py"), "locks", pid], {
  encoding: "utf8",
  env: process.env,
}).trim();

const candidates = rawLocks
  .split("\n")
  .filter(Boolean)
  .map((line) => {
    const [id, root] = line.split("\t");
    return { id, root };
  });

if (candidates.length === 0) {
  process.stderr.write(`No active DSH session found for PID ${pid}\n`);
  process.exit(1);
}

const dshPath = execFileSync("sh", ["-c", "command -v dsh"], { encoding: "utf8" }).trim();
const dshRealBin = realpathSync(dshPath);
const req = createRequire(join(dirname(dshRealBin), "../package.json"));

const { Context } = await import(req.resolve("@deepseek-ai/cordis"));
const persistencePlugin = await import(req.resolve("@deepseek-ai/dsh-session-persistence-jsonl"));
const { buildForkSeed } = await import(req.resolve("@deepseek-ai/dsh-session/fork"));

const sessionsRoot = candidates[0].root;
const ctx = new Context();
const fiber = ctx.plugin(persistencePlugin, { root: sessionsRoot });
await fiber.await();

function registerInWorkspaceFile(sessionsDir, cwd, childId) {
  if (!cwd) return;
  const wsPath = join(dirname(sessionsDir), "storages/workspace.json");
  if (!existsSync(wsPath)) return;
  try {
    const doc = JSON.parse(readFileSync(wsPath, "utf8"));
    const workspaces = doc?.tables?.workspaces;
    if (!workspaces || typeof workspaces !== "object") return;
    for (const ws of Object.values(workspaces)) {
      if (ws?.path === cwd && Array.isArray(ws.sessionIds) && !ws.sessionIds.includes(childId)) {
        ws.sessionIds.push(childId);
        ws.updatedAt = new Date().toISOString();
        const tmp = `${wsPath}.${process.pid}.tmp`;
        writeFileSync(tmp, `${JSON.stringify(doc, null, 2)}\n`, { mode: 0o600 });
        renameSync(tmp, wsPath);
        break;
      }
    }
  } catch {
    // Workspace index update is best-effort; dsh-tui --resume opens by ID directly.
  }
}

try {
  const persistence = ctx.get("sessionPersistence");
  let sourceId = null;
  if (candidates.length === 1) {
    sourceId = candidates[0].id;
  } else {
    const topLevel = [];
    for (const item of candidates) {
      const snap = await persistence.stat(item.id);
      if (snap && (snap.header.delegationDepth ?? 0) === 0) {
        topLevel.push(item.id);
      }
    }
    if (topLevel.length !== 1) {
      throw new Error(`Expected 1 top-level DSH session under PID ${pid}, found ${topLevel.length}`);
    }
    sourceId = topLevel[0];
  }

  const reader = await persistence.open(sourceId, "read");
  try {
    const { events } = await reader.read();
    const seed = events.length > 0 ? buildForkSeed(events, events[events.length - 1].seq) : [];
    const childId = randomUUID();
    const childHeader = {
      ...reader.header,
      id: childId,
      createdAt: Date.now(),
      parentSession: reader.header.id,
      isSeeded: seed.length > 0,
      delegationDepth: 0,
    };
    const writer = await persistence.create(
      childHeader,
      seed.length > 0 ? { inheritedEventCount: events.length } : {},
    );
    try {
      if (seed.length > 0) await writer.append(seed);
      await writer.flush();
    } finally {
      await writer.close();
    }
    registerInWorkspaceFile(sessionsRoot, reader.header.cwd, childId);
    process.stdout.write(`${childId}\n`);
  } finally {
    await reader.close();
  }
} finally {
  await fiber.dispose();
}
