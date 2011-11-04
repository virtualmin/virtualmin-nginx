#!/usr/local/bin/perl
# Show networking-related options

use strict;
use warnings;
require 'virtualmin-nginx-lib.pl';
our (%text, %access);
my $conf = &get_config();
my $http = &find("http", $conf);
$access{'global'} || &error($text{'index_eglobal'});

&ui_print_header(undef, $text{'net_title'}, "");

print &ui_form_start("save_net.cgi", "post");
print &ui_table_start($text{'net_header'}, undef, 2);

print &nginx_onoff_input("sendfile", $http);

print &nginx_onoff_input("gzip", $http);

print &nginx_opt_input("gzip_disable", $http, 60, $text{'net_regexp'});

print &nginx_onoff_input("tcp_nopush", $http);

print &nginx_onoff_input("tcp_nodelay", $http);

print &nginx_opt_input("keepalive_timeout", $http, 5, undef,
		       $text{'opt_secs'});

print &nginx_opt_input("keepalive_requests", $http, 5, undef);

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});
