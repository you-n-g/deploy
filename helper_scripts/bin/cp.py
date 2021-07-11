#!/usr/bin/env python
"""
create project
"""
import subprocess
from pathlib import Path

import fire
import os
import pandas as pd
from io import StringIO


class CP:
    """(C)reate (P)roject"""

    BASE_ENV = "base"
    def __init__(self, name=None, py_ver="3.8"):
        self.name = name
        self.py_ver = str(py_ver)
        # only base is supported; because the code in `_act` is based on conda base env
        assert(os.environ["CONDA_DEFAULT_ENV"] == self.BASE_ENV)

    def env(self):
        assert(self.name is not None)
        subprocess.run(f'conda create -y -n {self.name} python={self.py_ver}', shell=True)
        subprocess.run(f"{self._act()}; sh ~/deploy/deploy_apps/install_fav_py_pack.sh", shell=True)

    def check_env(self):
        res = subprocess.check_output(f"conda env list", shell=True)
        content = res.decode().replace("*", "")
        env_df = pd.read_csv(StringIO(content), sep=r"\s+", skiprows=2, header=None, index_col=0)
        assert(self.name in env_df.index)

    def _act(self):
        assert(self.name is not None)
        return f". $CONDA_PREFIX/etc/profile.d/conda.sh && conda activate {self.name}"

    def create(self, inst_qlib=True, force_qlib=False):
        """
        这里假设用户已经 yxca了环境, 并且已经在目录下面了

        这里大概会花 5min
        """
        self.check_env()
        pp = Path(".").absolute().resolve()
        lib_path = pp / "libs"
        lib_path.mkdir(exist_ok=True)
        if inst_qlib:
            subprocess.run(f'{self._act()} && pip install numpy', shell=True)
            subprocess.run(f'{self._act()} && pip install --upgrade  cython', shell=True)

            if (lib_path / "qlib").exists() and force_qlib:
                subprocess.run('rm -rf qlib', shell=True, cwd=lib_path)

            subprocess.run('git clone https://github.com/microsoft/qlib.git', shell=True, cwd=lib_path)

            subprocess.run(f'cd qlib && {self._act()} &&  python setup.py develop', shell=True, cwd=lib_path)

        (pp / "scripts").mkdir(exist_ok=True)

    def setup(self, install=False):
        assert(self.name is not None)
        content = f"""from setuptools import setup, find_packages
# 不知道为什么这个包在slave里面 一直要重新安装一下
setup(
    name='{self.name}',
    version='0.0.1',
    packages=find_packages(),
    install_requires=[],
)"""
        with open("setup.py", "w") as f:
            f.write(content)
        cmd = 'python setup.py develop'
        if install:
            cmd = f'{self._act()} ; {cmd}'
        subprocess.run(cmd, shell=True)

    def all(self):
        """
        Typically usage:
            cp.py --name nestedV02 --py_ver 3.7 all
        """
        self.env()
        self.create()
        self.setup()


if __name__ == "__main__":
    fire.Fire(CP)
