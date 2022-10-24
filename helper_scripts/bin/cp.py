#!/usr/bin/env python
"""
create project

# TODO: this scripts has following flaws
# - the second dependancy of Qlib will not be installed....  I don't know why.
#    - I tried install qlib with both `pip install -e` and `python setup.py develop` from a clean environment manually, both of them works well
# - It will be better to use `pip install -e .[dev]` for install qlib.
"""
import subprocess
from pathlib import Path

import fire
import os
import pandas as pd
from io import StringIO

# TODO:
# - replace git https url with ssh url


class CP:
    """
        (C)reate (P)roject

        运行命令之前需要确保:
        - **这里需要用户已经在特定目录下**

        其他的各种检查已经把能做的都做了

        在NFS集群上大概会花 5min; 在本地磁盘的一台新机器上只会花1min

        直接运行 `cp.py` 可以看到比 `cp.py -h` 更完整的信息
    """

    BASE_ENV = "base"

    def __init__(self, name=None, py_ver="3.8"):
        self.name = name
        self.py_ver = str(py_ver)
        # only base is supported; because the code in `_act` is based on conda base env
        assert os.environ["CONDA_DEFAULT_ENV"] == self.BASE_ENV

    def env(self):
        """
        cp.py --name auto_ops --py_ver=3.8 env

        大概需要 2m 53s
        """
        assert self.name is not None
        subprocess.run(f"conda create -y -n {self.name} python={self.py_ver}", shell=True)
        subprocess.run(f"{self._act()}; sh ~/deploy/deploy_apps/install_fav_py_pack.sh", shell=True)

    def check_env(self):
        res = subprocess.check_output(f"conda env list", shell=True)
        content = res.decode().replace("*", "")
        env_df = pd.read_csv(StringIO(content), sep=r"\s+", skiprows=2, header=None, index_col=0)
        assert self.name in env_df.index

    def _act(self):
        assert self.name is not None
        return f". $CONDA_PREFIX/etc/profile.d/conda.sh && conda activate {self.name}"

    def create(self, inst_qlib=True, force_qlib=False):
        """
        这里假设用户已经在特定目录下面了

        """
        self.check_env()
        pp = Path(".").absolute().resolve()
        lib_path = pp / "libs"
        lib_path.mkdir(exist_ok=True)
        if inst_qlib:
            subprocess.run(f"{self._act()} && pip install numpy", shell=True)
            subprocess.run(f"{self._act()} && pip install --upgrade  cython", shell=True)

            if (lib_path / "qlib").exists() and force_qlib:
                subprocess.run("rm -rf qlib", shell=True, cwd=lib_path)

            subprocess.run("git clone https://github.com/microsoft/qlib.git", shell=True, cwd=lib_path)

            subprocess.run(f"cd qlib && {self._act()} &&  pip install -e .", shell=True, cwd=lib_path)

        (pp / "scripts").mkdir(exist_ok=True)

    def setup(self, install=False):
        """Create a setup file and install it(if install==True)"""
        assert self.name is not None
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

        if install:
            cmd = "pip install -e ."
            cmd = f"{self._act()} ; {cmd}"
            subprocess.run(cmd, shell=True)

    def all(self, inst_qlib=False):
        """
        Typically usage:
            cd nestedV02 && cp.py --name nestedV02 --py_ver 3.8 all --inst_qlib
        """
        self.env()
        self.create(inst_qlib=inst_qlib)
        self.setup(install=True)


if __name__ == "__main__":
    fire.Fire(CP)
