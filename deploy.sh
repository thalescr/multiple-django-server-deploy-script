#!/bin/bash

# Check if user is root
if (($EUID != 0)); then
  echo "Please run this script as root."
  exit
fi

# Check positional parameters
if (($# != 3)); then
  echo "Usage: ./deploy.sh [SITE_NAME] [DOMAIN] [USER]"
  exit
fi

# Check if user exists
if ! id "$3" &>/dev/null; then
    echo "User $3 not found!"
    exit
fi

# Setting up variables
site_name=$1
domain=$2
user_name=$3
current_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Get wsgi.py file location
wsgi_dir=$( dirname $( find $current_dir -name wsgi.py | tail -1 ) )

# If wsgi.py was not found
if [ -z "$wsgi_dir" ]; then
    echo "Could not find wsgi.py"
    exit
fi

# Otherwise get its relative path and switch "/" chars to "."
wsgi=$( echo ${wsgi_dir#"$current_dir/"} | tr "/" "." )

# Define file paths
sock_path="$current_dir/$site_name.sock"
venv_path="$current_dir/venv"

# Check python version
python_version=$(python3 --version 2>&1 | grep -Po '(?<=Python )(.+)')
if [[ "$python_version" < "3.7.0" ]]; then
    echo "Missing python version at least 3.7 Check the command 'python3 --version'"
    exit
fi

# Check pip version
pip_version=$(pip3 --version 2>&1 | grep -Po '(?<=pip )(.+)' | cut -f1 -d" ")
if [[ "$pip_version" < "19.0.0" ]]; then
    echo "Missing pip version at least 19.0.0 Check the command 'pip3 --version'"
    exit
fi

# Create virtual environment and install requirements
python3 -m venv venv
source venv/bin/activate
pip3 install -r requirements.txt
pip3 install gunicorn

# Collect static data and migrate the database (just in case)
python3 manage.py collectstatic
python3 manage.py migrate

# Generate gunicorn socket file
cat > /etc/systemd/system/$site_name.gunicorn.socket <<EOF
[Unit]
Description=gunicorn socket

[Socket]
ListenStream=$sock_path

[Install]
WantedBy=sockets.target
EOF

# Generate gunicorn service file
cat > /etc/systemd/system/$site_name.gunicorn.service <<EOF
[Unit]
Description=gunicorn daemon
After=network.target

[Service]
User=$user_name
Group=www-data
WorkingDirectory=$current_path
ExecStart=$venv_path/bin/gunicorn --access-logfile - --workers 3 --bind unix:$sock_path $wsgi.wsgi:application

[Install]
WantedBy=multi-user.target
EOF

# Start and enable gunicorn socket and service
systemctl start $site_name.gunicorn.socket
systemctl enable $site_name.gunicorn.socket
systemctl start $site_name.gunicorn.service
systemctl enable $site_name.gunicorn.socket

# Generate nginx config file
cat > /etc/nginx/sites-available/$site_name <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name $domain;

    location = /favicon.ico { access_log off; log_not_found off; }
    location /static/ {
        root $current_dir;
    }

    location / {
        include proxy_params;
        proxy_pass http://unix:$sock_path;
    }
}
EOF

# Link nginx config file and reload it
ln -s /etc/nginx/sites-available/$site_name /etc/nginx/sites-enabled/
systemctl reload nginx

echo "Successfully deployed $site_name!"
