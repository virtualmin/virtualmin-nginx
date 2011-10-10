#!/usr/local/bin/perl
# Save networking-related options

use strict;
use warnings;
require 'virtualmin-nginx-lib.pl';
our (%text);
my $conf = &get_config();
my $http = &find("http", $conf);
&error_setup($text{'net_err'});
&ReadParse();

&lock_all_config_files();

&nginx_onoff_parse("sendfile", $http);

&nginx_onoff_parse("gzip", $http);

&nginx_opt_parse("keepalive_timeout", $http, undef, '\d+');

&flush_config_file_lines();
&unlock_all_config_files();
&webmin_log("net");
&redirect("");

