#!/usr/local/bin/perl
# Show virtual host access control options

use strict;
use warnings;
require 'virtualmin-nginx-lib.pl';
our (%text, %in);
&ReadParse();
my $server = &find_server($in{'id'});
$server || &error($text{'server_egone'});

&ui_print_header(&server_desc($server), $text{'access_title'}, "");

print &ui_form_start("save_saccess.cgi", "post");
print &ui_hidden("id", $in{'id'});
print &ui_table_start($text{'access_header'}, undef, 2);

print &nginx_access_input("allow", "deny", $server);

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("edit_server.cgi?id=".&urlize($in{'id'}),
		 $text{'server_return'});
