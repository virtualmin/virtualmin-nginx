# Common functions for NginX config file

use strict;
use warnings;

BEGIN { push(@INC, ".."); };
eval "use WebminCore;";
&init_config();
our %access = &get_module_acl();
our $get_config_cache;
our %config;

# get_config()
# Parses the Nginx config file into an array ref
sub get_config
{
if (!$get_config_cache) {
	$get_config_cache = &read_config_file($config{'nginx_config'});
	}
return $get_config_cache;
}

# read_config_file(file)
# Returns an array ref of nginx config objects
sub read_config_file
{
my ($file) = @_;
my $fh;
my @rv = ( );
my $addto = \@rv;
my @stack = ( );
my $lnum = 0;
&open_readfile($fh, $file);
while(<$fh>) {
	s/#.*$//;
	if (/^(\S+)\s+\{/) {
		# Start of a section
		my $ns = { 'name' => $1,
			   'type' => 1,
			   'file' => $file,
			   'line' => $lnum,
			   'eline' => $lnum,
			   'members' => [ ] };
		push(@stack, $addto);
		push(@$addto, $ns);
		$addto = $ns->{'members'};
		}
	elsif (/\s*}/) {
		# End of a section
		$addto = pop(@stack);
		$addto->[@$addto-1]->{'eline'} = $lnum;
		}
	elsif (/^(\S+)\s*"([^"]*)";/ ||
	       /^(\S+)\s*'([^']*)';/ ||
	       /^(\S+)\s*(\S+);/) {
		# Found a directive
		my ($name, $value) = ($1, $2);
		if ($name eq "include") {
			# Include a file or glob
			if ($value !~ /^\//) {
				my $filedir = $file;
				$filedir =~ s/\/[^\/]+$//;
				$value = $filedir."/".$value;
				}
			foreach my $ifile (glob($value)) {
				my $inc = &read_config_file($ifile);
				push(@$addto, $inc);
				}
			}
		else {
			# Some directive in the current section
			my $dir = { 'name' => $name,
				    'value' => $value,
				    'type' => 0,
				    'file' => $file,
				    'line' => $lnum,
				    'eline' => $lnum };
			push(@$addto, $dir);
			}
		}
	$lnum++;
	}
close($fh);
return \@rv;
}

# get_nginx_version()
# Returns the version number of the installed Nginx binary
sub get_nginx_version
{
my $out = &backquote_command("$config{'nginx_cmd'} -v 2>&1 </dev/null");
return $out =~ /version:\s*nginx\/([0-9\.]+)/i ? $1 : undef;
}

1;

