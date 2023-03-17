#!/usr/bin/env python
"""
pip install -U memory_profiler
mprof attach -C <pid>
pip install py-spy

# NOTE: sudo is required for py-spy

# TODO:
# show values via plotext with streaming...
# - rich may be helpful (console live)
#    - https://github.com/Textualize/rich/discussions/1002 ,  感觉和 termplotlib 一起用成本会比较低
# - Termplot may be helpful
- pip install rich
- pip install termplotlib
- sudo apt-get install gnuplot


# 一个经典用法

CMD &
BACK_PID=$!
monitor.py all $BACK_PID &
MONI_PID=$!
wait $BACK_PID
kill $MONI_PID
"""
from datetime import datetime
import re
import os
import fire
import time
import psutil
import subprocess
import numpy as np
import pandas as pd
from tqdm.auto import tqdm
from joblib import Parallel, delayed
from threading import Thread
from pathlib import Path


class Monitor:
    VS_FN = "vmstat.dat"
    MP_FN = "mprof.dat"
    PD_FN = "pydump.dat"

    def vs(self, fname=VS_FN):
        """
        写完之后才感觉不对:  free 得到到结果看内存更方便
        """
        bar = tqdm()
        while True:
            subprocess.run(f"vmstat -t >> {fname}", shell=True)
            bar.update(1)
            time.sleep(1)

    def mprof(self, pid, fname=MP_FN):
        # RES mprof 第二列是内存占用， 代表物理内存占用(我核对过相当于htop的RES列)， 单位是 MB,
        subprocess.run(f"mprof attach -o {fname} -C {pid}", shell=True)

    def pydump(self, pid, fname=PD_FN):
        bar = tqdm()
        while True:
            with open(fname, "a") as f:
                f.write(f"Timestamp: {time.time()}\n")
            subprocess.run(f'sudo env "PATH=$PATH"  py-spy dump --pid {pid} >> {fname}', shell=True)
            bar.update(1)
            time.sleep(1)

    def all(self, pid=None):
        threads = [
            Thread(target=self.vs),
            Thread(target=self.mprof, args=(pid, )),
            Thread(target=self.pydump, args=(pid, ))
        ]
        for t in threads:
            t.start()

        for t in threads:
            t.join()

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

        TIME_COL = ["UTC", "CST"]  # 根据系统时区设置， 这里可能会不一样
        t_col_name = None
        df = []
        for idx in range(0, len(lines), 3):
            data = lines[idx + 2].split()
            idx = lines[idx + 1].split()
            if idx[-1] in TIME_COL:
                data[-2:] = [" ".join(data[-2:])]
                t_col_name = idx[-1]
            sr = pd.Series(data, idx)
            df.append(sr)
        df = pd.DataFrame(df)

        df[t_col_name] = df[t_col_name].apply(pd.to_datetime)

        df.set_index(t_col_name, inplace=True)
        df = df.astype(np.int)

        print((df["free"] / 2 ** 20).describe())  # the unit is GB
        return df

    def ana_pm(self, fname=MP_FN, print_desc=True, to_datetime=True):
        """Analysis python memory
        The unit is MB
        """
        data = pd.read_csv(fname, sep=" ", index_col=2, names=["col", "memory", "time"], skiprows=1)
        data = data[~data.index.isna()]  # 我遇到过算出index有NA的
        if to_datetime:
            data.index = data["memory"].index.to_series().apply(datetime.fromtimestamp)
        else:
            data.index = data["memory"].index.to_series().diff().fillna(0).cumsum()
        if print_desc:
            print(data["memory"].astype("float").describe())
        return data

    def ana_pd(self, fname=PD_FN):
        """Analysis python dump"""
        with open(fname) as f:
            lines = f.readlines()
        tss = []
        content = []
        for l in lines:
            m = re.match(r"Timestamp: (?P<time>.+)", l)
            if m is not None:
                tss.append(float(m.groupdict()["time"]))
                content.append([])
            else:
                content[-1].append(l)
        return pd.Series(map(lambda x: "".join(x), content), index=map(lambda ts: datetime.fromtimestamp(ts), tss))

    def m(self):
        # run monitor
        # in case of user have no rich
        from rich.layout import Layout
        from rich import print
        from rich.panel import Panel
        import termplotlib as tpl
        import numpy
        from rich.live import Live


        def get_info():
            data = self.ana_pm(print_desc=False, to_datetime=False)
            # x = numpy.linspace(0, 2 * numpy.pi, 10)
            # y = numpy.sin(x)
            #
            # fig = tpl.figure()
            # fig.plot(x, y, label="data", width=100, height=15)

            fig = tpl.figure()
            ma, mi =  data["memory"].max(), data["memory"].min()
            ra = ma - mi
            kwargs = {}
            if ra > 0:
                kwargs = {"ylim": (mi - ra * 0.1, ma + ra * 0.1)}
            size = os.get_terminal_size()
            # fig.plot(y=data["memory"], x=data.index, label="Mem(MB)", width=size[0] - 20, height=size[1] - 10, **kwargs)
            fig.plot(y=data["memory"], x=data.index, label="Mem(MB)", width=size[0] - 5, height=size[1], **kwargs)
            return fig.get_string(), data["memory"].iloc[-1]

        def get_panel():
            fig, latest = get_info()
            return Panel(fig, title=f'memory plot, latest={latest} MB')

        with Live(get_panel(), refresh_per_second=1, screen=True) as live:
            while True:
                live.update(get_panel())
                time.sleep(1)


if __name__ == "__main__":
    fire.Fire(Monitor)
