---
name: explain
description: >
  Explain a codebase in two modes: `framework` produces a high-level architecture
  walkthrough saved to `codebase-walkthrough.md`; `impl <path>` explains a specific
  implementation saved to `codebase-impl-explain.md`.
metadata:
  short-description: Codebase architecture & implementation explainer
---

# `explain` — Codebase Explainer

## Usage

```
/explain framework
/explain impl <path>
```

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

Explain the specific implementation at `<path>` and write it to **`codebase-impl-explain.md`**.

### Steps

1. **内部结构** — 说明该实现内部主要分哪几个大块（类、函数组、文件）。

2. **技巧与注意事项** — 对于实现的核心功能，提炼出关键技巧和注意事项，使得初级程序员也能实现相同功能。排列时**把大多数人不知道的放在前面**。

3. **运行环境** — 如果涉及特殊环境（uv/conda/docker/虚拟机），说明在哪个环境哪台机器上运行。

---

## General rules

- 文件引用始终写完整相对路径，格式：`path/to/file.py:line`，即使介绍子目录内容时也不省略前缀。
  - 一定要写清楚行数，方便我定位；最好能带上能定位到代码的更容易读的路径，比如`AAAA[class]->BBBB[func]`
  - 我平时会使用 vim 的 gf 来做代码跳转，请务必保证用完整路径，让我跳转的时候能到准确位置。
- 输出文件直接写在**项目根目录**，Markdown 格式，不要写在子目录里。
- 语言跟随用户：用户用中文问就用中文写，用英文问就用英文写。
