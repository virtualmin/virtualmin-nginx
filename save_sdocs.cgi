#!/usr/local/bin/perl
# Save document options

use strict;
use warnings;
require './virtualmin-nginx-lib.pl';
our (%text, %in, %access);
&lock_all_config_files();
&error_setup($text{'docs_err'});
&ReadParse();
my $server = &find_server($in{'id'});
$server || &error($text{'server_egone'});
&can_edit_server($server) || &error($text{'server_ecannot'});

&nginx_opt_parse("root", $server, undef, '^\/.*$');
$in{'root_def'} || &can_directory($in{'root'}) ||
	&error(&text('location_ecannot',
		     "<tt>".&html_escape($in{'root'})."</tt>",
		     "<tt>".&html_escape($access{'root'})."</tt>"));

&nginx_opt_parse("index", $server, undef, undef, undef, 1);

&nginx_opt_parse("default_type", $server, undef,
		 '^[a-zA-Z0-9\.\_\-]+\/[a-zA-Z0-9\.\_\-]+$');

&flush_config_file_lines();
&unlock_all_config_files();
my $name = &find_value("server_name", $server);
&webmin_log("sdocs", "server", $name);

# Redirect with the the new root directory if it was changed
my ($dom, $domroot_curr) = split(/;/, $in{'id'});
my $domroot_new = $in{'root'} ? $in{'root'} : undef;
my ($return_id, $return_query) = ($in{'id'}, "");
if ($domroot_new && $domroot_new ne $domroot_curr) {
	&foreign_require("virtual-server");
	my $d = &virtual_server::get_domain_by('dom', $dom);
	if ($d) {
		&virtual_server::clear_links_cache($d);
		$return_id = "$dom;$domroot_new";
		$return_query = "refresh=1";
		}
	}

&redirect("edit_server.cgi?id=".&urlize($return_id).
	  ($return_query ? "&$return_query" : ""));

