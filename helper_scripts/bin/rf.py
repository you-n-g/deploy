#!/usr/bin/env python
import fire
from pathlib import Path
from pprint import pprint
import pickle


class ReadFile:
    def pk(self, path):
        with Path(path).open("rb") as f:
            obj = pickle.load(f)
        pprint(obj)


if __name__ == "__main__":
    fire.Fire(ReadFile)
