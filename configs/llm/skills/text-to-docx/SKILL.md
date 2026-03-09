---
name: text-to-docx
description: Converts plain text files (.txt) to Microsoft Word documents (.docx). Use when you need to create a formatted document from raw text.
---

# Text to DOCX Skill

## Description
This skill converts plain text files into `.docx` format using the `python-docx` library. It preserves line breaks by creating a new paragraph for each line in the source file.

## Usage

To convert a text file, execute the following command using `uv`:

```bash
uv run --with python-docx python3 ~/deploy/configs/llm/skills/text-to-docx/scripts/txt_to_docx.py <input_txt> <output_docx>
```

## Examples

**Convert a log file to Word:**
```bash
uv run --with python-docx python3 ~/deploy/configs/llm/skills/text-to-docx/scripts/txt_to_docx.py notes.txt notes.docx
```

## Troubleshooting
If `uv` is not available, ensure `python-docx` is installed via pip:
```bash
pip install python-docx
python3 ~/deploy/configs/llm/skills/text-to-docx/scripts/txt_to_docx.py input.txt output.docx
```