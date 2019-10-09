from matplotlib.font_manager import _rebuild
import subprocess
from pathlib import Path


def run(cmd, output=False):
    print(cmd)
    if output:
        return subprocess.check_output(cmd, shell=True).decode()
    else:
        return subprocess.call(cmd, shell=True)


conda_path = Path(run("which python", output=True))

run('wget http://legionfonts.com/download/simhei -O /tmp/simhei.zip')
run('unzip -d  /tmp/ /tmp/simhei.zip')
for p in conda_path.parent.parent.glob('lib/*/site-packages/matplotlib/mpl-data/fonts/ttf'):
    run(f'cp /tmp/SimHei.ttf {p}')
run('rm /tmp/simhei.zip /tmp/SimHei.ttf')

_rebuild()
