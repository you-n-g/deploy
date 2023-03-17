#!/usr/bin/env python
import json
import copy
from pathlib import Path
import sys
import fire

NAME = "Launch Debugger"

# Here is the detailed options
# https://github.com/microsoft/debugpy/wiki/Debug-configuration-settings
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
                "program": "<path to main python file>",
                "args": [],  # the arguments you start the program
                "justMyCode#json": "${justMyCode:true}",
                # Because the varible can only accept string.
                # So we will convert it to string and then convert it to json to make its type boolean
            },
        }
    }
}


JAVA_TPL_G = {"adapters": {"java-debug-server": {"name": "vscode-java", "port": "${AdapterPort}"}}}


JAVA_TPL_V = {
    "adapters": {"java-debug-server": {"name": "vscode-java", "port": "${AdapterPort}"}},
    "configurations": {
        "Java Attach": {
            "adapter": "java-debug-server",
            "configuration": {"request": "attach", "host": "127.0.0.1", "port": "5005"},
            "breakpoints": {"exception": {"caught": "N", "uncaught": "Y"}},
        }
    },
}


class VimSpector:
    def pygen(self, script, jmc=None):
        """
        NOTE:
        - 如果有多个 `.vimspector.json`，它会优先取 % 文件当下的
        """
        tpl = copy.deepcopy(PY_TPL)
        cfg = tpl["configurations"][NAME]["configuration"]
        cfg["cwd"] = str(Path(".").absolute())
        cfg["python"] = str(Path(sys.executable).absolute())
        cfg["program"] = str(Path(script).absolute())

        if jmc is not None:
            cfg["justMyCode"] = jmc
            del cfg["justMyCode#json"]

        with open(".vimspector.json", "w") as f:
            json.dump(tpl, f)

        print('please run `:VimspectorInstall debugpy` in your vim. And press " vc" to start debugger')

    def jgen(self):
        # 后来发现  .gadgets.json 好像不需要呀
        for cfg, fname in (JAVA_TPL_G, ".gadgets.json"), (JAVA_TPL_V, ".vimspector.json"):
            with open(fname, "w") as f:
                json.dump(cfg, f)

        print("请参考 init.vim coc-java 部分的代码")


if __name__ == "__main__":
    fire.Fire(VimSpector)
