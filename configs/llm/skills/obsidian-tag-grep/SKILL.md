---
name: obsidian-tag-grep
description:
  Expertise in searching Obsidian vaults for notes containing specific hierarchical tags and extracting contextual information. Use when the user asks to "search" or "find" information related to tags in their Obsidian knowledge base.
---
# Obsidian Tag Grep Skill

## Description
This skill allows you to search your Obsidian knowledge base for notes containing a specific hierarchical tag (e.g., `#p/ms/name`). It finds relevant Markdown files and extracts contextual blocks (like headers or list items) surrounding the tag.

## Usage
To use this skill, navigate to the root directory of the Obsidian vault you wish to search. Then, execute the `run.sh` script, providing the tag you want to find as an argument.

**Command:**
```bash
cd /path/to/your/obsidian/vault
~/deploy/configs/llm/skills/obsidian-tag-grep/run.sh <your_tag_query>
```

**Example:**
To search for the tag `#p/ms/name` within your main Obsidian vault located at `/mnt/c/data/obsidian/main/`:
```bash
cd /mnt/c/data/obsidian/main/
~/deploy/configs/llm/skills/obsidian-tag-grep/run.sh p/ms/name
```

## How it Works
The `run.sh` script acts as a wrapper for the `search_tag_tree.py` Python script. It automatically sets the Obsidian vault path to your current working directory and passes the provided tag query to the Python script for processing.

The Python script then recursively searches Markdown files within that directory for lines containing the specified tag. When a tag is found, it attempts to extract the surrounding logical block (e.g., content under the same header or within a list item) to provide context.

## Notes
- The script searches the **current directory** where `run.sh` is executed. Ensure you `cd` into the desired Obsidian vault's root directory before running.
- Tags should be provided without the leading `#` when calling `run.sh` (e.g., `p/ms/name` instead of `#p/ms/name`), as the Python script handles adding it.
