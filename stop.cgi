#!/usr/local/bin/perl
# Stop the webserver

use strict;
use warnings;
require 'virtualmin-nginx-lib.pl';
our (%text, %access);
&error_setup($text{'stop_err'});
$access{'stop'} || &error($text{'stop_ecannot'});

my $err = &stop_nginx();
$err && &error("<tt>".&html_escape($err)."</tt>");
&webmin_log("stop");
&redirect("");
