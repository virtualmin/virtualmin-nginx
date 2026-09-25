# Nginx regression tests

The shared parser and locking tests live in Webmin's `nginx/t/config-locks.t`. Run them from the Webmin checkout with `prove nginx/t/config-locks.t nginx/t/server-files.t`.

The tests below require a disposable Linux VM with the updated Webmin Nginx module and both Virtualmin Nginx plugins installed. They skip unless explicitly enabled.

```sh
VIRTUALMIN_NGINX_CONFIG_TEST=1 prove -v t/config-updates-vm.t
VIRTUALMIN_NGINX_CONCURRENT_TEST=1 prove -v t/concurrent-domains-vm.t
```

`config-updates-vm.t` exercises the installed parser and plugin functions against a temporary configuration. Another process shifts server blocks before each edit. Certificate generation and service actions are stubbed.

It also checks that domain renames preserve active and rotated logs, including when the active log is missing or the home directory has already moved.

`concurrent-domains-vm.t` creates four domains in two pairs, starting each pair one second apart. It checks Nginx configuration, IPv4/IPv6 SSL listeners, domain validation, and static files and PHP over HTTP/HTTPS. The VM's default features must include Nginx, SSL and PHP-FPM, and Nginx must be running when the test starts. Creation emails and ACME requests are disabled. Domains and fixture credentials are removed afterward; command logs remain in the printed temporary directory.

Set `VIRTUALMIN_NGINX_CREATE_CGI=1` as well to create the domains through the real `domain_setup.cgi` form via `create-domain-cgi.pl` instead of the CLI. That mode saves a temporary template with emails and ACME disabled and deletes it afterward.
