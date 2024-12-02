"""
pip install openpyxl
"""
import pickle
from pathlib import Path
DIRNAME = Path(__file__).absolute().resolve().parent
with open("scripts/cand_list_dump.pkl", "rb") as dump_file:
    final_cand_list = pickle.load(dump_file)[::-1]
__import__('pprint').pprint(final_cand_list[:8])

data = [d for _, d in final_cand_list]
for d in data:
    for t in d["tags"]:
        if t["relevant"]:
            d[f"tag/{t['tag']}"] = t["reason"]
    del d["tags"]


import pandas as pd
df = pd.DataFrame(data)

# FIXME: it raise IllegalCharacterError(f"{value} cannot be used in worksheets.")
# Sanitize the data to remove illegal characters
def sanitize_for_excel(value):
    if isinstance(value, str):
        # Remove or replace illegal characters
        return ''.join(c for c in value if c.isprintable() and c not in ['\x00', '\x01', '\x02', '\x03', '\x04', '\x05', '\x06', '\x07', '\x08', '\x09', '\x0A', '\x0B', '\x0C', '\x0D', '\x0E', '\x0F', '\x10', '\x11', '\x12', '\x13', '\x14', '\x15', '\x16', '\x17', '\x18', '\x19', '\x1A', '\x1B', '\x1C', '\x1D', '\x1E', '\x1F'])
    return value

# Apply the sanitization to the entire DataFrame
df = df.applymap(sanitize_for_excel)
df.to_excel(DIRNAME / "data_rank.xlsx")
