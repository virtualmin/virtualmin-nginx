# Common functions for NginX config file

use strict;
use warnings;

BEGIN { push(@INC, ".."); };
eval "use WebminCore;";
&init_config();
our %access = &get_module_acl();
our $get_config_cache;
our %get_default_cache;
our (%config, %text, %in, $module_root_directory);

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
my @rv = ( );
my $addto = \@rv;
my @stack = ( );
my $lnum = 0;
my $lref = &read_file_lines($file, 1);
foreach (@$lref) {
	s/#.*$//;
	if (/^\s*(\S+)\s+((\S+)\s+)?\{/) {
		# Start of a section
		my $ns = { 'name' => $1,
			   'value' => $3,
			   'type' => 1,
			   'file' => $file,
			   'line' => $lnum,
			   'eline' => $lnum,
			   'members' => [ ] };
		push(@stack, $addto);
		push(@$addto, $ns);
		$addto = $ns->{'members'};
		}
	elsif (/^\s*}/) {
		# End of a section
		$addto = pop(@stack);
		$addto->[@$addto-1]->{'eline'} = $lnum;
		}
	elsif (/^\s*(\S+)((\s+("([^"]*)"|'([^']*)'|\S+))*);/) {
		# Found a directive
		my ($name, $value) = ($1, $2);
		my @words;
		while($value =~ s/^\s+"([^"]+)"// ||
		      $value =~ s/^\s+'([^']+)'// ||
		      $value =~ s/^\s+(\S+)//) {
			push(@words, $1);
			}
		if ($name eq "include") {
			# Include a file or glob
			if ($words[0] !~ /^\//) {
				my $filedir = $file;
				$filedir =~ s/\/[^\/]+$//;
				$words[0] = $filedir."/".$value;
				}
			foreach my $ifile (glob($words[0])) {
				my $inc = &read_config_file($ifile);
				push(@$addto, @$inc);
				}
			}
		else {
			# Some directive in the current section
			my $dir = { 'name' => $name,
				    'value' => $words[0],
				    'words' => \@words,
				    'type' => 0,
				    'file' => $file,
				    'line' => $lnum,
				    'eline' => $lnum };
			push(@$addto, $dir);
			}
		}
	$lnum++;
	}
return \@rv;
}

# find(name, [&config])
# Returns the object or objects with some name in the given config
sub find
{
my ($name, $conf) = @_;
$conf ||= &get_config();
my @rv;
foreach my $c (@$conf) {
	if (lc($c->{'name'}) eq $name) {
		push(@rv, $c);
		}
	}
return wantarray ? @rv : $rv[0];
}

# find_value(name, [config])
# Returns the value of the object or objects with some name in the given config
sub find_value
{
my ($name, $conf) = @_;
my @rv = map { $_->{'value'} } &find($name, $conf);
return wantarray ? @rv : $rv[0];
}

# save_directive(&parent, name, &values)
# Updates the values of some named directive
sub save_directive
{
my ($parent, $name, $values) = @_;
my $oldvalues = [ &find($name, $parent) ];
for(my $i=0; $i<@$values || $i<@$oldvalues; $i++) {
	# XXX
	}
}

# get_nginx_version()
# Returns the version number of the installed Nginx binary
sub get_nginx_version
{
my $out = &backquote_command("$config{'nginx_cmd'} -v 2>&1 </dev/null");
return $out =~ /version:\s*nginx\/([0-9\.]+)/i ? $1 : undef;
}

# get_default(name)
# Returns the default value for some directive
sub get_default
{
my ($name) = @_;
if (!%get_default_cache) {
	my $lref = &read_file_lines("$module_root_directory/default-values", 1);
	foreach my $l (@$lref) {
		$l =~ s/^\s*#.*//;
		$l =~ s/\s+$//;
		if ($l =~ /^(\S+)\s+(.*)/) {
			$get_default_cache{$1} = $2;
			}
		}
	}
return $get_default_cache{$name};
}

# nginx_onoff_input(name, &config)
# Returns HTML for a table row for an on/off input
sub nginx_onoff_input
{
my ($name, $conf) = @_;
my $value = &find_value($name, $conf);
$value ||= &get_default($name);
return &ui_table_row($text{'opt_'.$name},
	&ui_yesno_radio($name, $value =~ /on|true|yes/i ? 1 : 0));
}

# nginx_onoff_parse(name, &config, &in)
# Updates the config with input from nginx_onoff_input
sub nginx_onoff_parse
{
my ($name, $conf, $in) = @_;
$in ||= \%in;
&save_directive($conf, $name, [ $in->{$name} ? "on" : "off" ]);
}

# nginx_opt_input(name, &config, size, prefix, suffix)
# Returns HTML for an optional text field
sub nginx_opt_input
{
my ($name, $conf, $size, $prefix, $suffix) = @_;
my $value = &find_value($name, $conf);
my $def = &get_default($name);
return &ui_table_row($text{'opt_'.$name},
	&ui_opt_textbox($name, $value, $size,
			$text{'default'}.($def ? " ($def)" : ""), $prefix).
	$suffix, $size > 40 ? 3 : 1);
}

1;

