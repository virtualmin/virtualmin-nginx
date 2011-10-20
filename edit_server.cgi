#!/usr/local/bin/perl
# Show the config for one HTTP server

use strict;
use warnings;
require 'virtualmin-nginx-lib.pl';
our (%text, %in);
&ReadParse();

my $server;
if ($in{'new'}) {
	&ui_print_header(undef, $text{'server_create'}, "");
	$server = { 'name' => 'server',
		    'members' => [ ] };
	}
else {
	&ui_print_header(undef, $text{'server_edit'}, "");
	$server = &find_server($in{'id'});
	$server || &error($text{'server_egone'});
	}

if ($in{'server'}) {
	# Show icons for server settings types
	# XXX

	# Show table for locations
	# XXX

	print &ui_hr();
	}

# Show form to edit name, IPs and root
print &ui_form_start("save_server.cgi", "post");
print &ui_hidden("id", $in{'id'});
print &ui_hidden("new", $in{'new'});
print &ui_table_start($text{'server_header'}, "width=100%", 2);

# Server name
print &nginx_text_input("server_name", $server, 50);

# IP addresses / ports to listen on
my @listen;
if ($in{'new'}) {
	@listen = ( &value_to_struct('listen', '80') );
	}
else {
	@listen = &find("listen", $server);
	}
my $table = &ui_columns_start([ $text{'server_ip'},
				$text{'server_port'},
				$text{'server_default'},
				$text{'server_ssl'},
				$text{'server_ipv6'} ], 100);
my $i = 0;
my @tds = ( "valign=top", "valign=top", "valign=top",
	    "valign=top", "valign=top" );
foreach my $l (@listen, { 'words' => [ ] }) {
	my @w = @{$l->{'words'}};
	my ($ip, $port) = @w ? &split_ip_port(shift(@w)) : ( );
	my ($default, $ssl, $ipv6) = (0, 0, "");
	foreach my $w (@w) {
		if ($w eq "default" || $w eq "default_server") {
			$default = 1;
			}
		elsif ($w eq "ssl") {
			$ssl = 1;
			}
		elsif ($w =~ /^ipv6only=(\S+)/) {
			$ipv6 = lc($1);
			}
		}
	my $ipmode = !$ip && !$port ? 3 : $ip eq "::" ? 2 : $ip eq "" ? 1 : 0;
	# XXX disable inputs when disabled
	$table .= &ui_columns_row([
		&ui_radio("ip_def_$i", $ipmode,
			  [ [ 3, $text{'server_none'}."<br>" ],
			    [ 1, $text{'server_ipany'}."<br>" ],
			    [ 2, $text{'server_ip6any'}."<br>" ],
			    [ 0, $text{'server_ipaddr'} ] ])." ".
		  &ui_textbox("ip_$i", $ipmode == 0 ? $ip : "", 30),
		&ui_textbox("port_$i", $port, 6),
		&ui_select("default_$i", $default,
			   [ [ 0, $text{'no'} ], [ 1, $text{'yes'} ] ]),
		&ui_select("ssl_$i", $ssl,
			   [ [ 0, $text{'no'} ], [ 1, $text{'yes'} ] ]),
		&ui_select("ipv6_$i", $ipv6,
			   [ [ "", $text{'server_auto'} ],
		  	     [ "off", $text{'no'} ], [ "on", $text{'yes'} ] ]),
		], \@tds);
	$i++;
	}
$table .= &ui_columns_end();
print &ui_table_row($text{'server_listen'}, $table);

# Root directory (for new hosts)
if ($in{'new'}) {
	print &ui_table_row($text{'server_rootdir'},
		&ui_filebox("rootdir", undef, 50, 0, undef, undef, 1));
	}

print &ui_table_end();
if ($in{'new'}) {
	print &ui_form_end([ [ undef, $text{'create'} ] ]);
	}
else {
	print &ui_form_end([ [ undef, $text{'save'} ],
			     [ 'delete', $text{'server_delete'} ] ]);
	}

&ui_print_footer("", $text{'index_return'});
