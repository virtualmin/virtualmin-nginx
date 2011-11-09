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
	return &text('log_'.$action.'_mime',
		     "<tt>".&html_escape($object)."</tt>");
	}
elsif ($type eq 'mimes') {
	return &text('log_'.$action.'_mimes', $object);
	}
elsif ($action eq 'manual') {
	return &text('log_manual',
		     "<tt>".&html_escape($object)."</tt>");
	}
elsif ($type eq 'server') {
	return &text('log_'.$action.'_server',
		     "<tt>".&html_escape($object)."</tt>");
	}
elsif ($type eq 'location') {
	return &text('log_'.$action.'_location',
		     "<tt>".&html_escape($object)."</tt>",
		     "<tt>".&html_escape($p->{'server'})."</tt>");
	}
elsif ($type eq 'user') {
	return &text('log_'.$action.'_user',
		     "<tt>".&html_escape($object)."</tt>",
		     "<tt>".&html_escape($p->{'file'})."</tt>");
	}
else {
	return $text{'log_'.$action};
	}
return undef;
}

