#!/usr/bin/env python
import fire
import subprocess
import json
import re
from pprint import pprint
from pathlib import Path

class DV:
    def prepare(self):
        subprocess.run('sudo apt-get install -y docker', shell=True)
        subprocess.run('sudo docker pull v2ray/official', shell=True)

    def run(self, conf_path):
        conf_path = Path(conf_path)
        # read data
        with conf_path.open() as f:
            lines = f.readlines()
        data = "".join(re.sub(r"//.*$", "", line) for line in lines)
        data = json.loads(data)

        in_ports = [item['port'] for item in data['inbounds']]

        port_cmd = "".join(f" -p {p}:{p} " for p in in_ports)
        cmd = (f"sudo docker run -d --name v2ray -v {conf_path.parent.resolve()}:/etc/v2ray"
               f" {port_cmd} v2ray/official v2ray -config=/etc/v2ray/{conf_path.name}")
        subprocess.run(cmd, shell=True)

    def clean(self):
        subprocess.run('sudo docker rm v2ray', shell=True)




if __name__ == "__main__":
    fire.Fire(DV)
