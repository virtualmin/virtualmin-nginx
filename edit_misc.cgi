#!/usr/local/bin/perl
# Show other random options

use strict;
use warnings;
require 'virtualmin-nginx-lib.pl';
our (%text);
my $parent = &get_config_parent();
my $events = &find("events", $parent);

&ui_print_header(undef, $text{'events_title'}, "");

print &ui_form_start("save_misc.cgi", "post");
print &ui_table_start($text{'misc_header'}, undef, 2);

print &nginx_user_input("user", $parent);

print &nginx_opt_input("worker_processes", $parent, 5);

print &nginx_opt_input("worker_priority", $parent, 5, $text{'misc_pri'},
		       $text{'misc_prisuffix'});

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});
