#!/usr/local/bin/perl
# Show virtual host logging options

use strict;
use warnings;
require 'virtualmin-nginx-lib.pl';
our (%text, %in, %access);
&ReadParse();
my $server = &find_server($in{'id'});
$server || &error($text{'server_egone'});
&can_edit_server($server) || &error($text{'server_ecannot'});

&ui_print_header(undef, $text{'slogs_title'}, "");

print &ui_form_start("save_slogs.cgi", "post");
print &ui_hidden("id", $in{'id'});
print &ui_table_start($text{'slogs_header'}, undef, 2);

print &nginx_error_log_input("error_log", $server);

print &nginx_access_log_input("access_log", $server);

print &nginx_logformat_input("log_format", $server);

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("edit_server.cgi?id=".&urlize($in{'id'}),
		 $text{'server_return'});
