#!/bin/bash

echo "    ___           _  ______      _   _            "
echo "   |_  |         | | | ___ \    | | | |           "
echo "     | |_   _ ___| |_| |_/ / ___| |_| |_ ___ _ __ "
echo "     | | | | / __| __| ___ \/ _ \ __| __/ _ \ '__|"
echo " /\__/ / |_| \__ \ |_| |_/ /  __/ |_| ||  __/ |   "
echo " \____/ \____|___/\__\____/ \___|\__|\__\___|_|   "
echo "                                                 "
echo "                                                 "
echo "Netdata Configuration Script"

if [[ -n "$1" ]]; then
    slack_url="$1"
else
    read -p "Please enter the Slack webhook URL: " slack_url
fi

tmp_dir="/tmp/netdata_install"

# Gather latest configuration files
rm -rf "$tmp_dir"
mkdir "$tmp_dir"
git clone -n --depth=1 --filter=tree:0 https://github.com/justbetter/serverconfigs.git "$tmp_dir"
cd "$tmp_dir"
git sparse-checkout set --no-cone netdata
git checkout

# Setup the config

directories=("/etc/netdata" "/opt/netdata/etc/netdata" $2)

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

cp -r "$tmp_dir/netdata/health.d" $config_dir
cp -r "$tmp_dir/netdata/go.d" $config_dir

rm -rf "$tmp_dir"

cp /usr/lib/netdata/conf.d/health_alarm_notify.conf "$config_dir"

# Set Slack
if [ -n "$slack_url" ]; then
    echo "Setting Slack webhook"
    sed -i '' "s|SLACK_WEBHOOK_URL=.*|SLACK_WEBHOOK_URL=\"$slack_url\"|" "$config_dir/health_alarm_notify.conf"
    sed -i '' "s|SEND_SLACK=.*|SEND_SLACK=YES|" "$config_dir/health_alarm_notify.conf"
    sed -i '' "s|DEFAULT_RECIPIENT_SLACK=.*|DEFAULT_RECIPIENT_SLACK=\"#netdata\"|" "$config_dir/health_alarm_notify.conf"
fi


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
