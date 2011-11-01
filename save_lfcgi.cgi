#!/usr/local/bin/perl
# Save location FastCGI options

use strict;
use warnings;
require 'virtualmin-nginx-lib.pl';
our (%text, %in);
&lock_all_config_files();
&error_setup($text{'fcgi_err'});
&ReadParse();
my $server = &find_server($in{'id'});
$server || &error($text{'server_egone'});
my $location = &find_location($server, $in{'path'});
$location || &error($text{'location_egone'});

&nginx_opt_parse("fastcgi_pass", $location, undef,
		 '^[a-zA-Z0-9\.\_\-]+:[0-9]+$');

&nginx_opt_parse("fastcgi_index", $server, undef, '^\S+$');

&nginx_params_parse("fastcgi_param", $server);

&nginx_opt_parse("fastcgi_buffer_size", $server, undef, '^\d+[bkmgtp]?$');

&flush_config_file_lines();
&unlock_all_config_files();
my $name = &find_value("server_name", $server);
&webmin_log("lfcgi", "location", $location->{'words'}->[0], 
	    { 'server' => $name });
&redirect("edit_location.cgi?id=".&urlize($in{'id'}).
	  "&path=".&urlize($in{'path'}));

