from pathlib import Path
DIRNAME = Path(__file__).absolute().resolve().parent


data_path = DIRNAME.parent / "watcher"  / "openreview_w_tags.json"
import json

with data_path.open("r") as f:
    data = json.load(f)


for d in data:
    for t in d["tags"]:
        if t["relevant"]:
            d[f"tag/{t['tag']}"] = t["reason"]
    del d["tags"]

import pandas as pd
df = pd.DataFrame(data)

df.head()
df.columns


relevant = (~(df["tag/Agent"].isna() | df["tag/LLM"].isna()))
spotlight = (df["venue"] == "Spotlight")
rl = ~df["tag/RL"].isna()

print((relevant).sum())
print((relevant & ~rl).sum())

print((relevant & ~rl & spotlight).sum())

print((relevant & spotlight).sum())

df[relevant & spotlight].to_excel(DIRNAME / "data_spotlight.xlsx")


print((relevant & (~rl | spotlight)).sum())
df[relevant & (~rl | spotlight)].to_excel(DIRNAME / "data.xlsx")
