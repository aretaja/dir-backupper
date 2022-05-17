#!/bin/bash
#
# dir-backupper.sh
# Copyright 2022 by Marko Punnar <marko[AT]aretaja.org>
# Version: 1.0.0
#
# Script to make single directory backup of your data to remote
# target. Requires bash, rsync on both ends and ssh key login without
# password to remote end. Must be executed as root.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>
#
# Changelog:
# 1.0.0 Initial release

# show help if requested
if [[ "$1" = '-h' ]] || [[ "$1" = '--help' ]]
then
    echo "Make daily, weekly, monthly single directory backups."
    echo "Creates monthly backup on every 1 day of month in remeote"
    echo "'monthly' directory, weekly on every 1 day of week in"
    echo "'weekly' directory and every other day in 'daily' directory."
    echo "Only latest backup will preserved in every directory."
    echo "Requires config file. Default: /usr/local/etc/dir-backupper.conf"
    echo "Script must be executed by root."
    echo ""
    echo "Usage:"
    echo "       dir-backupper.sh dir-backupper.conf"
    exit 1
fi

### Functions ###############################################################
# Output formater. Takes severity (ERROR, WARNING, INEO) as first
# and output message as second arg.
write_log()
{
    tstamp=$(date -Is)
    if [[ "$1" = 'INFO'  ]]
    then
        echo "$tstamp [$1] $2"
    else
       echo "$tstamp [$1] $2" 1>&2
    fi
}
#############################################################################
# Make sure we are root
if [[ "$EUID" -ne 0 ]]
then
   write_log ERROR "$0 must be executed as root! Interrupting.."
   exit 1
fi

# Define default values
cfile="/usr/local/etc/dir-backupper.conf"
lock_f="/var/run/dir-backupper.lock"
dport="22"

# Check for running backup (lockfile)
if [[ -e "$lock_f" ]]
then
    write_log ERROR "Previous backup is running (lockfile set). Interrupting.."
    exit 1
fi

# Load config
if [[ -r "$cfile" ]]
then
    # shellcheck source=./dir-backupper.conf_example
    . "$cfile"
else
     write_log ERROR "Config file missing! Interrupting.."
     exit 1
fi


# Check config
# shellcheck disable=SC1001
if [[ -z "$local_dir" ]] || [[ ! "$local_dir" =~ ^[[:alnum:]_\.\/-]+$ ]] || [[ ! -w "$local_dir" ]]
then
    write_log ERROR "Config - Local dir for backup missing or incorrect"
    exit 1
else
    # Change working dir
    cd "$local_dir"|| exit
    if [ "$PWD" != "$local_dir" ]
    then
        write_log ERROR "Wrong working dir - ${PWD}. Must be - ${local_dir}! Interrupting.."
        exit 1
    fi
fi

if [[ -z "$dhost" ]] || [[ ! "$dhost" =~ ^[[:alnum:]\.-]+$ ]]
then
    write_log ERROR "Config - Backup destination host missing or incorrect"
    exit 1
fi

if [[ -z "$dport" ]] || [[ ! "$dport" =~ ^[[:digit:]]+$ ]]
then
    write_log ERROR "Config - Backup destination ssh port missing or incorrect"
    exit 1
fi

if [[ -z "$duser" ]] || [[ ! "$duser" =~ ^[[:alnum:]_\.-]+$ ]]
then
    write_log ERROR "Config - Backup destination ssh user missing or incorrect"
    exit 1
fi

if [[ -z "$dpdir" ]] || [[ ! "$dpdir" =~ ^[[:alnum:]_\ \.-]+$ ]]
then
    write_log ERROR "Config - Backup destination preffix missing or incorrect"
    exit 1
fi

if [[ -z "$ddir" ]] || [[ ! "$ddir" =~ ^[[:alnum:]_\ \.-]+$ ]]
then
    write_log ERROR "Config - Backup destination basedir missing or incorrect"
    exit 1
fi

# Set remote directory name
target="daily"
day_of_month=$(date +%-d)
day_of_week=$(date +%u)

if [[ "$day_of_month" -eq 1 ]]
then
    target="monthly"
elif [[ "$day_of_week" -eq 1 ]]
then
    target="weekly"
fi
dir="${dpdir}_${target}"

# Set lockfile
touch "$lock_f";

# Connection check
# shellcheck disable=SC2029
if result=$(ssh -q -o BatchMode=yes -o ConnectTimeout=10 -l"$duser" -p"$dport" "$dhost" "cd \"$ddir\"" 2>&1)
then
    write_log INFO "$dhost connection test OK"
else
    if [[ -z "$result" ]]
    then
        write_log ERROR "$dhost is not reachable! Interrupting.."
    else
        write_log ERROR "$dhost returned \"${result}\"! Interrupting.."
    fi
    rm "$lock_f"
    exit 1
fi

# Do backup to remote server
write_log INFO "rsync - start backup to remote server: \"${duser}\"@${dhost}:\"${ddir}/${dir}\". Rsync log follows:"

cmd="rsync -aHAXh --delete --timeout=300 --stats --numeric-ids -M--fake-super -e 'ssh -o BatchMode=yes -p${dport}' \"${local_dir}/\" \"${duser}\"@${dhost}:\"${ddir}/${dir}\""

for (( i=1; i<=10; i++ ))
do
    eval "$cmd" 2>&1
    ret=$?
    if [[ "$ret" -eq 0 ]]; then break; fi
    write_log WARNING "rsync - got non zero exit code - $ret.! Retrying.."
    sleep 60
done
if [[ "$ret" -ne 0 ]]
then
    write_log ERROR "rsync - got non zero exit code - $ret. Giving up"
    rm "$lock_f"
    exit 1
fi

write_log INFO "Directory backup done"
rm "$lock_f"
exit 0
