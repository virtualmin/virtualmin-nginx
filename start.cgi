#!/usr/local/bin/perl
# Start the webserver

use strict;
use warnings;
require 'virtualmin-nginx-lib.pl';
our (%text);
&error_setup($text{'start_err'});

my $err = &start_nginx();
$err && &error("<tt>".&html_escape($err)."</tt>");
&webmin_log("start");
&redirect("");
