#!/usr/local/bin/perl
# Show virtual host FCGI options

use strict;
use warnings;
require 'virtualmin-nginx-lib.pl';
our (%text, %in);
&ReadParse();
my $server = &find_server($in{'id'});
$server || &error($text{'server_egone'});

&ui_print_header(&server_desc($server), $text{'fcgi_title'}, "");

print &ui_form_start("save_fcgi.cgi", "post");
print &ui_hidden("id", $in{'id'});
print &ui_table_start($text{'fcgi_header'}, undef, 2);

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("edit_server.cgi?id=".&urlize($in{'id'}),
		 $text{'server_return'});
