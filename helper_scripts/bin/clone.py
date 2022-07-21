#!/usr/bin/env python
"""

# 脚本的功能
快速 clone 一个项目;

## 实现这个目标主要是基于 对项目结构的如下假设

project[得是个git repo]/
- data[shared, 未来这边会共享文件]/
    - dataset/
    - intermediate[这个命名有点奇怪，之前取名太随意]/
- setup.py[未来clone 环境后会依赖这个重新安装]/
- libs/
    - <每一个文件>[里面都是 git repo]/
        - 如果里面有 setup.py， 则会在新的项目中安装这个文件


# 解决的问题

## 快速检验代码的正确性
大家平时跑通代码后，常常会有各种硬编码(环境路径依赖) & 忘记提交代码;
这个脚本可以实现快速重复部署 & 运行程序， 多了一种检验代码可用的方式；

## 减少部署成本
自动clone项目

## 减少迁移成本:
低成本部署可以快速部署多个版本系统，  从而不用强制更新所有代码到最新版本

项目一般分为核心代码 & 用户代码
- 核心代码是一直会反复用的
- 用户代码是利用核心代码反复coding的代码

每次接口有大的升级的时候，如果用户代码和核心代码都升级， 代价会很大;

所以现在可以直接clone项目保留老代码 & 同时用新代码

## 让人没有后顾之忧地重构代码
总是能确保之前版本的代码是能用的，所以改起来没有后顾之忧，让代码永葆活力

# 其他信息

## 如果能保证下面的名字能一致，写代码的时候能少处理很多细节
当项目版本是  <XX> 时(比如 07)
- mlflow service: http://10.0.0.4:50<XX>/
- 项目地址: "/home/xiaoyang/repos/online3rd_projects/V<XX>/"
- 环境名字: "online_V<XX>"
- task_db_name: "online_V<XX>"
- tmux session name: "online_V<XX>"

当要做实验时(比如实验名字是 <YY>)
- data/<YY>/
- exps/<YY>/

"""

from io import StringIO
import os
from pathlib import Path
import shutil
import subprocess

import fire
from loguru import logger
import pandas as pd


class Clone:
    """
    参见 all 的文档
    clone.py all online_V05 online_V06  /home/xiaoyang/repos/online3rd_projects/V05 /home/xiaoyang/repos/online3rd_projects/V06
    """
    def clone_git(self, source, target, force=False):
        if target.exists():
            if force:
                logger.warning("强行删文件了")
                shutil.rmtree(target)
            else:
                logger.info(f"项目已经存在，跳过clone {target}")
                return

        target, source = Path(target), Path(source)
        target = target.expanduser().absolute()
        target.parent.mkdir(exist_ok=True, parents=True)
        subprocess.run(rf'git clone {source} {target}', shell=True)
        shutil.copy(source / ".git" / "config", target / ".git" / "config")

    def clone_libs(self, source: str, target: str, force=False):
        target, source = Path(target), Path(source)
        tlib = target / "libs"
        tlib.mkdir(exist_ok=True)
        # We assume the files are managed by git
        for fpath in source.glob("libs/*/"):
            self.clone_git(fpath, tlib / fpath.name)

    def clone_env(self, s_env: str, t_env: str, target: str):
        """
        python scripts/deploy/clone.py clone_env online online_V01 /home/xiaoyang/repos/online3rd_projects/V01/

        Parameters
        ----------
        s_env : str
            the name of source environment
        t_env : str
            the name of target environment
        target : str
            Clone the environment for `target` environment
        """
        subprocess.run(f'conda create --name {t_env} --clone {s_env}', shell=True)

        target = Path(target)

        res = subprocess.check_output('conda env list', shell=True)
        conda_env = pd.read_csv(StringIO(res.decode().replace("*", "")),
                                comment="#",
                                names=["name", "path"],
                                sep=r'\s+',
                                index_col="name")
        python_path = f"{conda_env.loc[t_env].item()}/bin/python"

        subprocess.run(f'{python_path} setup.py develop', shell=True, cwd=target)
        for fpath in target.glob("libs/*/setup.py"):
            subprocess.run(f'{python_path} setup.py develop', shell=True, cwd=fpath.parent)

    def clone_project(self, source: str, target: str, force=False):
        """
        clone the project

        python scripts/deploy/clone.py clone_project /home/xiaoyang/repos/online3rd/ /home/xiaoyang/repos/online3rd_projects/V01/  --force

        Parameters
        ----------
        source : str
            The source path of the project
        target : str
            The target path of the project
        """
        source, target = Path(source), Path(target)
        self.clone_git(source, target, force=force)

        shutil.copy(source / "config.yaml", target / "config.yaml")

        # 把数据 link过来 (这里假设数据是共享的)
        for fname in ["data"]:
            fpath = source / fname
            if fpath.exists():
                os.symlink(fpath, target / fname)

        # 把子project也link过来
        self.clone_libs(source, target)

    def all(self, s_env: str, t_env: str, source: str, target: str, force: bool=False):
        """
        -clone这个参数后面的不仅可以是环境的名字，也可以是环境的路径。
        所以，用这种方法我们就可以实现跨用户匹配，命令的具体格式为：
        conda create -n  your_env_name --clone ~/path

        具体到clone.py这个脚本，克隆环境的代码为
        subprocess.run(f'conda create --name {t_env} --clone {s_env}', shell=True)
        我们只需要把s_env这个参数改为conda环境的路径即可，故命令为：
        python ./clone.py all /home/xiaoyang/miniconda3/envs/online_V02/ your_env_name /home/xiaoyang/repos/online3rd_projects/V02 /home/shared_user/v-jiangwu/conda_project/ --force

        在非server01的服务器上跑server01的项目，由于磁盘挂载在server本地，故其他机器是链接到磁盘上的。在import项目代码中的模块时，需要使用scripts/deploy/reinstall.sh
        在非server01的机器上运行脚本，将磁盘上的相应模块挂载在server01的模块在本地重新安装即可。

        Parameters
        ----------
        s_env : str
            source environment, 可以是conda 名称也可以是路径地址
        t_env : str
            目标环境
        source : str
            源项目路径
        target : str
            目标项目路径
        force : bool
            please reference to the docs of clone_project
        """
        self.clone_project(source, target, force)
        self.clone_env(s_env, t_env, target)
        logger.info("接下来可能要做的事情: 修改config")
        logger.info("在非server01的服务器上跑server01的项目，可能会出现问题，见注释")


if __name__ == "__main__":
    fire.Fire(Clone)
