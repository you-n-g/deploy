---
name: pdf-reader
description: Reads text content from PDF files. Use when you need to extract text, analyze content, or summarize information from a PDF document. Supports limiting the number of pages read.
---

# PDF Reader Skill

## Description
This skill allows you to extract and read text content from PDF files using `pypdf`.

## Usage

To read a PDF file, execute the following command using `uv`:

```bash
uv run --with pypdf python3 ~/deploy/configs/llm/skills/pdf-reader/scripts/read_pdf.py <path_to_pdf> [--pages <number_of_pages>]
```

## Examples

**Read an entire PDF:**
```bash
uv run --with pypdf python3 ~/deploy/configs/llm/skills/pdf-reader/scripts/read_pdf.py /path/to/document.pdf
```

**Read only the first 5 pages:**
```bash
uv run --with pypdf python3 ~/deploy/configs/llm/skills/pdf-reader/scripts/read_pdf.py /path/to/document.pdf --pages 5
```

## Troubleshooting
If `uv` is not available, ensure `pypdf` is installed via pip:
```bash
pip install pypdf
python3 ~/deploy/configs/llm/skills/pdf-reader/scripts/read_pdf.py <path_to_pdf> --pages <number_of_pages>
```