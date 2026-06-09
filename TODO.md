# Introduction
这里会记录一些还未自动化的部署步骤


## jumbo

vim插件安装
- `sudo ln -s ~/.dein.vim/repos/github.com/Valloric/YouCompleteMe/third_party/ycmd/ycm_core.so  /root/.jumbo/lib/python2.7/site-packages`
- `sudo ln -s ~/.dein.vim/repos/github.com/Valloric/YouCompleteMe/third_party/ycmd/libclang.so.*  /root/.jumbo/lib/python2.7/site-packages`
- 安装GLIBC\_ ， 才能正常使用编译后的 clang支持， 最后卡在了无法安装新版的 glibc上。

## tmux

状态栏点击在手机端不生效
- 现象：`status-right` 里类似 `状态栏修复 󰂚 ○` 的区域已经被包到 `range=user|sb_a`，桌面端点击可以触发等价 `prefix+a` 的 auto-switch；但手机端点击状态栏没有任何效果。
- 相关改动：`configs/tmux/script/refresh_status_right.sh` 把当前窗口提示、小铃铛和 auto-switch 圆圈包成同一个 `sb_a` 点击区；`configs/tmux/tmux.conf` 的 `MouseDown1Status` 会把 `sb_*` / `right` range 交给 `handle_status_button.sh`。
- 待排查：手机终端/tmux client 是否发送 `MouseDown1Status`，是否支持 `mouse_status_range`，以及触摸事件是否被终端吞掉或只映射为 pane 点击。需要在手机端临时记录 `#{mouse_status_range}` / `#{mouse_x}` / `#{client_termname}` 后再决定兼容方案。
