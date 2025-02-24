## virtualmin-nginx

Virtualmin plugin to use the nginx web server instead of Apache.

### Installation

The recommended way to install Virtualmin is to use the `virtualmin-install.sh`
automated install script, found on the [download page](https://www.virtualmin.com/download)
of Virtualmin.com. To get the LEMP stack, which includes nginx instead of 
Apache, use the `-b LEMP` option when installing. The install script should be
run on a freshly installed supported OS, with no preconfiguration or third party
repositories enabled.

```
# /bin/sh virtualmin-install.sh -b LEMP
```

The `LEMP` stack installs Virtualmin with the nginx and nginx-ssl plugins, nginx,
BIND, Postfix, MariaDB, PHP, etc. and sets them up for use in a shared virtual hosting
environment. The `--minimal` flag also works with a `LEMP` installation.

### OS Support

We support this plugin on the same [operating systems as Virtualmin itself](https://www.virtualmin.com/docs/os-support/).

### Contributing Translations

If you'd like to help improve `virtualmin-nginx` translations, please see our [translation contribution guide](https://www.virtualmin.com/docs/development/translations/).

The following languages are currently supported for `virtualmin-nginx`:

| Language | Human | Machine | Missing | Coverage (Human vs. Total) |
|----------|-------|---------|---------|----------------------------|
| cs       | 0     | 465     | 1       |   0.0%   /   99.8%         |
| de       | 0     | 466     | 0       |   0.0%   /  100.0%         |
| en       | 466   | 0       | 0       |   100.0% /  100.0%         |
| es       | 0     | 466     | 0       |   0.0%   /  100.0%         |
| fr       | 0     | 466     | 0       |   0.0%   /  100.0%         |
| it       | 0     | 465     | 1       |   0.0%   /   99.8%         |
| ja       | 0     | 465     | 1       |   0.0%   /   99.8%         |
| nl       | 440   | 25      | 1       |  94.4%   /   99.8%         |
| no       | 0     | 465     | 1       |   0.0%   /   99.8%         |
| pl       | 0     | 465     | 1       |   0.0%   /   99.8%         |
| pt_BR    | 0     | 465     | 1       |   0.0%   /   99.8%         |
| ru       | 0     | 466     | 0       |   0.0%   /  100.0%         |
| sk       | 0     | 465     | 1       |   0.0%   /   99.8%         |
| tr       | 0     | 465     | 1       |   0.0%   /   99.8%         |
| zh       | 0     | 466     | 0       |   0.0%   /  100.0%         |
| zh_TW    | 0     | 466     | 0       |   0.0%   /  100.0%         |
