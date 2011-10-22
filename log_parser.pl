# log_parser.pl
# Functions for parsing this module's logs

use strict;
use warnings;
do 'virtualmin-nginx-lib.pl';
our (%text);

# parse_webmin_log(user, script, action, type, object, &params)
# Converts logged information from this module into human-readable form
sub parse_webmin_log
{
my ($user, $script, $action, $type, $object, $p) = @_;
if ($type eq 'mime') {
	return &text('log_'.$action.'_mime', &html_escape($object));
	}
elsif ($type eq 'mimes') {
	return &text('log_'.$action.'_mimes', $object);
	}
elsif ($type eq 'manual') {
	return &text('log_manual', &html_escape($object));
	}
elsif ($type eq 'server') {
	return &text('log_'.$action.'_server', &html_escape($object));
	}
else {
	return $text{'log_'.$action};
	}
return undef;
}

