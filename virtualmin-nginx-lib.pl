# Common functions for NginX config file

use strict;
use warnings;

BEGIN { push(@INC, ".."); };
eval "use WebminCore;";
&init_config();
our %access = &get_module_acl();
our ($get_config_cache, $get_config_parent_cache, %list_directives_cache,
     @list_modules_cache);
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

# get_config_parent()
# Returns an object that represents the whole config file
sub get_config_parent
{
if (!$get_config_parent_cache) {
	$get_config_parent_cache = { 'members' => &get_config(),
				     'file' => $config{'nginx_config'},
				     'indent' => 0,
				     'line' => 0,
				     'eline' => 0 };
	foreach my $c (@{$get_config_parent_cache->{'members'}}) {
		if ($c->{'file'} eq $get_config_parent_cache->{'file'} &&
		    $c->{'eline'} > $get_config_parent_cache->{'eline'}) {
			$get_config_parent_cache->{'eline'} = $c->{'eline'};
			}
		}
	}
return $get_config_parent_cache;
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
my $fh = "CFILE";
&open_readfile($fh, $file);
my @lines = <$fh>;
close($fh);
foreach (@lines) {
	s/#.*$//;
	if (/^\s*(\S+)\s+((\S+)\s+)?\{/) {
		# Start of a section
		my $ns = { 'name' => $1,
			   'value' => $3,
			   'type' => 1,
			   'indent' => scalar(@stack),
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
				    'indent' => scalar(@stack),
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

# find(name, [&config|&parent])
# Returns the object or objects with some name in the given config
sub find
{
my ($name, $conf) = @_;
$conf ||= &get_config();
if (ref($conf) eq 'HASH') {
	$conf = $conf->{'members'};
	}
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
my $oldstructs = [ &find($name, $parent) ];
my $newstructs = [ map { &value_to_struct($name, $_) } @$values ];
for(my $i=0; $i<@$newstructs || $i<@$oldstructs; $i++) {
	my $o = $i<@$oldstructs ? $oldstructs->[$i] : undef;
	my $n = $i<@$newstructs ? $newstructs->[$i] : undef;
	my $file = $o ? $o->{'file'} : $parent->{'file'};
	my $lref = &read_file_lines($file);
	if ($i<@$newstructs && $i<@$oldstructs) {
		# Updating some directive
		$o->{'value'} = $n->{'value'};
		$o->{'words'} = $n->{'words'};
		$lref->[$o->{'line'}] = &make_directive_lines(
						$o, $parent->{'indent'} + 1);
		}
	elsif ($i<@$newstructs) {
		# Adding a directive
		&renumber($file, $parent->{'eline'}-1, 1);
		$n->{'eline'} = $n->{'line'} = $parent->{'eline'};
		push(@{$parent->{'members'}}, $n);
		splice(@$lref, $n->{'line'}, 0,
		       &make_directive_lines($n, $parent->{'indent'} + 1));
		}
	elsif ($i<@$oldstructs) {
		# Removing a directive
		splice(@$lref, $o->{'line'}, 1);
		my $idx = &indexof($o, @{$parent->{'members'}});
		if ($idx >= 0) {
			splice(@{$parent->{'members'}}, $idx, 1);
			}
		&renumber($file, $o->{'line'}, -1);
		}
	}
}

# renumber(filename, line, offset, [&parent])
# Adjusts the line number of any directive after the one given by the offset
sub renumber
{
my ($file, $line, $offset, $object) = @_;
$object ||= &get_config_parent();
if ($object->{'file'} eq $file) {
	$object->{'line'} += $offset if ($object->{'line'} > $line);
	$object->{'eline'} += $offset if ($object->{'eline'} > $line);
	}
if ($object->{'type'}) {
	foreach my $m (@{$object->{'members'}}) {
		&renumber($file, $line, $offset, $m);
		}
	}
}

# flush_config_file_lines([&parent])
# Flush all lines in the current config
sub flush_config_file_lines
{
my ($parent) = @_;
foreach my $f (&get_all_config_files($parent)) {
	&flush_file_lines($f);
	}
}

# lock_all_config_files([&parent])
# Locks all files used in the current config
sub lock_all_config_files
{
my ($parent) = @_;
foreach my $f (&get_all_config_files($parent)) {
	&lock_file($f);
	}
}

# unlock_all_config_files([&parent])
# Un-locks all files used in the current config
sub unlock_all_config_files
{
my ($parent) = @_;
foreach my $f (reverse(&get_all_config_files($parent))) {
	&unlock_file($f);
	}
}

# get_all_config_files([&parent])
# Returns all files in the given config object
sub get_all_config_files
{
my ($parent) = @_;
$parent ||= &get_config_parent();
my @rv = ( $parent->{'file'} );
if ($parent->{'type'}) {
	foreach my $c (@{$parent->{'members'}}) {
		push(@rv, &get_all_config_files($c));
		}
	}
return &unique(@rv);
}

# make_directive_lines(&directive, indent)
# Returns text for some directive
sub make_directive_lines
{
my ($dir, $indent) = @_;
my @rv;
if ($dir->{'type'}) {
	# Multi-line
	# XXX
	}
else {
	# Single line
	push(@rv, $dir->{'name'}." ".&join_words(@{$dir->{'words'}}).";");
	}
foreach my $r (@rv) {
	$r = ("\t" x $indent).$r;
	}
return wantarray ? @rv : $rv[0];
}

# join_words(word, etc..)
# Returns a string made by joining directive words
sub join_words
{
my @rv;
foreach my $w (@_) {
	if ($w eq "") {
		push(@rv, '""');
		}
	elsif ($w =~ /\s/ && $w !~ /"/) {
		push(@rv, "\"$w\"");
		}
	elsif ($w =~ /\s/) {
		push(@rv, "'$w'");
		}
	else {
		push(@rv, $w);
		}
	}
return join(" ", @rv);
}

# value_to_struct(name, value)
# Converts a string, array ref or hash ref to a config struct
sub value_to_struct
{
my ($name, $value) = @_;
if (ref($value) eq 'HASH') {
	# Already in correct format
	$value->{'name'} = $name;
	return $value;
	}
elsif (ref($value) eq 'ARRAY') {
	# Array of words
	return { 'name' => $name,
		 'words' => $value,
		 'value' => $value->[0] };
	}
else {
	# Single value
	return { 'name' => $name,
		 'words' => [ $value ],
		 'value' => $value };
	}
}

# get_nginx_version()
# Returns the version number of the installed Nginx binary
sub get_nginx_version
{
my $out = &backquote_command("$config{'nginx_cmd'} -v 2>&1 </dev/null");
return $out =~ /version:\s*nginx\/([0-9\.]+)/i ? $1 : undef;
}

# list_nginx_directives()
# Returns a hash ref of hash refs, with name, module, default and context keys
sub list_nginx_directives
{
if (!%list_directives_cache) {
	my $lref = &read_file_lines(
			"$module_root_directory/nginx-directives", 1);
	foreach my $l (@$lref) {
		my ($module, $name, $default, $context) = split(/\t/, $l);
		$list_directives_cache{$name} = 
			{ 'module' => $module,
			  'name' => $name,
			  'default' => $default eq '-' ? undef : $default,
			  'context' => [ split(/,/, $context) ],
			};
		}
	}
return \%list_directives_cache;
}

# get_default(name)
# Returns the default value for some directive
sub get_default
{
my ($name) = @_;
my $dirs = &list_nginx_directives();
my $dir = $dirs->{$name};
return $dir ? $dir->{'default'} : undef;
}

# list_nginx_modules()
# Returns a list of enabled modules. Includes those compiled in by default
# unless disabled, plus extra compiled in at build time.
sub list_nginx_modules
{
if (!@list_modules_cache) {
	@list_modules_cache = ( 'http_core', 'http_access', 'http_access',
				'http_auth_basic', 'http_autoindex',
				'http_browser', 'http_charset',
				'http_empty_gif', 'http_fastcgi', 'http_geo',
				'http_gzip', 'http_limit_req',
				'http_limit_zone', 'http_map',
				'http_memcached', 'http_proxy',
				'http_referer', 'http_rewrite',
				'http_scgi', 'http_split_clients',
				'http_ssi', 'http_userid', 
				'http_uwsgi' );
	my $out = &backquote_command("$config{'nginx_cmd'} -V 2>&1 </dev/null");
	while($out =~ s/--with-(\S+)_module\s+//) {
		push(@list_modules_cache, $1);
		}
	while($out =~ s/--without-(\S+)_module\s+//) {
		@list_modules_cache = grep { $_ ne $1 } @list_modules_cache;
		}
	}
return @list_modules_cache;
}

# supported_directive(name, [&parent])
# Returns 1 if the module for some directive is supported on this system
sub supported_directive
{
my ($name, $parent) = @_;
my $dirs = &list_nginx_directives();
my $dir = $dirs->{$name};
return 0 if (!$dir);
return 0 if ($parent && &indexof($parent->{'name'}, @{$dir->{'context'}}) < 0);
my @mods = &list_nginx_modules();
return 0 if (&indexof($dir->{'module'}, @mods) < 0);
return 1;
}

# nginx_onoff_input(name, &parent)
# Returns HTML for a table row for an on/off input
sub nginx_onoff_input
{
my ($name, $parent) = @_;
return undef if (!&supported_directive($name, $parent));
my $value = &find_value($name, $parent);
$value ||= &get_default($name);
$value ||= "";
return &ui_table_row($text{'opt_'.$name},
	&ui_yesno_radio($name, $value =~ /on|true|yes/i ? 1 : 0));
}

# nginx_onoff_parse(name, &parent, &in)
# Updates the config with input from nginx_onoff_input
sub nginx_onoff_parse
{
my ($name, $parent, $in) = @_;
return undef if (!&supported_directive($name, $parent));
$in ||= \%in;
&save_directive($parent, $name, [ $in->{$name} ? "on" : "off" ]);
}

# nginx_opt_input(name, &parent, size, prefix, suffix)
# Returns HTML for an optional text field
sub nginx_opt_input
{
my ($name, $parent, $size, $prefix, $suffix) = @_;
return undef if (!&supported_directive($name, $parent));
my $value = &find_value($name, $parent);
my $def = &get_default($name);
return &ui_table_row($text{'opt_'.$name},
	&ui_opt_textbox($name, $value, $size,
			$text{'default'}.($def ? " ($def)" : ""), $prefix).
	$suffix, $size > 40 ? 3 : 1);
}

# nginx_opt_parse(name, &parent, &in, [regex], [&validator])
# Updates the config with input from nginx_opt_input
sub nginx_opt_parse
{
my ($name, $parent, $in, $regexp, $vfunc) = @_;
return undef if (!&supported_directive($name, $parent));
$in ||= \%in;
if ($in->{$name."_def"}) {
	&save_directive($parent, $name, [ ]);
	}
else {
	my $v = $in->{$name};
	$v eq '' && &error(&text('opt_missing', $text{'opt_'.$name}));
	!$regexp || $v =~ /$regexp/ || &error($text{'opt_e'.$name});
	my $err = $vfunc && &$vfunc($v, $name);
	$err && &error($err);
	&save_directive($parent, $name, [ $v ]);
	}
}

1;

