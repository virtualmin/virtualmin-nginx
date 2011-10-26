#!/usr/local/bin/perl
# Show virtual host SSL options

use strict;
use warnings;
require 'virtualmin-nginx-lib.pl';
our (%text, %in);
&ReadParse();
my $server = &find_server($in{'id'});
$server || &error($text{'server_egone'});

&ui_print_header(undef, $text{'ssl_title'}, "");

print &ui_form_start("save_ssl.cgi", "post");
print &ui_hidden("id", $in{'id'});
print &ui_table_start($text{'ssl_header'}, undef, 2);

print &nginx_onoff_input("ssl", $server);

print &nginx_opt_input("ssl_certificate", $server, 50, $text{'ssl_file'},
		       &file_chooser_button("ssl_certificate"));

print &nginx_opt_input("ssl_certificate_key", $server, 50, $text{'ssl_file'},
		       &file_chooser_button("ssl_certificate_key"));

print &nginx_opt_input("ssl_ciphers", $server, 30, $text{'ssl_clist'});

print &nginx_multi_input("ssl_protocols", $server,
			 [ "SSLv2", "SSLv3", "TLSv1" ]);

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("edit_server.cgi?id=".&urlize($in{'id'}),
		 $text{'server_return'});
