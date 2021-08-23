import subprocess
from pathlib import Path


def run(cmd, output=False):
    print(cmd)
    if output:
        return subprocess.check_output(cmd, shell=True).decode()
    else:
        return subprocess.call(cmd, shell=True)


conda_path = Path(run("which python", output=True))

run("wget http://legionfonts.com/download/simhei -O /tmp/simhei.zip")
run("unzip -d  /tmp/ /tmp/simhei.zip")
for p in conda_path.parent.parent.glob("lib/*/site-packages/matplotlib/mpl-data/fonts/ttf"):
    run(f"cp /tmp/SimHei.ttf {p}")
run("rm /tmp/simhei.zip /tmp/SimHei.ttf")

# 还得删除缓存：https://www.zhihu.com/question/25404709/answer/309784195
# 这个缓存是用户相关的，只会影响自己的用户
try:
    from matplotlib.font_manager import _rebuild

    _rebuild()
except ImportError:
    # 新版的接口改了
    from matplotlib.font_manager import _load_fontmanager

    _load_fontmanager(try_read_cache=False)


## 使用
# 在代码中需要用下面的方式指定字体
# plt.rcParams['font.sans-serif'] = 'SimHei'
# plt.rcParams['axes.unicode_minus'] = False
