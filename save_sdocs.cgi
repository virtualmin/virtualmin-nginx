#!/usr/local/bin/perl
# Save document options

use strict;
use warnings;
require 'virtualmin-nginx-lib.pl';
our (%text, %in);
&lock_all_config_files();
&error_setup($text{'sdocs_err'});
&ReadParse();
my $server = &find_server($in{'id'});
$server || &error($text{'server_egone'});

&nginx_opt_parse("index", $server, undef);

&nginx_opt_parse("default_type", $server, undef,
		 '^[a-zA-Z0-9\.\_\-]+\/[a-zA-Z0-9\.\_\-]+$');

&flush_config_file_lines();
&unlock_all_config_files();
my $name = &find_value("server_name", $server);
&webmin_log("sdocs", "server", $name);
&redirect("edit_server.cgi?id=".&urlize($in{'id'}));

