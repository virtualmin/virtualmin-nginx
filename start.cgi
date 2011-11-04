#!/usr/local/bin/perl
# Start the webserver

use strict;
use warnings;
require 'virtualmin-nginx-lib.pl';
our (%text, %access);
&error_setup($text{'start_err'});
$access{'stop'} || &error($text{'start_ecannot'});

my $err = &start_nginx();
$err && &error("<tt>".&html_escape($err)."</tt>");
&webmin_log("start");
&redirect("");
