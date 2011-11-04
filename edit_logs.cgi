#!/usr/local/bin/perl
# Show logging options

use strict;
use warnings;
require 'virtualmin-nginx-lib.pl';
our (%text, %access);
my $parent = &get_config_parent();
my $http = &find("http", $parent);
$access{'global'} || &error($text{'index_eglobal'});

&ui_print_header(undef, $text{'logs_title'}, "");

print &ui_form_start("save_logs.cgi", "post");
print &ui_table_start($text{'logs_header'}, undef, 2);

print &nginx_error_log_input("error_log", $parent);

print &nginx_access_log_input("access_log", $http);

print &nginx_logformat_input("log_format", $http);

print &nginx_opt_input("pid", $parent, 60, $text{'logs_file'});

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});
