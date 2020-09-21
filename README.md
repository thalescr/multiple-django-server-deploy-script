# Multiple Django server deploy script

A script that automates deploying a Django website using Gunicorn and nginx in a shared environment.

## Requirements

- A linux environment with root privileges
- Nginx
- Python >= 3.7
- python-venv
- Pip >= 20.0

## Usage

Clone this repository inside your Django project folder. The project folder has to be inside your user folder (e.g. `/home/my-linux-user/`).

Ensure you have all requirements installed and updated in your system and run the following command:

```
./deploy.sh [SITE NAME] [DOMAIN] [USER]
```

```sh
./deploy.sh example example.com my-linux-user
```

## How the script works

It simply creates a virtual environment in your Django project folder, install all the requirements in file "requirements.txt" and also Gunicorn. Then it creates and enables 2 systemd service files: `your-site-name.gunicorn.service` and `your-site-name.gunicorn.socket`. The first one runs the Django server, and it requires the second one to be running, that is the gunicorn socket. After running the server, it creates a simple proxy redirect using Nginx and reloads Nginx service.
