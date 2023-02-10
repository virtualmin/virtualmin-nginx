# virtualmin-nginx

Virtualmin plugin to use the nginx web server instead of Apache.

# Installation

The recommended way to install Virtualmin is to use the `virtualmin-install.sh`
automated install script, found on the [Download page](https://www.virtualmin.com/download)
of Virtualmin.com. To get the LEMP stack, which includes nginx instead of 
Apache, use the `-b LEMP` option when installing.

```
# /bin/sh virtualmin-install.sh -b LEMP
```

If you won't be processing mail on the system, or the system is small (<1.5GB RAM)
you will likely want to use the `--minimal` option as well, which excludes some
of the more resource-intensive parts of the mail stack, and some other optional
packages.

The install script uses your OS native package manager to install all software,
including our packages.

The `LEMP` stack installs Virtualmin with the nginx and nginx-ssl plugsin, nginx,
BIND, Postfix, MariaDB, PHP, etc. and sets them up for use in a shared virtual hosting
environment.

# OS Support

We support this plugin on the same [operating systems as Virtualmin itself](https://www.virtualmin.com/documentation/os-support/).
