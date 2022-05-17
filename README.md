# dir-backupper
Script to make single directory backups of your data to remote target. Requires bash, rsync on both ends and ssh key login without password to remote end. Must be executed as root.

## Setup
* Prerequisites

Make sure you have **bash**, **rsync** installed on source and destination servers.

* Install
```
git clone https://github.com/aretaja/dir-backupper
cd dir-backupper
sudo ./install.sh
```

* Config

Config file location defaults to `/usr/local/etc/dir-backupper.conf`. Look at provided example config file.

## Usage
* Help
```
sudo dir-backupper.sh -h

Make daily, weekly, monthly single directory backups.
Creates monthly backup on every 1 day of month in remeote
'monthly' directory, weekly on every 1 day of week in
'weekly' directory and every other day in 'daily' directory.
Only latest backup will preserved in every directory.
Requires config file. Default: /usr/local/etc/dir-backupper.conf
Script must be executed by root.

Usage:
       dir-backupper.sh dir-backupper.conf
```

* Setup cron job for backup (Append to */etc/crontab*)
```
# Directory backup
55 1    * * *   root    /usr/local/bin/dir-backupper.sh >>/var/log/dir-backupper.log 2>&1
```
