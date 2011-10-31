#!/usr/local/bin/perl
# Show the config for one location inside a virtual host

use strict;
use warnings;
require 'virtualmin-nginx-lib.pl';
our (%text, %in);
&ReadParse();
my $server = &find_server($in{'id'});
$server || &error($text{'server_egone'});

my $location;
if ($in{'new'}) {
	&ui_print_header(&server_desc($server), $text{'location_create'}, "");
	$location = { 'name' => 'location',
		      'members' => [ ] };
	}
else {
	$location = &find_location($server, $in{'path'});
	$location || &error($text{'location_egone'});
	&ui_print_header(&location_desc($server, $location),
			 $text{'location_edit'}, "");
	}

if ($in{'path'}) {
	# Show icons for location types
	print &ui_subheading($text{'location_settings'});
	my @lpages = ( "ldocs", "lfcgi", "lssi", "lgzip", "lproxy", );
	&icons_table(
		[ map { "edit_".$_.".cgi?id=".&urlize($in{'id'}) } @lpages ],
		[ map { $text{$_."_title"} } @lpages ],
		[ map { "images/".$_.".gif" } @lpages ],
		);

	print &ui_hr();
	}

# Show form to edit location path and root
if (!$in{'new'}) {
	print &ui_subheading($text{'location_location'});
	}
print &ui_form_start("save_location.cgi", "post");
print &ui_hidden("id", $in{'id'});
print &ui_hidden("new", $in{'new'});
print &ui_hidden("path", $in{'path'});
print &ui_table_start($text{'location_header'}, "width=100%", 2);

# Location path
print &ui_table_row($text{'location_path'},
	&ui_textbox("path", $location->{'words'}->[0], 60));

# Root directory
print &nginx_text_input("root", $location, 60,
			&file_chooser_button("root", 1));

print &ui_table_end();
if ($in{'new'}) {
	print &ui_form_end([ [ undef, $text{'create'} ] ]);
	}
else {
	print &ui_form_end([ [ undef, $text{'save'} ],
			     [ 'delete', $text{'location_delete'} ] ]);
	}

&ui_print_footer("edit_server.cgi?id=".&urlize($in{'id'}),
		 $text{'server_return'});
