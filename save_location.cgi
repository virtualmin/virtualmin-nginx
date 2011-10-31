#!/usr/local/bin/perl
# Create, update or delete a location block

use strict;
use warnings;
require 'virtualmin-nginx-lib.pl';
our (%text, %in, %config);
&ReadParse();

# Get the current location
&lock_all_config_files();
my $server = &find_server($in{'id'}):
$server || &error($text{'server_egone'});
my $conf = &get_config();
my @locations = &find("location", $server);
my $location;
my $old_name;
if ($in{'new'}) {
	$location = { 'name' => 'location',
		      'type' => 1,
		      'words' => [ $in{'path'} ],
		      'members' => [ ] };
	}
else {
	$location = &find_location($server, $in{'id'});
        $location || &error($text{'location_egone'});
        }

# Check for clash
if ($in{'new'} || $in{'path'} ne $location->{'words'}->[0]) {
	foreach my $l (@locations) {
		$l->{'words'}->[0] eq $in{'path'} &&
			&error($text{'location_eclash'});
		}
	}

my $action;
my $name;
if ($in{'delete'}) {
	if ($in{'confirm'}) {
		# Got confirmation, delete it
		&save_directive($server, [ $location ], [ ]);
		$action = 'delete';
		}
	else {
		# Ask for confirmation first
		&ui_print_header(&location_desc($server, $location),
				 $text{'location_edit'}, "");

		print &ui_confirmation_form("save_location.cgi",
			&text('location_rusure',
			      "<tt>".&html_escape($location->{'words'}->[0])."</tt>"),
			[ [ 'id', $in{'id'} ],
			  [ 'path', $in{'path'} ],
			  [ 'delete', 1 ] ],
			[ [ 'confirm', $text{'server_confirm'} ] ],
			);

		&ui_print_footer("edit_location.cgi?id=".&urlize($in{'id'}).
				   "&path=".&urlize($in{'path'}),
				 $text{'server_return'});
		}
	}
else {
	# Validate path
	$in{'path'} =~ /^\/\S+$/ || &error($text{'location_epath'});

	if ($in{'new'}) {
		# Create a new location object
		&save_directive($server, [ ], [ $location ]);
		$action = 'create';
		}
	else {
		# Update path in existing one
		$location->{'words'}->[0] = $in{'path'};
		&save_directive($server, [ $location ], [ $location ]);
		$action = 'modify';
		}

	# Update root directory
	&nginx_text_parse("root", $location, undef, '^\/\S+$');
	}

&flush_config_file_lines();
&unlock_all_config_files();
if ($action) {
	my $name = &find_value("server_name", $server);
	&webmin_log($action, 'location', $name, { 'server' => $name });
	&redirect("");
	}


