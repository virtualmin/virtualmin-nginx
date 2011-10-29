#!/usr/local/bin/perl
# Show document related options

use strict;
use warnings;
require 'virtualmin-nginx-lib.pl';
our (%text);
my $parent = &get_config_parent();
my $http = &find("http", $parent);

&ui_print_header(undef, $text{'docs_title'}, "");

print &ui_form_start("save_docs.cgi", "post");
print &ui_table_start($text{'docs_header'}, undef, 2);

print &nginx_opt_input("root", $http, 60, undef,
		       &file_chooser_button("root", 1));

print &nginx_opt_input("index", $http, 60);

print &nginx_opt_input("default_type", $http, 20);

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});
