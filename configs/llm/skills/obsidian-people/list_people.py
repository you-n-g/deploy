import os
import sys

def parse_simple_yaml(text):
    """
    A very basic YAML parser to avoid external dependencies like PyYAML.
    Handles:
    key: value
    key: [list, items]
    key:
      - list item
    """
    data = {}
    lines = text.split('\n')
    current_key = None
    
    for line in lines:
        stripped = line.strip()
        if not stripped:
            continue
            
        if ':' in line:
            parts = line.split(':', 1)
            key = parts[0].strip()
            val = parts[1].strip()
            
            if val:
                # Inline value
                if val.startswith('[') and val.endswith(']'):
                    # Inline list
                    items = [v.strip() for v in val[1:-1].split(',')]
                    data[key] = items
                else:
                    # String value
                    # Remove quotes if present
                    if (val.startswith('"') and val.endswith('"')) or (val.startswith("'") and val.endswith("'")):
                        val = val[1:-1]
                    data[key] = val
                current_key = None # Reset
            else:
                # Key with potential nested list next
                current_key = key
                data[key] = []
        
        elif stripped.startswith('- ') and current_key:
            # List item
            val = stripped[2:].strip()
            if isinstance(data[current_key], list):
                data[current_key].append(val)

    return data

def parse_frontmatter(file_path):
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            lines = f.readlines()
    except Exception:
        return None

    if not lines or not lines[0].strip() == '---':
        return None

    frontmatter = []
    i = 1
    while i < len(lines):
        line = lines[i]
        if line.strip() == '---':
            break
        frontmatter.append(line)
        i += 1
    
    if i == len(lines):
        return None

    fm_text = "".join(frontmatter)
    
    # Try PyYAML first, fall back to manual
    try:
        import yaml
        data = yaml.safe_load(fm_text)
    except ImportError:
        data = parse_simple_yaml(fm_text)
    except Exception:
        data = {}

    return data

def scan_people(base_dir):
    # Try to find 'People' directory
    people_dir = os.path.join(base_dir, 'People')
    
    if not os.path.isdir(people_dir):
        # Maybe we are already inside a structure that has people files?
        # Or maybe the folder is lowercase?
        if os.path.isdir(os.path.join(base_dir, 'people')):
            people_dir = os.path.join(base_dir, 'people')
        elif os.path.basename(os.path.abspath(base_dir)).lower() == 'people':
             people_dir = base_dir
        else:
            # Just scan the current directory if 'People' isn't found, 
            # but warn the user.
            # actually, let's strictly look for People to avoid scanning the whole vault
            print(f"Warning: 'People/' directory not found in {base_dir}. Scanning root...")
            people_dir = base_dir

    print(f"Scanning directory: {people_dir}\n")
    
    # Header
    print(f"{'Name':<25} | {'Aliases':<25} | {'Tags'}")
    print("-" * 80)

    for root, dirs, files in os.walk(people_dir):
        # Skip hidden folders
        dirs[:] = [d for d in dirs if not d.startswith('.')]

        for file in files:
            if not file.endswith('.md'):
                continue
            
            file_path = os.path.join(root, file)
            filename = file[:-3]
            
            data = parse_frontmatter(file_path)
            
            # If no frontmatter, define defaults
            if data is None: 
                data = {}

            # Logic to determine Name
            # 1. 'name' field in frontmatter
            # 2. Filename
            name = data.get('name')
            if not name:
                name = filename
            
            # Logic to determine Aliases
            aliases = data.get('aliases', data.get('alias', []))
            if isinstance(aliases, str):
                aliases = [aliases]
            elif aliases is None:
                aliases = []
            
            # Logic to determine Tags
            tags = data.get('tags', data.get('tag', []))
            if isinstance(tags, str):
                if ',' in tags:
                    tags = [t.strip() for t in tags.split(',')]
                else:
                    tags = tags.split()
            elif tags is None:
                tags = []

            # Filter tags to only include those starting with p/ or #p/
            tags = [t for t in tags if str(t).startswith('p/') or str(t).startswith('#p/')]

            # Format for output
            alias_str = ", ".join(str(a) for a in aliases)
            tag_str = ", ".join(str(t) for t in tags)

            # Truncation for clean table
            d_name = (str(name)[:22] + '..') if len(str(name)) > 24 else str(name)
            d_alias = (alias_str[:22] + '..') if len(alias_str) > 24 else alias_str
            
            print(f"{d_name:<25} | {d_alias:<25} | {tag_str}")

if __name__ == "__main__":
    target_dir = sys.argv[1] if len(sys.argv) > 1 else "."
    scan_people(target_dir)
