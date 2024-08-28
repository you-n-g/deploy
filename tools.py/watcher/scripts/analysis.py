from pathlib import Path
DIRNAME = Path(__file__).absolute().resolve().parent


data_path = DIRNAME.parent / "watcher"  / "openreview_w_tags.json"
import json

with data_path.open("r") as f:
    data = json.load(f)

from IPython import embed; embed()

for d in data:
    for t in d["tags"]:
        d[f"tag/{t['tag']}"] = t["reason"]
    del d["tags"]

import pandas as pd
df = pd.DataFrame(data)

df.head()
df.columns

.sum()

relavent = (~(df["tag/Agent"].isna() | df["tag/LLM"].isna()))
spotlight = (df["venue"] == "Spotlight")

(relavent & spotlight).sum()

df[relavent & spotlight].to_excel(DIRNAME / "data_spotlight.xlsx")


df.to_excel(DIRNAME / "data.xlsx")
