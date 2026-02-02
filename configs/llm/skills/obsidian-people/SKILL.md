---
name: obsidian-people
description:
  Expertise in listing people profiles from an Obsidian vault. It scans the 'People' directory and extracts names, aliases, and tags from the frontmatter of markdown files. Use when the user asks to "list people", "show contacts", or "who is in my vault".
---
# Obsidian People Lister Skill

## Description
This skill scans your Obsidian vault (specifically the `People/` directory) for Markdown files representing people. It parses the YAML frontmatter of each file to extract and display key metadata:
- **Name**: From the `name` field or filename.
- **Aliases**: From the `aliases` or `alias` field.
- **Tags**: From the `tags` or `tag` field.

It presents this information in a neat, tabular format.

## Usage
To use this skill, navigate to the root directory of your Obsidian vault. Then execute the `run.sh` script.

**Command:**
```bash
cd /path/to/your/obsidian/vault
~/deploy/configs/llm/skills/obsidian-people/run.sh
```

**Optional:** You can pass a specific directory path as an argument if you are not currently in the vault root.
```bash
~/deploy/configs/llm/skills/obsidian-people/run.sh /path/to/vault
```

## How it Works
1.  The script looks for a `People` (or `people`) directory within the target path.
2.  It iterates through all `.md` files in that directory.
3.  For each file, it reads the YAML frontmatter (the block between `---` at the top).
4.  It extracts `name`, `aliases`, and `tags` using a robust parser (falling back to a simple manual parser if `PyYAML` is not installed).
5.  It prints a formatted table of the results.

## Notes

If the user provides more details about a person, such as an alias, please help update that person's information.
