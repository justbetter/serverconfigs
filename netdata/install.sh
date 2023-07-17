#!/bin/bash

echo "    ___           _  ______      _   _            "
echo "   |_  |         | | | ___ \    | | | |           "
echo "     | |_   _ ___| |_| |_/ / ___| |_| |_ ___ _ __ "
echo "     | | | | / __| __| ___ \/ _ \ __| __/ _ \ '__|"
echo " /\__/ / |_| \__ \ |_| |_/ /  __/ |_| ||  __/ |   "
echo " \____/ \____|___/\__\____/ \___|\__|\__\___|_|   "
echo "                                                 "
echo "                                                 "
echo "Netdata Install Script"

if [ "$(id -u)" -ne 0 ]; then
        echo 'This script must be run by root' >&2
        exit 1
fi

if [[ -n "$1" ]]; then
    wget_command="$1"
else
    read -p "Please enter the wget install command for Netdata: " wget_command
fi

if [[ -n "$2" ]]; then
    slack_url="$2"
else
    read -p "Please enter the Slack URL: " slack_url
fi

# Install Netdata
eval "$wget_command"

# Setup the config

directories=("/etc/netdata" "/opt/netdata/etc/netdata" $3)

# Setup the config
config_dir=""

# Loop through the directories
for dir in "${directories[@]}"; do
    if [[ -d "$dir" ]]; then
        config_dir="$dir"
        break
    fi
done

# Check if a valid directory was found
if [[ -z "$config_dir" ]]; then
    echo "Config directory does not exist"
    exit
fi

echo "Using configuration directory $config_dir"

cp -r ./health.d $config_dir
cp -r ./go.d $config_dir


# Set Slack
if [ -n "$slack_url" ]; then
    echo "Setting Slack webhook"
    sed -i '' "s|SLACK_WEBHOOK_URL=.*|SLACK_WEBHOOK_URL=\"$slack_url\"|" "$config_dir/netdata.conf"
fi


# TODO Reload Netdata

echo "Netdata installation and configuration completed successfully!"

if command -v mysql &> /dev/null; then
    if mysql -u root -e "exit" &> /dev/null; then

        if ! mysql -u root -e "SELECT EXISTS(SELECT 1 FROM mysql.user WHERE user = 'netdata' AND host = 'localhost');" | grep -q '1'; then
            mysql -u root -e "CREATE USER 'netdata'@'localhost';"
            mysql -u root -e "GRANT USAGE, REPLICATION CLIENT, PROCESS ON *.* TO 'netdata'@'localhost';"
            mysql -u root -e "FLUSH PRIVILEGES;"
        else
            echo "Netdata MySQL user already exists, skipping"
        fi
    else
        read -p "Cannot access MySQL, create the Netdata user manually! Press any key to continue"
    fi
else
    echo "MySQL not installed"
fi


echo "Restarting Netdata"
service netdata restart
