"""
pip install openpyxl
"""
from rich.console import Console
from rich.traceback import install

# Create a console that does not use color
console = Console(color_system=None)
install(console=console, show_locals=True, code_width=128)  # , max_frames=5  # , extra_lines=0

import pickle
import json
import pandas as pd
from pathlib import Path


DIRNAME = Path(__file__).absolute().resolve().parent

# Part 1: Loading raw data and processing tags

def load_and_process_rank_data():
    """
    We may not have tags in the rank data.
    """
    with open(DIRNAME / "cand_list_dump.pkl", "rb") as dump_file:
        final_cand_list = pickle.load(dump_file)[::-1]

    data = [d for _, d in final_cand_list]
    data = process_tags(data)
    return data

def load_and_process_tag_data():
    """Tag is contained in the data."""
    data = json.loads(open(DIRNAME.parent / "watcher" / "openreview_w_tags.json").read())
    data = process_tags(data)
    return data

def process_tags(data):
    for d in data:
        if "tags" in d:
            for t in d["tags"]:
                if t.get("relevant", False):
                    d[f"tag/{t['tag']}"] = t["reason"]
            del d["tags"]
    return data

# Part 2: Post processing for specific user purpose

def filter_related_papers(data, tags):
    def has_tag(paper, tag):
        for t in paper["tags"]:
            if t["relevant"] and t["tag"] == tag:
                return True
        return False

    related_papers = [d for d in data if all(has_tag(d, tag) for tag in tags)]
    return related_papers

def merge_tag_to_rank(rank_data, tag_data):
    """
    The data is merged on paper name
    """
    # Convert list of dictionaries to DataFrame for easier merging
    rank_df = pd.DataFrame(rank_data)
    tag_df = pd.DataFrame(tag_data)

    # Assuming 'title' is the key to merge on
    merged_df = pd.merge(rank_df, tag_df, on="title", how="inner")

    # Sanitize the merged DataFrame to remove illegal characters for Excel
    merged_df = merged_df.applymap(sanitize_for_excel)
    return merged_df

# Sanitize the data to remove illegal characters
def sanitize_for_excel(value):
    if isinstance(value, str):
        # Remove or replace illegal characters
        return ''.join(c for c in value if c.isprintable() and c not in ['\x00', '\x01', '\x02', '\x03', '\x04', '\x05', '\x06', '\x07', '\x08', '\x09', '\x0A', '\x0B', '\x0C', '\x0D', '\x0E', '\x0F', '\x10', '\x11', '\x12', '\x13', '\x14', '\x15', '\x16', '\x17', '\x18', '\x19', '\x1A', '\x1B', '\x1C', '\x1D', '\x1E', '\x1F'])
    return value

# Main execution
if __name__ == "__main__":
    rank_data = load_and_process_rank_data()
    tag_data = load_and_process_tag_data()

    merged_data = merge_tag_to_rank(rank_data, tag_data)
    print(merged_data)
    # print(merged_data.columns)
    focus_df = merged_data[~merged_data["tag/Agent.Reason"].isna() & ~merged_data["tag/LLM"].isna()]
    print(focus_df)
    focus_df.to_excel(DIRNAME / "data_rank.agent.reason.xlsx")

    # Apply the sanitization to the entire DataFrame
    df = pd.DataFrame(merged_data)
    # df = df.applymap(sanitize_for_excel)
    # df.to_excel(DIRNAME / "data_rank.xlsx")
