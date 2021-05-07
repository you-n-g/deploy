#!/usr/bin/env python
"""
pip install -U memory_profiler
mprof attach -C <pid>
"""
import fire
import time
import subprocess
import numpy as np
import pandas as pd
from tqdm.auto import tqdm
from joblib import Parallel, delayed
from pathlib import Path


class Monitor:
    VS_FN = "vmstat.dat"
    MP_FN = "mprof.dat"

    def vs(self, fname=VS_FN):
        """
        写完之后才感觉不对:  free 得到到结果看内存更方便
        """
        bar = tqdm()
        while True:
            subprocess.run(f'vmstat -t >> {fname}', shell=True)
            bar.update(1)
            time.sleep(1)

    def mprof(self, pid, fname=MP_FN):
        # RES mprof 第二列是内存占用， 代表物理内存占用(我核对过相当于htop的RES列)， 单位是 MB,
        subprocess.run(f'mprof attach -o {fname} -C {pid}', shell=True)

    def all(self, pid=None):
        tasks = [delayed(self.vs)()]
        if pid is not None:
            tasks.append(delayed(self.mprof)(pid=pid))
        try:
            Parallel(n_jobs=2)(tasks)
        except KeyboardInterrupt:
            pass

    def clear(self):
        for fname in self.VS_FN, self.MP_FN:
            path = Path(fname)
            if path.exists():
                path.unlink()

    def anas(self, fname=VS_FN):
        """
        analysis result of system
        """
        data = pd.read_csv(fname)

        data.head()
        data.shape
        fi = Path(fname)
        with fi.open("r") as f:
            lines = f.readlines()

        df = []
        for idx in range(0, len(lines), 3):
            data = lines[idx + 2].split()
            idx = lines[idx + 1].split()
            if idx[-1] == "UTC":
                data[-2:] = [" ".join(data[-2:])]
            sr = pd.Series(data, idx)
            df.append(sr)
        df = pd.DataFrame(df)

        df['UTC'] = df['UTC'].apply(pd.to_datetime)

        df.set_index("UTC", inplace=True)
        df = df.astype(np.int)

        print((df["free"] / 2**20).describe())
        return df

    def anap(self, fname=MP_FN):
        data = pd.read_csv(fname, sep=" ", index_col=2, names=["col", "memory", "time"], skiprows=1)
        print(data["memory"].astype("float").describe())


if __name__ == "__main__":
    fire.Fire(Monitor)
