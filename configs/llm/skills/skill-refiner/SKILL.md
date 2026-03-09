---
name: skill-refiner
description: >
  Refine an existing, locally maintained Codex skill under
  `~/deploy/configs/llm/skills/` (or `/home/xiaoyang/deploy/configs/llm/skills/`)
  using recent user feedback; keep changes small and the prompt concise.
metadata:
  short-description: Refine a skill from feedback
---

# Skill Refiner (Feedback-Driven)

Use this skill when the user wants to improve a skill’s behavior based on feedback from recent turns (e.g., “这个 skill 还不对，按我刚刚的要求改一下”).

## Guardrails

- Only edit skills that are **locally maintained** under `~/deploy/configs/llm/skills/`.
- If the target skill directory (or the file to be edited) is a **symlink**, do **not** modify it; explain why and ask the user to copy it into a non-symlink folder if they want customization.

## Operating principles

- Anchor on the **most recent** user feedback and explicit must/must-not constraints.
- Keep edits **small and iterative** unless the user asks for a rewrite.
- Prefer changes that **increase generality** (clear triggers, clear intent, fewer brittle specifics).
- Keep the prompt **short**; avoid over-prescribing exact steps when multiple approaches can work.

## Output

Briefly report:
- which feedback you applied,
- which files you changed under `~/deploy/configs/llm/skills/`,
- any open question you still need to resolve.
