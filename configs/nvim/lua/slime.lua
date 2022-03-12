--  现在在下面的情况下还有BUG
--  - 在调用了 float window之后 (比如fzf)，可能这个 last_channel 会变化 (我怀疑 fzf 开了一个terminal来显示内容， 导致 slime_last_channel被修改)
--      - 如果调用的是 telescope 就不会有这个问题
--      - 但是这个 last_channel 不是我下面这段代码改变的; 
--      - 所以是 vim_slime 本身的脚本改动的
--  - 解决方案:
--      - 把我的变量改成 slime_last_toggleterm_channel 不依赖 slime本身的变量
--      - 把 WinEnter,TermOpen 这几个 autocmd 也加上， 
--          - 我感觉: windows之间的切换不会算到 BufEnter里面, 第一次打开 terminal时好像不会正常拿到 &channel 号...


local M = {}

function M.reset_slime()
    if vim.api.nvim_get_var("slime_target") == "neovim" then
        if vim.o.filetype == "toggleterm" then
            vim.api.nvim_set_var("slime_last_toggleterm_channel", vim.o.channel)
        else
            local ok, last_channel = pcall(vim.api.nvim_get_var, "slime_last_toggleterm_channel")
            if ok then
                vim.api.nvim_buf_set_var(0, "slime_config", {jobid=last_channel})
            end
        end
    end
end

return M
