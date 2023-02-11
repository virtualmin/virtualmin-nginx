# virtualmin-nginx

Virtualmin plugin to use the nginx web server instead of Apache.

# Installation

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

# OS Support

We support this plugin on the same [operating systems as Virtualmin itself](https://www.virtualmin.com/documentation/os-support/).
