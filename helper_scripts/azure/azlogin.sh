#!/bin/sh

export BROWSER=browser.sh

cat <<EOF > browser.sh
#!/bin/sh
echo "$@" >  ./browser.log
EOF
chmod +x browser.sh

az login &
# it will start a local http server; and embed the callback authentication url in the browser accessing url.

sleep 1

cat browser.log


# access the url in your authenticated device.
# it will redirect you to the authentication page. Copy it and curl on the server to finish az login.
