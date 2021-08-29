#!/usr/bin/env python
import pstats
import fire
import warnings


def show(path="stats_out"):
    warnings.warn("snakeviz is strongly recommended to replace this script")
    p = pstats.Stats(path)  # 再重新统计输出了
    print(p.strip_dirs().sort_stats("cumtime").print_stats(100))


if __name__ == "__main__":
    fire.Fire(show)
