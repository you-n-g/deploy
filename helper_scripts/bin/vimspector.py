#!/usr/bin/env python
import json
import copy
from pathlib import Path
import sys
import fire

NAME = 'Launch Debugger'

PY_TPL = {
  "configurations": {
    NAME: {
      "adapter": "debugpy",
      "configuration": {
        "name": NAME,
        "type": "python",
        "request": "launch",
        "cwd": "<working directory>",
        "python": "</path/to/python/interpreter/to/use>",
        "stopOnEntry": True,
        "console": "externalTerminal",
        "debugOptions": [],
        "program": "<path to main python file>"
      }
    }
  }
}



JAVA_TPL = {
  "adapters": {
    "java-debug-server": {
      "name": "vscode-java",
      "port": "${AdapterPort}"
    }
  }
}


class VimSpector:
    def pygen(self, script):
        tpl = copy.deepcopy(PY_TPL)
        cfg = tpl["configurations"][NAME]["configuration"]
        cfg["cwd"] = str(Path(".").absolute())
        cfg["python"] = str(Path(sys.executable).absolute())
        cfg["program"] = str(Path(script).absolute())

        with open('.vimspector.json', 'w') as f:
            json.dump(tpl, f)

        print('please run `:VimspectorInstall debugpy` in your vim. And press " vc" to start debugger')

    def jgen(self):
        with open(".gadgets.json", "w") as f:
            json.dump(JAVA_TPL, f)

        print("请参考 init.vim coc-java 部分的代码")


if __name__ == "__main__":
    fire.Fire(VimSpector)
