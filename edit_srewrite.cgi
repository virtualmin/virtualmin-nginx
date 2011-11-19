#!/usr/local/bin/perl
# Show virtual host URL re-write options

use strict;
use warnings;
require 'virtualmin-nginx-lib.pl';
our (%text, %in, %access);
&ReadParse();
my $server = &find_server($in{'id'});
$server || &error($text{'server_egone'});
&can_edit_server($server) || &error($text{'server_ecannot'});

&ui_print_header(&server_desc($server), $text{'rewrite_title'}, "");

print &ui_form_start("save_srewrite.cgi", "post");
print &ui_hidden("id", $in{'id'});
print &ui_table_start($text{'rewrite_header'}, undef, 2);

print &nginx_rewrite_input("rewrite", $server);

print &nginx_onoff_input("rewrite_log", $server);

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("edit_server.cgi?id=".&urlize($in{'id'}),
		 $text{'server_return'});
