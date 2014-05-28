#!/usr/local/bin/perl
# Show Nginx virtual hosts and global config

use strict;
use warnings;
require 'virtualmin-nginx-lib.pl';
my $ver = &get_nginx_version();
our (%text, %module_info, %config, $module_name, %access);

&ui_print_header($ver ? &text('index_version', $ver) : undef,
		 $module_info{'desc'}, "", undef, 1, 1);

# Check config
if (!-r $config{'nginx_config'}) {
	&ui_print_endpage(
		&text('index_econfig', "<tt>$config{'nginx_config'}</tt>",
		"../config.cgi?$module_name"));
	}
if (!&has_command($config{'nginx_cmd'})) {
	&ui_print_endpage(
		&text('index_ecmd', "<tt>$config{'nginx_cmd'}</tt>",
		"../config.cgi?$module_name"));
	}

my $conf = &get_config();
if ($access{'global'}) {
	# Show icons for global config types
	print &ui_subheading($text{'index_global'});
	my @gpages = ( "net", "mime", "logs", "docs", "ssi", "misc", "manual" );
	&icons_table(
		[ map { "edit_".$_.".cgi" } @gpages ],
		[ map { $text{$_."_title"} } @gpages ],
		[ map { "images/".$_.".gif" } @gpages ],
		);
	print &ui_hr();
	}

# Show list of virtual hosts
print &ui_subheading($text{'index_virts'});
my $http = &find("http", $conf);
if (!$http) {
	&ui_print_endpage(
		&text('index_ehttp', "<tt>$config{'nginx_config'}</tt>"));
	}
my @allservers = &find("server", $http);
my @servers = grep { &can_edit_server($_) } @allservers;
my @links;
if (!$access{'vhosts'}) {
	push(@links, "<a href='edit_server.cgi?new=1'>$text{'index_add'}</a>");
	}
if (@servers) {
	print &ui_links_row(\@links);
	my @tds = ( "valign=top", undef, undef, "valign=top" );
	print &ui_columns_start([ $text{'index_name'},
				  $text{'index_ip'},
				  $text{'index_port'},
				  $text{'index_root'} ], 100, 0, \@tds);
	foreach my $s (@servers) {
		my $name = &find_value("server_name", $s);
		$name ||= "";

		# Extract all IPs and ports from listen directives
		my (@ips, @ports);
		foreach my $l (&find_value("listen", $s)) {
			my ($ip, $port) = &split_ip_port($l);
			$ip ||= $text{'index_any'};
			$ip = $text{'index_any6'} if ($ip eq "::");
			push(@ips, $ip);
			push(@ports, $port);
			}

		my $rootdir = &find_value("root", $s);
		my $root = $rootdir;
		if (!$root) {
			my @locs = &find("location", $s);
			my ($rootloc) = grep { $_->{'value'} eq '/' } @locs;
			if ($rootloc) {
				$rootdir = &find_value("root", $rootloc);
				$root = $rootdir ||
					"<i>$text{'index_noroot'}</i>";
				}
			else {
				$root = "<i>$text{'index_norootloc'}</i>";
				}
			$rootdir ||= "";
			}
		my $id = $name.";".$rootdir;
		print &ui_columns_row([
			"<a href='edit_server.cgi?id=".&urlize($id)."'>".
			  ($name ? &html_escape($name) : $text{'default'})."</a>",
			join("<br>", @ips),
			join("<br>", @ports),
			$root ],
			\@tds);
		}
	print &ui_columns_end();
	}
elsif (@allservers) {
	print "<b>$text{'index_noneaccess'}</b><p>\n";
	}
else {
	print "<b>$text{'index_none'}</b><p>\n";
	}
print &ui_links_row(\@links);

# Show start / stop buttons
print &ui_hr();
print &ui_buttons_start();
if (&is_nginx_running()) {
	if ($access{'stop'}) {
		print &ui_buttons_row("stop.cgi", $text{'index_stop'},
				      $text{'index_stopdesc'});
		}
	print &ui_buttons_row("restart.cgi", $text{'index_restart'},
			      $text{'index_restartdesc'});
	}
elsif ($access{'stop'}) {
	print &ui_buttons_row("start.cgi", $text{'index_start'},
			      $text{'index_startdesc'});
	}
print &ui_buttons_end();

&ui_print_footer("/", $text{'index'});
