# from rdagent.oai import

from rdagent.oai.llm_utils import APIBackend
from rdagent.utils.agent.tpl import T
from tqdm.auto import tqdm

system_prompt = T(".classify:system")
user_prompt = T(".classify:user")


from pathlib import Path
DIRNAME = Path(__file__).absolute().resolve().parent

import json

with (DIRNAME.parent / 'watcher' / "openreview.json").open("r") as f:
    data = json.load(f)


def to_json(data):
    with (DIRNAME.parent / 'watcher' / "openreview_w_tags.json").open("w") as f:
        json.dump(data, f)

def from_json():
    p = DIRNAME.parent / 'watcher' / "openreview_w_tags.json"
    if p.exists():
        with p.open("r") as f:
            return json.load(f)
    return  []

data_w_tags = from_json()
for p in tqdm(data):
    for d in data_w_tags:
        if d["id"] == p["id"]:
            break
    else:
        resp = APIBackend().build_messages_and_create_chat_completion(user_prompt=user_prompt.r(title=p['title'], abstract=p['abstract']), system_prompt=system_prompt.r(), json_mode=True)
        p_w_tag = p.copy()
        p_w_tag['tags'] = json.loads(resp)['tags']
        data_w_tags.append(p_w_tag)
        to_json(data_w_tags)
