#!/bin/sh
set -x  # show command
set -e  # Error on exception

sudo apt-get install -y nginx apache2-utils

# https://stackoverflow.com/a/34531699
folder=$HOME/data/ftp/
user=$USER
while getopts ":f:u:" opt; do
    case $opt in
        f)
        echo "-f was triggered, Parameter: $OPTARG" >&2
        folder=$OPTARG
        ;;
        u)
        echo "-f was triggered, Parameter: $OPTARG" >&2
        user=$OPTARG
        ;;
        \?)
        echo "Invalid option: -$OPTARG" >&2
        exit 1
        ;;
        :)
        echo "Option -$OPTARG requires an argument." >&2
        exit 1
        ;;
    esac
done

sudo touch /etc/nginx/sites-available/http_files

sudo chown -R $USER:$USER /etc/nginx/sites-available/http_files

port=2121

cat << EOF > /etc/nginx/sites-available/http_files
server {
	listen $port default_server;
	listen [::]:$port default_server;

	root ${folder};

	server_name _;
  auth_basic "Private Property";
  auth_basic_user_file /etc/nginx/.htpasswd_file;
  expires -1;

	location / {
		# First attempt to serve request as file, then
		# as directory, then fall back to displaying a 404.
		try_files \$uri \$uri/ =404;
    autoindex on;  # Enable directory listing
	}
}
EOF

sudo ln -s /etc/nginx/sites-available/http_files /etc/nginx/sites-enabled/http_files

sudo htpasswd -c /etc/nginx/.htpasswd_file $user
# need input password

sudo service nginx restart
