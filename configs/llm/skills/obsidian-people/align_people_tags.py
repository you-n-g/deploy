import os
import re
import sys

# 简易 Frontmatter 解析与修改器
def read_frontmatter(file_path):
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            lines = f.readlines()
    except:
        return None, None

    if not lines or lines[0].strip() != '---':
        return None, lines

    frontmatter = []
    content_start = 0
    for i in range(1, len(lines)):
        if lines[i].strip() == '---':
            content_start = i + 1
            break
        frontmatter.append(lines[i])
    else:
        return None, lines # No closing ---

    return frontmatter, lines[content_start:]

def parse_tags_aliases(frontmatter_lines):
    tags = []
    aliases = []
    
    current_key = None
    
    for line in frontmatter_lines:
        stripped = line.strip()
        if not stripped: continue
        
        # Key Detection
        if stripped.startswith('tags:'):
            current_key = 'tags'
            val = stripped[5:].strip()
            if val and not val.startswith('['): # Inline scalar
                tags.extend([t.strip() for t in val.split() if t.strip()])
            elif val.startswith('[') and val.endswith(']'): # Inline list
                tags.extend([t.strip() for t in val[1:-1].split(',') if t.strip()])
        elif stripped.startswith('tag:'):
            current_key = 'tags'
            val = stripped[4:].strip()
            if val: tags.append(val)
            
        elif stripped.startswith('aliases:') or stripped.startswith('alias:'):
            current_key = 'aliases'
            val = stripped.split(':', 1)[1].strip()
            if val.startswith('[') and val.endswith(']'):
                aliases.extend([a.strip() for a in val[1:-1].split(',') if a.strip()])
            elif val:
                aliases.append(val)
                
        elif stripped.startswith('- ') and current_key == 'tags':
            tags.append(stripped[2:].strip())
        elif stripped.startswith('- ') and current_key == 'aliases':
            aliases.append(stripped[2:].strip())
        elif ':' in stripped:
            current_key = None # Other keys
            
    return tags, aliases

def update_file_tags(file_path, new_tag, dry_run=True):
    with open(file_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    if not lines or lines[0].strip() != '---':
        print(f"  [SKIP] No frontmatter in {os.path.basename(file_path)}")
        return

    tags_line_idx = -1
    insert_idx = -1
    has_tags = False
    
    for i, line in enumerate(lines):
        if line.strip() == '---' and i > 0:
            insert_idx = i
            break
        if line.strip().startswith('tags:'):
            tags_line_idx = i
            has_tags = True
    
    if dry_run:
        print(f"  [PLAN] Add '{new_tag}' to {os.path.basename(file_path)}")
        return

    # 实际修改
    if has_tags:
        if '[' in lines[tags_line_idx] and ']' in lines[tags_line_idx]:
            current_line = lines[tags_line_idx]
            match = re.search(r'\[(.*?)\]', current_line)
            if match:
                content = match.group(1)
                new_content = f"[{content}, {new_tag}]" if content.strip() else f"[{new_tag}]"
                lines[tags_line_idx] = current_line.replace(f"[{content}]", f"[{new_content}]")
        else:
            j = tags_line_idx + 1
            while j < len(lines) and (lines[j].strip().startswith('- ') or not lines[j].strip()):
                j += 1
            lines.insert(j, f"  - {new_tag}\n")
    else:
        if insert_idx > 0:
            lines.insert(insert_idx, f"tags:\n  - {new_tag}\n")
        else:
            return

    with open(file_path, 'w', encoding='utf-8') as f:
        f.writelines(lines)
    print(f"  [DONE] Updated {os.path.basename(file_path)}")

def main(vault_path, execute):
    people_dir = os.path.join(vault_path, 'People')
    if not os.path.exists(people_dir):
        print(f"People directory not found in {vault_path}")
        return

    print("Scanning vault for #p/ tags...")
    p_tags = set()
    
    # 正则：匹配 #p/ 后面跟中文、字母、数字、下划线、中划线、斜杠
    tag_pattern = re.compile(r'(#p/[\w\u4e00-\u9fa5/\-]+)')
    
    for root, dirs, files in os.walk(vault_path):
        if '.git' in dirs: dirs.remove('.git')
        for file in files:
            if file.endswith('.md'):
                try:
                    with open(os.path.join(root, file), 'r', encoding='utf-8') as f:
                        content = f.read()
                        matches = tag_pattern.findall(content)
                        for m in matches:
                            p_tags.add(m)
                except:
                    pass

    print(f"Found {len(p_tags)} unique #p/ tags.")

    print("Indexing People files...")
    people_map = {}
    
    for root, dirs, files in os.walk(people_dir):
        for file in files:
            if not file.endswith('.md'): continue
            
            path = os.path.join(root, file)
            filename = file[:-3]
            
            people_map[filename] = path
            
            fm, _ = read_frontmatter(path)
            if fm:
                _, aliases = parse_tags_aliases(fm)
                for a in aliases:
                    people_map[a] = path

    print("\nAligning tags to People files...")
    count = 0
    for tag in p_tags:
        # 提取名字: #p/ms/name -> name, #p/Alice -> Alice
        name_key = tag.split('/')[-1]
        
        target_file = None
        
        if name_key in people_map:
            target_file = people_map[name_key]
        else:
            name_space = name_key.replace('_', ' ')
            if name_space in people_map:
                target_file = people_map[name_space]
        
        if target_file:
            fm, _ = read_frontmatter(target_file)
            existing_tags, _ = parse_tags_aliases(fm) if fm else ([], [])
            
            clean_existing = [t.strip().lstrip('#') for t in existing_tags]
            clean_new = tag.lstrip('#')
            
            if clean_new not in clean_existing:
                print(f"Tag {tag} missing in {os.path.basename(target_file)}")
                update_file_tags(target_file, tag, dry_run=not execute)
                count += 1
        else:
            pass
            
    if count == 0:
        print("All aligned! No files needed updates.")
    else:
        if not execute:
            print(f"\n[Preview] Total updates proposed: {count}")
            print("Run with --exec to apply changes.")
        else:
            print(f"\nTotal updates made: {count}")

if __name__ == "__main__":
    vault = sys.argv[1] if len(sys.argv) > 1 else "."
    execute = "--exec" in sys.argv
    main(vault, execute)
