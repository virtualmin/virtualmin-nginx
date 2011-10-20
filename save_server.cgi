#!/usr/local/bin/perl
# Create, update or delete a virtual host

use strict;
use warnings;
require 'virtualmin-nginx-lib.pl';
our (%text, %in);
&ReadParse();

# Get the current server
&lock_all_config_files();
my $conf = &get_config();
my $http = &find("http", $conf);
my $server;
if ($in{'new'}) {
	$server = { 'name' => 'server',
		    'type' => 1,
		    'members' => [ ] };
	}
else {
	$server = &find_server($in{'id'});
        $server || &error($text{'server_egone'});
        }

my $action;
if ($in{'delete'}) {
	if ($in{'confirm'}) {
		# Got confirmation, delete it
		# XXX
		$action = 'delete';
		}
	else {
		# Ask for confirmation first
		# XXX
		}
	}
else {
	if ($in{'new'}) {
		# Create a new server object
		&save_directive($http, [ ], [ $server ]);
		$action = 'create';
		}
	else {
		$action = 'modify';
		}

	# Validate and update existing directives
	&nginx_text_parse("server_name", $server, undef, '^\S+$');

	if ($in{'new'}) {
		# Add root directory block
		# XXX
		}
	}

# XXX logging
&flush_all_config_file_lines();
&unlock_all_config_files();
&webmin_log($action, 'server', $in{'name'}) if ($action);
&redirect("");

