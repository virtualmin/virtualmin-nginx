# Virtualmin API plugins for Nginx

use strict;
use warnings;
require 'virtualmin-nginx-lib.pl';
our (%text);

sub feature_name
{
return $text{'feat_name'};
}

sub feature_losing
{
return $text{'feat_losing'};
}

sub feature_disname
{
return $text{'feat_disname'};
}

sub feature_label
{
return $text{'feat_label'};
}

sub feature_hlink
{
return "label";
}

sub feature_check
{
if (!-r $config{'nginx_config'}) {
	return &text('feat_econfig', "<tt>$config{'nginx_config'}</tt>");
	}
elsif (!&has_command($config{'nginx_cmd'})) {
	return &text('feat_ecmd', "<tt>$config{'nginx_cmd'}</tt>");
	}
else {
	return undef;
	}
}

1;

