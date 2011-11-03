#!/usr/local/bin/perl
# Save virtual host access control

use strict;
use warnings;
require 'virtualmin-nginx-lib.pl';
our (%text, %in);
&lock_all_config_files();
&error_setup($text{'access_err'});
&ReadParse();
my $server = &find_server($in{'id'});
$server || &error($text{'server_egone'});

&nginx_access_parse("allow", "deny", $server);

&flush_config_file_lines();
&unlock_all_config_files();
my $name = &find_value("server_name", $server);
&webmin_log("access", "server", $name);
&redirect("edit_server.cgi?id=".&urlize($in{'id'}));

