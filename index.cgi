#!/usr/local/bin/perl
# Show Nginx virtual hosts and global config

use strict;
use warnings;
require 'virtualmin-nginx-lib.pl';
my $ver = &get_nginx_version();
our (%text, %module_info, %config, $module_name);

&ui_print_header($ver ? &text('index_version', $ver) : undef,
		 $module_info{'desc'}, "", undef, 1, 1);

# Check config
if (!-r $config{'nginx_config'}) {
	&ui_print_endpage(
		&text('index_econfig', "<tt>$config{'nginx_config'}</tt>",
		"../config.cgi?$module_name"));
	}
if (!&has_command($config{'nginx_cmd'})) {
	&ui_print_endpage(
		&text('index_ecmd', "<tt>$config{'nginx_cmd'}</tt>",
		"../config.cgi?$module_name"));
	}

# Show icons for global config types
my $conf = &get_config();

# Show list of virtual hosts
# XXX

&ui_print_footer("/", $text{'index'});
