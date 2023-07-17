# JB Netdata Installation Script

This script installs and configures Netdata.


## Usage

Run the `install.sh` script, it will ask for the Netdata wget install command which you can find in Netdata Cloud.


### Run without interaction

You can run the `install.sh` script without interactions by providing the necessary arguments via the command line:

```sh
sh install.sh "<wget command>" "<Slack URL>"
```


## Additional configuration

Not all configuration can be done automatically, depending on the server a manual action may be required to enable a specific collector.

### PHP FPM

Unable to auto configure because of the different PHP versions.

This Netdata configuration listens to a few locations for FPM monitoring. See the `go.d/phpfpm.conf` for a list.

The quickest way to configure this is to enable the FPM status socket for your PHP version in `/tmp/fpm-status.sock`.
Configure it like this:

```
pm.status_path = /status
pm.status_listen = /tmp/fpm-status.sock
```

### MySQL

The script will attempt to configure a MySQL user for you, but if it is unable to do so you will get a notification.
In that case access MySQL as root and run the following statements:

```sql
CREATE USER 'netdata'@'localhost';
GRANT USAGE, REPLICATION CLIENT, PROCESS ON *.* TO 'netdata'@'localhost';
FLUSH PRIVILEGES;
```

This will create a `netdata` user so that Netdata can access MySQL.
