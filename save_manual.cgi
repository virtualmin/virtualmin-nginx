#!/usr/local/bin/perl
# Update one config file

use strict;
use warnings;
require 'virtualmin-nginx-lib.pl';
&ReadParseMime();
our (%text, %in);
&error_setup($text{'manual_err'});

$in{'data'} =~ s/\r//g;
if ($in{'test'}) {
	# Backup the file, write to it, and then test the config
	my $temp = &transname();
	}
