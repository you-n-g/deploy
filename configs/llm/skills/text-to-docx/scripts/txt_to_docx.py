import sys
import os
import argparse

try:
    from docx import Document
except ImportError:
    print("Error: python-docx is not installed.")
    print("Please run with: uv run --with python-docx python <script_path> <input_txt> <output_docx>")
    sys.exit(1)

def convert_txt_to_docx(input_path, output_path):
    if not os.path.exists(input_path):
        print(f"Error: Input file not found at {input_path}")
        sys.exit(1)
        
    try:
        document = Document()
        
        with open(input_path, 'r', encoding='utf-8') as f:
            for line in f:
                document.add_paragraph(line.rstrip('\n'))
        
        document.save(output_path)
        print(f"Successfully converted {input_path} to {output_path}")
    except Exception as e:
        print(f"Error during conversion: {e}")
        sys.exit(1)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Convert a text file to a DOCX document.")
    parser.add_argument("input_txt", help="Path to the input text file.")
    parser.add_argument("output_docx", help="Path to the output DOCX file.")
    
    args = parser.parse_args()
    
    convert_txt_to_docx(args.input_txt, args.output_docx)
