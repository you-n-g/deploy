---
name: explain
description: >
  Explain a codebase in four modes: `framework` produces a high-level architecture
  walkthrough saved to `codebase-walkthrough.md`; `impl <path>` explains a specific
  implementation saved to `codebase-impl-explain.md`; `run <identifier>` explains
  a specific execution run by tracing code + logs, saved to `codebase-run-explain.md`;
  `debug [<identifier>] [<question>]` diagnoses failures and verifies fixes, saved to
  `codebase-debug.md`.
metadata:
  short-description: Codebase architecture, implementation, run & debug explainer
---

# `explain` — Codebase Explainer

## Usage

```
/explain framework
/explain impl <path>
/explain run <identifier>
/explain debug [<identifier>] [<question>]
```

`<identifier>` can be a run ID, log directory, timestamp, workspace name, tmux pane
(e.g. `MySession:7.0`), or any hint that helps locate the specific run to explain.
If omitted, explain the most recent run.

`<question>` is an optional free-text focus: a hypothesis to verify ("是不是 Codex
提前退出了"), a feature to check ("resume 机制是否生效"), or a specific failure to
investigate ("为什么 exit 23").

---

## Mode: `framework`

Produce a full architecture walkthrough and write it to **`codebase-walkthrough.md`**.

### Steps

1. **大模块识别** — 列出顶层的所有大模块（组件、服务、包），每个模块写清楚：
   - 功能职责（1–3 句）
   - 与其他模块之间的**顶层接口**（function call / RESTful API / message queue 等），指明接口定义所在的完整相对路径。
   - 不列模块内部的子接口。

2. **程序入口 & 执行流** — 找到所有程序入口（main、entrypoint、CLI command 等），按执行顺序逐步讲解系统运行过程：
   - 每个关键调用点注明它在上层的哪里被调用（完整相对路径 + 行号）。
   - 如果有多个程序需要启动，说明各自运行的环境（uv/conda/docker/虚拟机/物理机）和机器。

3. **架构改进意见** — 给出框架层面的设计改进建议，优先关注：
   - 模块数量、命名与直觉/使用场景的一致性
   - 接口冗余、任务定义不清晰、参数设置不合理

---

## Mode: `impl <path>`

### Steps

1. **内部结构** — 说明该实现内部主要分哪几个大块（类、函数组、文件）。

2. **技巧与注意事项** — 对于实现的核心功能，提炼出关键技巧和注意事项，使得初级程序员也能实现相同功能。排列时**把大多数人不知道的放在前面**。

3. **运行环境** — 如果涉及特殊环境（uv/conda/docker/虚拟机），说明在哪个环境哪台机器上运行。

---

## Mode: `debug [<identifier>] [<question>]`

诊断一次运行的失败原因，验证特定功能/修复是否生效。写入 **`codebase-debug.md`**。

与 `run` 模式的关系：两者结构类似（都是从启动到结束逐步追踪），区别在于**侧重点**：
- `run` 没有特别重的侧重点，均匀地解释每个阶段做了什么。
- `debug` 的侧重点是**异常**：重点展开异常之处，追踪这个异常是如何一步步引导出最终
  bug 的；正常运行的部分一行带过。

### Locating the run

1. 如果 `<identifier>` 是 tmux pane（如 `MySession:7.0`），先 capture pane 内容。
2. 如果是 log dir / workspace name / timestamp，定位日志文件。
3. 如果省略，取最近一次运行。

### Steps

1. **Triage（快速总览）** — 一张表，不写废话：

   | Workspace | 阶段 | Exit Code | 一句话原因 |
   |-----------|------|-----------|-----------|

   标注几个成功几个失败。

2. **从启动到出错的完整链条** — 这是 debug 模式的核心。对**每个失败的
   workspace**，按执行顺序逐步追踪，从入口一直到报错那一行。每一步都必须包含：

   a. **源码位置** — `完整路径/file.py:行号` + `Class->function` 可读路径
   b. **参考代码** — 摘出该步的关键代码片段（3-10 行），让读者不用打开文件就能理解逻辑
   c. **运行时证据** — 如果该步产生了 log 输出，原文摘录相关行（不转述）
   d. **跳转说明** — 这一步结束后控制流去了哪里（正常路径 vs 实际走的路径）

   格式示例：
   ```
   ### Step N: <简述>

   **源码**: `ai4ai/agents/developer/run.sh:210` → `run_codex_on_gpu()`
   **代码**:
   ​```bash
   rsync -azL -e "ssh ... -p ${REMOTE_PORT}" \
     "${WORKSPACE_DIR}/" "${REMOTE_USER}@${REMOTE_HOST}:${remote_root}/"
   ​```
   **Log 证据**:
   > symlink has no referent: ".../model/artifacts/snapshot"
   > rsync error: ... (code 23) at main.c(1338) [sender=3.2.7]

   **跳转**: rsync exit 23 → `set -e` (run.sh:26) 终止脚本 → EXIT trap (run.sh:368)
   ```

   要求：
   - 链条必须从程序入口开始（`run.sh` / `loop.py:main()`），不能从中间开始
   - 链条必须到达实际报错的那一行，不能在中间停下
   - 每步之间的调用关系必须显式写出（谁调了谁、在哪一行）
   - 如果某个步骤是"正常通过"的，一行带过即可（如 "setup_remote_codex 成功"）
   - 在失败点之后，追踪错误是如何传播的（exit code 如何传递、是否被捕获或丢弃）

3. **Root Cause 总结** — 用一段话明确回答"为什么失败了"：
   - 出错的值是什么，正确的值应该是什么
   - 如果有计算/路径错误，列出推导过程
   - 如果是外部原因（API 错误、机器不可达），引用原始错误信息

4. **Feature 验证**（仅当 `<question>` 涉及功能检查时）:

   对每个要验证的功能：
   - **是否触发了？** — 日志中触发的证据（原文引用）或缺失的证据
   - **行为是否正确？** — 对比代码预期 vs 实际表现
   - **效果如何？** — 带来了什么实际改善或没有改善

5. **修复建议** — 按优先级排列：

   | 优先级 | 问题 | 修复位置 (`file:line`) | 具体改法 |
   |--------|------|----------------------|---------|

6. **Key File Index** — 所有引用的文件路径 + 行号，按类别分组。

---

## Mode: `run <identifier>`

Explain how a specific execution run actually worked, tracing code paths against real
log output. Write to **`codebase-run-explain.md`**.

### Locating the run

1. Use `<identifier>` (run ID, log dir, timestamp, workspace name) to find the run's
   log files and output artifacts. Search log directories, workspace dirs, etc.
2. If `<identifier>` is omitted, find the most recent run (latest log dir by timestamp).

### Steps

1. **Architecture Overview** — Draw the execution flow as an ASCII diagram showing the
   entry point, each stage/step, and which sub-processes or agents are spawned. Include
   full paths to the source files that define each stage.

2. **逐步追踪** — For each stage of the run, in execution order:
   - **代码入口**: which code file + line triggers this stage (full path:line).
   - **实际命令**: the shell command or function call that was executed.
   - **Log 摘要**: read the stage's log file; report:
     - First few lines (startup, config, banner).
     - Key events (what the agent/process actually did, decisions made).
     - Last few lines (final status, exit code, token usage if applicable).
     - Error messages if any.
   - **产出文件**: list the files this stage created or modified (full paths).

3. **Timeline & Metrics** — Summarize wall-clock timing per stage and overall, plus any
   resource metrics found in logs (token counts, GPU usage, data sizes, etc.) as a table.

4. **Data Flow** — ASCII diagram showing how data/artifacts flow between stages: what
   each stage reads as input and what it produces as output.

5. **结果判定** — Explain the final outcome: success/failure classification, why, and
   what the key evidence was. If the run failed, pinpoint where and likely why.

6. **Key File Index** — A final section listing every referenced file path with line
   number, grouped by category (code, logs, outputs, config). This section is the
   primary navigation aid for Vim users.

---

## General rules

- 文件引用始终写完整相对路径，格式：`path/to/file.py:line`，即使介绍子目录内容时也不省略前缀。
  - 一定要写清楚行数，方便我定位；最好能带上能定位到代码的更容易读的路径，比如`AAAA[class]->BBBB[func]`
  - 我平时会使用 vim 的 gf 来做代码跳转，请务必保证用完整路径，让我跳转的时候能到准确位置。
    - 一定不要省略路径！ 如果你写成 `path/a......z/file.py:line`，我就会很难定位到它。
- 输出文件直接写在**项目根目录**，Markdown 格式，不要写在子目录里。
- 语言跟随用户：用户用中文问就用中文写，用英文问就用英文写。
