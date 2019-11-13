#!/bin/bash
set -x

git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm

if ! grep 'plugins\/tpm' ~/.tmux.conf ; then
    cat >> ~/.tmux.conf <<EOF

# List of plugins
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-sensible'

# Other examples:
# set -g @plugin 'github_username/plugin_name'
# set -g @plugin 'git@github.com/user/plugin'
# set -g @plugin 'git@bitbucket.com/user/plugin'
set -g @plugin 'tmux-plugins/tmux-resurrect'

# Initialize TMUX plugin manager (keep this line at the very bottom of tmux.conf)
run -b '~/.tmux/plugins/tpm/tpm'
EOF
fi

# TODO: I have to do this manually now
# Hit prefix + I to fetch the plugin and source it. You should now be able to use the plugin.
