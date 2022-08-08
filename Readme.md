# Notes:
- due to the force with snapd no firefox works under version 22.04 firefox works with earlier versions (20.04 and older).

- audio and possibly copy and paste may no longer be possible due to the conversion of the Dockerfile.

## Ubuntu from 18.04 to 22.04 (only LTS Versions)  Multi User Remote Desktop Server

Fully implemented Multi User xrdp
with xorgxrdp and pulseaudio
on Ubuntu from 18.04 to 22.04
Copy/Paste and sound is working.
Users can re-login in the same session.
Xfce4, Firefox are pre installed.

# Tags

danielguerra/ubuntu-xrdp:18.04  or latest
danielguerra/ubuntu-xrdp:20.04

## Usage

Start the rdp server
(WARNING: use the --shm-size 1g or firefox/chrome will crash)

```bash
docker run -d --name uxrdp --hostname terminalserver --shm-size 1g -p 3389:3389 -p 2222:22 danielguerra/ubuntu-xrdp:latest
```
*note if you already use a rdp server on 3389 change -p <my-port>:3389
	  -p 2222:22 is for ssh access ( ssh -p 2222 ubuntu@<docker-ip> )

Connect with your remote desktop client to the docker server.
Use the Xorg session (leave as it is), user and pass.

## Creation of users

To automate the creation of users, supply a file users.list in the /etc directory of the container.
The format is as follows:

```bash
id username password-hash list-of-supplemental-groups
```

The provided users.list file will create a sample user with sudo rights

Username: ubuntu
Password: ubuntu

To generate the password hash use the following line

```bash
openssl passwd -1 'newpassword'
```

Run the xrdp container with your file

```bash
docker run -d -v $PWD/users.list:/etc/users.list
```

You can change your password in the rdp session in a terminal

```bash
passwd
```

## Add new users

No configuration is needed for new users just do

```bash
docker exec -ti uxrdp adduser mynewuser
```

After this the new user can login

## Add new services

To make sure all processes are working supervisor is installed.
The location for services to start is /etc/supervisor/conf.d

Example: Add mysql as a service

```bash
apt-get -yy install mysql-server
echo "[program:mysqld] \
command= /usr/sbin/mysqld \
user=mysql \
autorestart=true \
priority=100" > /etc/supervisor/conf.d/mysql.conf
supervisorctl update
```

## Volumes
This image uses two volumes:
1. `/etc/ssh/` holds the sshd host keys and config
2. `/home/` holds the `ubuntu/` default user home directory

When bind-mounting `/home/`, make sure it contains a folder `ubuntu/` with proper permission, otherwise no login will be possible.

```
mkdir -p ubuntu
chown 999:999 ubuntu
```

## Installing additional packages during build

The Dockerfile has support for the build argument ADDITIONAL_PACKAGES to install additional packages during build. Either pass it with `--build-arg` during `docker build` or add it 
as `args` in your `docker-compose.override.yml` and run `docker-compose build`.

## To run with docker-compose

```bash
git clone https://github.com/LizenzFass78851/ubuntu-xrdp.git
cd ubuntu-xrdp/
vi docker-compose.override.yml # if you want to override any default value
docker-compose up -d
```

## Build Image from Dockerfile

```
git clone https://github.com/LizenzFass78851/ubuntu-xrdp.git
cd ubuntu-xrdp/
docker build . --file Dockerfile --tag ubuntu-xrdp:20.04   # or the version that is built into the dockerfile as the ubuntu version
vi docker-compose.yml   # to change the settings and to use the locally built image, remove the word "danielguerra/" from the line beginning with "image: " and possibly change the tag ":latest" to the version number selected in the build command
docker-compose up -d
```
