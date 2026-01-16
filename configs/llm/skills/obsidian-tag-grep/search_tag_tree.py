import os
import sys
import re


def get_indentation(line):
    return len(line) - len(line.lstrip())


def is_list_item(line):
    stripped = line.lstrip()
    return (
        stripped.startswith("- ")
        or stripped.startswith("* ")
        or stripped.startswith("+ ")
        or re.match(r"^\d+\. ", stripped)
    )


def is_header(line):
    return line.lstrip().startswith("#")


def get_header_level(line):
    return len(line.lstrip().split()[0])


def search_files(directory, tag_query):
    # 处理 Tag 格式，确保包含 #
    tag_search = tag_query.strip()
    if not tag_search.startswith("#"):
        tag_search = "#" + tag_search

    print(f"Searching for structure under tag: {tag_search} in {directory}\n")

    found_any = False

    for root, dirs, files in os.walk(directory):
        # 忽略隐藏目录
        dirs[:] = [d for d in dirs if not d.startswith(".")]

        for file in files:
            if not file.endswith(".md"):
                continue

            # 忽略脚本自身
            if file == "search_tag_tree.py":
                continue

            file_path = os.path.join(root, file)
            rel_path = os.path.relpath(file_path, directory)

            try:
                with open(file_path, "r", encoding="utf-8") as f:
                    lines = f.readlines()
            except Exception:
                continue

            # 快速过滤
            content = "".join(lines)
            if tag_search not in content:
                continue

            i = 0
            file_matches = []

            while i < len(lines):
                line = lines[i]

                # 简单匹配：只要行内包含该Tag字符串
                if tag_search in line:
                    stripped = line.lstrip()
                    indent = get_indentation(line)

                    block = []
                    block.append(line.rstrip())

                    current_i = i + 1

                    if is_header(line):
                        # 逻辑：标题模式
                        header_level = get_header_level(line)
                        while current_i < len(lines):
                            next_line = lines[current_i]
                            if is_header(next_line):
                                next_level = get_header_level(next_line)
                                if next_level <= header_level:
                                    break
                            block.append(next_line.rstrip())
                            current_i += 1

                        # 更新主循环索引
                        i = current_i - 1

                    elif is_list_item(line):
                        # 逻辑：列表模式
                        # 向下读取直到遇到缩进 <= 当前缩进的非空行
                        while current_i < len(lines):
                            next_line = lines[current_i]

                            # 空行通常视为列表的一部分或者分隔符，为了连续性，保留空行
                            # 但如果连着多个空行可能意味结束。简单起见，只要下一行非空且缩进更深，或是空行，就继续。
                            if not next_line.strip():
                                block.append(next_line.rstrip())
                                current_i += 1
                                continue

                            next_indent = get_indentation(next_line)

                            if next_indent > indent:
                                block.append(next_line.rstrip())
                                current_i += 1
                            else:
                                break

                        # 更新主循环索引
                        i = current_i - 1

                    else:
                        # 普通文本行模式
                        pass

                    file_matches.append("\n".join(block))

                i += 1

            if file_matches:
                found_any = True
                print(f"📄 File: [[{rel_path}]]")
                print("=" * 40)
                for match in file_matches:
                    print(match)
                    print("-" * 20)
                print("\n")

    if not found_any:
        print("No matches found.")


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python script.py <directory> <tag>")
    else:
        search_files(sys.argv[1], sys.argv[2])
