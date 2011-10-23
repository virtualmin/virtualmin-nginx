#!/usr/local/bin/perl
# Save virtual host logging options

use strict;
use warnings;
require 'virtualmin-nginx-lib.pl';
our (%text, %in);
&lock_all_config_files();
&error_setup($text{'slogs_err'});
&ReadParse();
my $server = &find_server($in{'id'});
$server || &error($text{'server_egone'});

&nginx_error_log_parse("error_log", $server);

&nginx_access_log_parse("access_log", $server);

&flush_config_file_lines();
&unlock_all_config_files();
my $name = &find_value("server_name", $server);
&webmin_log("slogs", "server", $name);
&redirect("edit_server.cgi?id=".&urlize($in{'id'}));

