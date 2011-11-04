#!/usr/local/bin/perl
# Show global server-side include options

use strict;
use warnings;
require 'virtualmin-nginx-lib.pl';
our (%text, %access);
my $parent = &get_config_parent();
my $http = &find("http", $parent);
$access{'global'} || &error($text{'index_eglobal'});

&ui_print_header(undef, $text{'ssi_title'}, "");

print &ui_form_start("save_ssi.cgi", "post");
print &ui_table_start($text{'ssi_header'}, undef, 2);

print &nginx_onoff_input("ssi", $http);

print &nginx_onoff_input("ssi_silent_errors", $http);

print &nginx_opt_list_input("ssi_types", $http, 60, $text{'ssi_types'});

print &nginx_opt_input("ssi_value_length", $http, 10);

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});
