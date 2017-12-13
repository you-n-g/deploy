#!/bin/bash

# The solution comes from   https://stackoverflow.com/a/20844506

mkdir -p ~/bin/

wget 'https://raw.githubusercontent.com/toobaz/ipynb_output_filter/master/ipynb_output_filter.py' -O ~/bin/ipynb_output_filter.py
chmod a+x ~/bin/ipynb_output_filter.py

cat > ~/.gitattributes << EOF
*.ipynb    filter=dropoutput_ipynb
EOF

git config --global core.attributesfile ~/.gitattributes
git config --global filter.dropoutput_ipynb.clean ~/bin/ipynb_output_filter.py
git config --global filter.dropoutput_ipynb.smudge cat
