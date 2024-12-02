import re
import pickle
from pathlib import Path
DIRNAME = Path(__file__).absolute().resolve().parent
# DIRNAME = Path("/data/home/xiaoyang/deploy/tools.py/watcher/scripts/rank_paper.py").absolute().resolve().parent

import json

def from_json():
    # p = DIRNAME.parent / 'watcher' / "openreview_w_tags.json"
    p = DIRNAME / "openreview_pool.json"
    if p.exists():
        with p.open("r") as f:
            return json.load(f)
    return []

data = from_json()

cand_list = []
cand_list_path = "scripts/cand_list_dump.pkl"

# Load cand_list from pickle if it exists
if Path(cand_list_path).exists():
    with open(cand_list_path, "rb") as dump_file:
        cand_list = pickle.load(dump_file)
else:
    for i, d in enumerate(data):
        del d['id']
        cand_list.append((i, d))

# Determine the highest pass number from existing pass files
pass_orders_dir = Path("scripts/pass_orders")
existing_pass_files = list(pass_orders_dir.glob("pass_*.pkl"))
if existing_pass_files:
    pass_numbers = [int(re.search(r"pass_(\d+).pkl", str(f)).group(1)) for f in existing_pass_files]
    last_pass_num = max(pass_numbers)

import os
from tqdm import tqdm

from rdagent.oai.llm_utils import APIBackend
from rdagent.utils.agent.tpl import T

n_pass = 100
step = 3
window = step * 2

N = len(cand_list)

# Create a directory to store the order of candidates after each pass
os.makedirs("scripts/pass_orders", exist_ok=True)

from math import comb

# Function to calculate normalized Kendall tau distance
def calculate_normalized_kendall_tau_distance(old_order, new_order):
    n = len(old_order)
    if n <= 1:
        return 0.0  # No change possible for lists of length 0 or 1

    # Create a mapping from candidate ID to its index in the new order
    new_order_index = {cand_id: idx for idx, cand_id in enumerate(new_order)}

    # Count the number of pairwise disagreements
    num_disagreements = 0
    for i in range(n):
        for j in range(i + 1, n):
            if new_order_index[old_order[i]] > new_order_index[old_order[j]]:
                num_disagreements += 1

    # Normalize the distance
    max_disagreements = comb(n, 2)  # This is n choose 2, or n*(n-1)/2
    normalized_distance = num_disagreements / max_disagreements
    return normalized_distance

start_pass = last_pass_num + 1 if existing_pass_files else 0
for pass_num in tqdm(range(start_pass, n_pass), desc="Passes"):
    old_order = [cand[0] for cand in cand_list]  # Store the old order before changes
    for start in tqdm(range(0, N, step), desc="Processing candidates", leave=False):
        comp_cand = cand_list[start:start + window]
        resp = APIBackend().build_messages_and_create_chat_completion(
            user_prompt=T(".prompts:rank.user").r(paper_l=comp_cand),
            system_prompt=T(".prompts:rank.sys").r(),
            json_mode=True)
        res = json.loads(resp)

        try:
            rank = [int(i) for i in res["rank"]]  # ensure the type of the returned json
            comp_cand.sort(key=lambda x: rank.index(x[0]))
        except ValueError:
            print("Error in value converting or sorting")
            continue
        except TypeError:
            print("Error in value Type")
            continue
        cand_list[start:start + window] = comp_cand

        # Dump the list every time we change it
        with open(cand_list_path, "wb") as dump_file:
            pickle.dump(cand_list, dump_file)

    # Dump the order of candidate IDs after each pass
    pass_order = [cand[0] for cand in cand_list]
    with open(f"scripts/pass_orders/pass_{pass_num}.pkl", "wb") as pass_file:
        pickle.dump(pass_order, pass_file)

    # Calculate and append the order change magnitude
    order_change_magnitude = calculate_normalized_kendall_tau_distance(old_order, pass_order)
    with open("scripts/order_change_magnitude.txt", "a") as magnitude_file:
        magnitude_file.write(f"Pass {pass_num}: {order_change_magnitude}\n")
