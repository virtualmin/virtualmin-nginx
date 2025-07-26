#!/usr/local/bin/perl
# Show document related options for a virtual host

use strict;
use warnings;
require './virtualmin-nginx-lib.pl';
our (%text, %in, %access);
&ReadParse();
my $server = &find_server($in{'id'});
$server || &error($text{'server_egone'});
&can_edit_server($server) || &error($text{'server_ecannot'});

&ui_print_header(&server_desc($server), $text{'sdocs_title'}, "");

print &ui_form_start("save_sdocs.cgi", "post");
print &ui_hidden("id", $in{'id'});
print &ui_table_start($text{'docs_header'}, undef, 2);

if (!&foreign_check("virtual-server")) {
	print &nginx_opt_input("root", $server, 60, undef,
			       &file_chooser_button("root", 1));
	}

print &nginx_opt_input("index", $server, 60, undef, undef, 1);

print &nginx_opt_input("default_type", $server, 20);

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("edit_server.cgi?id=".&urlize($in{'id'}),
		 $text{'server_return'});
