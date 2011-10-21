#!/usr/local/bin/perl
# Create, update or delete a virtual host

use strict;
use warnings;
require 'virtualmin-nginx-lib.pl';
our (%text, %in);
&ReadParse();

# Get the current server
&lock_all_config_files();
my $conf = &get_config();
my $http = &find("http", $conf);
my $server;
if ($in{'new'}) {
	$server = { 'name' => 'server',
		    'type' => 1,
		    'members' => [ ] };
	}
else {
	$server = &find_server($in{'id'});
        $server || &error($text{'server_egone'});
        }

my $action;
if ($in{'delete'}) {
	if ($in{'confirm'}) {
		# Got confirmation, delete it
		# XXX
		$action = 'delete';
		}
	else {
		# Ask for confirmation first
		# XXX
		}
	}
else {
	if ($in{'new'}) {
		# Create a new server object
		&save_directive($http, [ ], [ $server ]);
		$action = 'create';
		}
	else {
		$action = 'modify';
		}

	# Validate and update existing directives, starting with hostname
	# or regexp
	&nginx_text_parse("server_name", $server, undef, '^\S+$');

	# Addresses to accept connections on
	# XXX preserve existing args
	my $i = 0;
	my @listens;
	while(defined($in{"ip_def_$i"})) {
		my $def = $in{"ip_def_$i"};
		next if ($def == 3);
		my $ip;
		if ($def == 0) {
			$ip = $in{"ip_$i"};
			$ip || &error(&text('server_eipmissing', $i+1));
			&to_ipaddress($ip) || &to_ip6address($ip) ||
				&error(&text('server_eip', $i+1, $ip));
			if (&check_ip6address($ip)) {
				$ip = "[$ip]";
				}
			}
		elsif ($def == 2) {
			$ip = "[::]";
			}
	
		# Port number
		$in{"port_$i"} =~ /^\d+$/ ||
			&error(&text('server_eport', $i+1));
		if ($ip && $in{"port_$i"} != 80) {
			$ip .= ":".$in{"port_$i"};
			}
		else {
			$ip = $in{"port_$i"};
			}

		# Other random options
		my @words = ( $ip );
		if ($in{"default_$i"}) {
			push(@words, "default_server");
			}
		if ($in{"ssl_$i"}) {
			push(@words, "ssl");
			}
		if ($in{"ipv6_$i"}) {
			push(@words, "ipv6only=".$in{"ipv6_$i"});
			}
		push(@listen, { 'name' => 'listen',
				'value' => $words[0],
				'words' => \@words });
		}
	@listen || &error($text{'server_elisten'});
	&save_directive($server, "listen", \@listen);

	if ($in{'new'}) {
		# Add root directory block
		# XXX
		}
	}

&flush_all_config_file_lines();
&unlock_all_config_files();
&webmin_log($action, 'server', $in{'name'}) if ($action);
&redirect("");

