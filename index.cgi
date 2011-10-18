#!/usr/local/bin/perl
# Show Nginx virtual hosts and global config

use strict;
use warnings;
require 'virtualmin-nginx-lib.pl';
my $ver = &get_nginx_version();
our (%text, %module_info, %config, $module_name);

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

# Show icons for global config types
print &ui_subheading($text{'index_global'});
my $conf = &get_config();
my @gpages = ( "net", "mime", "logs", "misc", "manual" );
&icons_table(
	[ map { "edit_".$_.".cgi" } @gpages ],
	[ map { $text{$_."_title"} } @gpages ],
	[ map { "images/".$_.".gif" } @gpages ],
	scalar(@gpages),
	);
print &ui_hr();

# Show list of virtual hosts
print &ui_subheading($text{'index_virts'});
my $http = &find("http", $conf);
if (!$http) {
	&ui_print_endpage(
		&text('index_ehttp', "<tt>$config{'nginx_config'}</tt>"));
	}
my @servers = &find("server", $http->{'members'});
my @links = ( "<a href='edit_server.cgi?new=1'>$text{'index_add'}</a>" );
if (@servers) {
	unshift(@links, &select_all_link("d"),
			&select_invert_link("d"));
	print &ui_links_row(\@links);
	my @tds = ( "width=5 valign=top", "valign=top",
		    undef, undef, "valign=top" );
	print &ui_columns_start([ "",
				  $text{'index_name'},
				  $text{'index_ip'},
				  $text{'index_port'},
				  $text{'index_root'} ], 100, 0, \@tds);
	foreach my $s (@servers) {
		my $name = &find_value("server_name", $s->{'members'});

		my (@ips, @ports);
		foreach my $l (&find_value("listen", $s->{'members'})) {
			if ($l =~ /^\d+$/) {
				push(@ips, $text{'index_any'});
				push(@ports, $l);
				}
			elsif ($l =~ /^\[(\S+)\]:(\d+)$/) {
				push(@ips, $1 eq "::" ? $text{'index_any6'}
						      : $1);
				push(@ports, $2);
				}
			elsif ($l =~ /^(\S+):(\d+)$/) {
				push(@ips, $1);
				push(@ports, $2);
				}
			}

		my @locs = &find("location", $s->{'members'});
		my ($rootloc) = grep { $_->{'value'} eq '/' } @locs;
		my $root;
		if ($rootloc) {
			$root = &find_value("root", $rootloc->{'members'}) ||
				"<i>$text{'index_noroot'}</i>";
			}
		else {
			$root = "<i>$text{'index_norootloc'}</i>";
			}
		my $id = $name.";".$root;
		print &ui_checked_columns_row([
				"<a href='edit_serv.cgi?id=".&urlize($id)."'>".
				  &html_escape($name)."</a>",
				join("<br>", @ips),
				join("<br>", @ports),
				$root ],
			\@tds, "d", $name);
		}
	print &ui_columns_end();
	}
else {
	print "<b>$text{'index_none'}</b><p>\n";
	}
print &ui_links_row(\@links);

# Show start / stop buttons
print &ui_hr();
print &ui_buttons_start();
if (&is_nginx_running()) {
	print &ui_buttons_row("stop.cgi", $text{'index_stop'},
			      $text{'index_stopdesc'});
	print &ui_buttons_row("restart.cgi", $text{'index_restart'},
			      $text{'index_restartdesc'});
	}
else {
	print &ui_buttons_row("start.cgi", $text{'index_start'},
			      $text{'index_startdesc'});
	}
print &ui_buttons_end();

&ui_print_footer("/", $text{'index'});
