import sys
import os
import argparse

try:
    from pypdf import PdfReader
except ImportError:
    print("Error: pypdf is not installed.")
    print("Please run with: uv run --with pypdf python <script_path> <pdf_path>")
    sys.exit(1)

def read_pdf(file_path, page_limit=None):
    if not os.path.exists(file_path):
        print(f"Error: File not found at {file_path}")
        sys.exit(1)
        
    try:
        reader = PdfReader(file_path)
        number_of_pages = len(reader.pages)
        
        pages_to_read = number_of_pages
        if page_limit is not None:
            pages_to_read = min(number_of_pages, page_limit)

        print(f"--- Start of PDF: {file_path} (Reading {pages_to_read} of {number_of_pages} pages) ---")
        
        for i in range(pages_to_read):
            page = reader.pages[i]
            text = page.extract_text()
            print(f"--- Page {i+1} ---")
            if text:
                print(text)
            else:
                print("[No text extracted from this page]")
            print("\n")
                    
        print(f"--- End of PDF: {file_path} ---")
    except Exception as e:
        print(f"Error reading PDF: {e}")
        sys.exit(1)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Read text from a PDF file.")
    parser.add_argument("file_path", help="Path to the PDF file.")
    parser.add_argument("--pages", type=int, help="Limit the number of pages to read.")
    
    args = parser.parse_args()
    
    read_pdf(args.file_path, args.pages)
