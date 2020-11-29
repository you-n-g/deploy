#!/bin/bash

# The solution comes from   https://stackoverflow.com/a/20844506

mkdir -p ~/bin/

wget 'https://raw.githubusercontent.com/toobaz/ipynb_output_filter/master/ipynb_output_filter.py' -O ~/bin/ipynb_output_filter.py
chmod a+x ~/bin/ipynb_output_filter.py

if ! grep "MY_CONFIG" ~/bin/ipynb_output_filter.py ; then
    sed -i '/if "metadata" in cell:/a \ \ \ \ \ \ \ \ \ \ \ \ if "tags" in cell.metadata and  "MY_CONFIG" in cell.metadata["tags"]:\n                cell.source = ["# Please write your personal config here, it will not be uploaded to the repo."]' ~/bin/ipynb_output_filter.py
fi

cat > ~/.gitattributes << EOF
*.ipynb    filter=dropoutput_ipynb
EOF

while getopts "a" opt; do
    case $opt in
        a)
        git config --global core.attributesfile ~/.gitattributes
        git config --global filter.dropoutput_ipynb.clean ~/bin/ipynb_output_filter.py
        git config --global filter.dropoutput_ipynb.smudge cat
        exit 0
        ;;
        \?)
        echo "Invalid option: -$OPTARG" >&2
        exit 1
        ;;
    esac
done
