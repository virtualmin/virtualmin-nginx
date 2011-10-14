#!/usr/local/bin/perl
# Create, save or delete MIME types

use strict;
use warnings;
require 'virtualmin-nginx-lib.pl';
our (%text, %in);
&ReadParse();
&error_setup($text{'mime_err'});
&lock_all_config_files();
my $conf = &get_config();
my $http = &find("http", $conf);
my $types = &find("types", $http);

# Validate type name and values
my @words;
if ($in{'new'} || $in{'type'}) {
	# XXX clash check
	$in{'name'} =~ /^[a-z0-9\.\_\-]+\/[a-z0-9\.\_\-]+$/ ||
		&error($text{'mime_ename'});
	@words = split(/\s+/, $in{'words'});
	@words || &error($text{'mime_ewords'});
	foreach my $w (@words) {
		$w =~ /^[a-z0-9\_\-]+$/ || &error($text{'mime_eword'});
		}
	}

if ($in{'new'}) {
	# Add a new type
	&save_directive($types, [ ], [ { 'name' => $in{'name'},
					 'words' => \@words } ]);
	}
elsif ($in{'type'}) {
	# Updating some type
	}
elsif ($in{'delete'}) {
	# Deleting some rows
	}
else {
	# Nothing to do?
	&error($text{'mime_ebutton'});
	}

&flush_config_file_lines();
&unlock_all_config_files();
&webmin_log("net");
&redirect("edit_mime.cgi?search=".&urlize($in{'search'}));
