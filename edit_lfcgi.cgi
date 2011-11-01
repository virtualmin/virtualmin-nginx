#!/usr/local/bin/perl
# Show location FCGI options

use strict;
use warnings;
require 'virtualmin-nginx-lib.pl';
our (%text, %in);
&ReadParse();
my $server = &find_server($in{'id'});
$server || &error($text{'server_egone'});
my $location = &find_location($server, $in{'path'});
$location || &error($text{'location_egone'});

&ui_print_header(&location_desc($server, $location), $text{'fcgi_title'}, "");

print &ui_form_start("save_lfcgi.cgi", "post");
print &ui_hidden("id", $in{'id'});
print &ui_hidden("path", $in{'path'});
print &ui_table_start($text{'fcgi_header'}, undef, 2);

print &nginx_opt_input("fastcgi_pass", $location, 50, $text{'fcgi_hostport'});

print &nginx_opt_input("fastcgi_index", $location, 20, $text{'fcgi_index'});

print &nginx_param_input("fastcgi_param", $location);

print &nginx_opt_input("fastcgi_buffer_size", $location, 10,
		       $text{'fcgi_buffer'});

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("edit_location.cgi?id=".&urlize($in{'id'}).
		   "&path=".&urlize($in{'path'}),
		 $text{'location_return'},
		 "edit_server.cgi?id=".&urlize($in{'id'}),
		 $text{'server_return'});
