# Introduction
这里会记录一些还未自动化的部署步骤


## jumbo

vim插件安装
- `sudo ln -s ~/.dein.vim/repos/github.com/Valloric/YouCompleteMe/third_party/ycmd/ycm_core.so  /root/.jumbo/lib/python2.7/site-packages`
- `sudo ln -s ~/.dein.vim/repos/github.com/Valloric/YouCompleteMe/third_party/ycmd/libclang.so.*  /root/.jumbo/lib/python2.7/site-packages`
- 安装GLIBC\_ ， 才能正常使用编译后的 clang支持， 最后卡在了无法安装新版的 glibc上。
