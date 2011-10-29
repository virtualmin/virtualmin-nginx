#!/usr/local/bin/perl
# Save global server-side include settings

use strict;
use warnings;
require 'virtualmin-nginx-lib.pl';
our (%text);
&lock_all_config_files();
my $parent = &get_config_parent();
my $http = &find("http", $parent);
&error_setup($text{'misc_err'});
&ReadParse();

&nginx_onoff_parse("ssi", $http);

&nginx_onoff_parse("ssi_silent_errors", $http);

&nginx_opt_list_parse("ssi_types", $http, undef,
		      '^[a-zA-Z0-9\.\_\-]+\/[a-zA-Z0-9\.\_\-]+$');

&nginx_opt_parse("ssi_value_length", $http, undef, '^\d+$');

&flush_config_file_lines();
&unlock_all_config_files();
&webmin_log("ssi");
&redirect("");

