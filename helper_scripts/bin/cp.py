#!/usr/bin/env python
"""
create project
"""
import subprocess
from pathlib import Path

import fire


class CP:
    """(C)reate (P)roject"""
    def __init__(self, name=None):
        self.name = name

    def env(self):
        # TODO
        # subprocess.run('', shell=True)
        ...

    def create(self, inst_qlib=True, force_qlib=False):
        """
        这里假设用户已经 yxca了环境, 并且已经在目录下面了

        这里大概会花 5min
        """
        pp = Path(".").absolute().resolve()
        lib_path = pp / "libs"
        lib_path.mkdir(exist_ok=True)
        if inst_qlib:
            subprocess.run('pip install numpy', shell=True)
            subprocess.run('pip install --upgrade  cython', shell=True)

            if (lib_path / "qlib").exists() and force_qlib:
                subprocess.run('rm -rf qlib', shell=True, cwd=lib_path)

            subprocess.run('git clone https://github.com/microsoft/qlib.git', shell=True, cwd=lib_path)

            subprocess.run('cd qlib && python setup.py develop', shell=True, cwd=lib_path)

        (pp / "scripts").mkdir(exist_ok=True)

    def setup(self, name, install=False):
        content = f"""from setuptools import setup, find_packages
# 不知道为什么这个包在slave里面 一直要重新安装一下
setup(
    name='{name}',
    version='0.0.1',
    packages=find_packages(),
    install_requires=[],
)"""
        with open("setup.py", "w") as f:
            f.write(content)
        subprocess.run('python setup.py develop', shell=True)

    def all(self):
        self.env()
        self.create()


if __name__ == "__main__":
    fire.Fire(CP)
