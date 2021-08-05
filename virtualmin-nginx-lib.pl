# Common functions for NginX config file

use strict;
use warnings;
no warnings 'recursion';
use Socket;

BEGIN { push(@INC, ".."); };
eval "use WebminCore;";
&init_config();
our %access = &get_module_acl();
our ($get_config_cache, $get_config_parent_cache, %list_directives_cache,
     @list_modules_cache, @open_config_files);
our (%config, %text, %in, $module_root_directory);

my @lock_all_config_files_cache;

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
				     'type' => 1,
				     'file' => $config{'nginx_config'},
				     'indent' => -1,
				     'line' => 0,
				     'eline' => 0 };
	foreach my $c (@{$get_config_parent_cache->{'members'}}) {
		if ($c->{'file'} eq $get_config_parent_cache->{'file'} &&
		    $c->{'eline'} > $get_config_parent_cache->{'eline'}) {
			$get_config_parent_cache->{'eline'} = $c->{'eline'}+1;
			}
		}
	}
return $get_config_parent_cache;
}

# flush_config_cache()
# Delete all in-memory config caches
sub flush_config_cache
{
undef($get_config_parent_cache);
undef($get_config_cache);
}

# read_config_file(file, [preserve-includes])
# Returns an array ref of nginx config objects
sub read_config_file
{
my ($file, $noinc) = @_;
my $link = &resolve_links($file);
$link || &error("Dangling link $file");
$file = $link;
my @rv = ( );
my $addto = \@rv;
my @stack = ( );
my $lnum = 0;
my $fh = "CFILE".int(rand(1000000));
&open_readfile($fh, $file) || return [];
my @lines = <$fh>;
close($fh);
while(@lines) {
	my $l = shift(@lines);
	$l =~ s/#.*$//;
	my $slnum = $lnum;

	# If line doesn't end with { } or ; , it must be continued on the
	# next line
	while($l =~ /\S/ && $l !~ /[\{\}\;]\s*$/ && @lines) {
		my $nl = shift(@lines);
		if ($nl =~ /\S/) {
			$nl =~ s/#.*$//;
			$l .= " ".$nl;
			}
		$lnum++;
		}

	if ($l =~ /^\s*if\s*\((.*)\)\s*\{\s*$/) {
		# Start of an if statement
		my $ns = { 'name' => 'if',
			   'type' => 2,
			   'indent' => scalar(@stack),
			   'file' => $file,
			   'line' => $slnum,
			   'eline' => $lnum,
			   'members' => [ ] };
		my $value = $1;
		$ns->{'words'} = [ &split_words(" ".$value) ];
		$ns->{'value'} = $ns->{'words'}->[0];
		push(@stack, $addto);
		push(@$addto, $ns);
		$addto = $ns->{'members'};
		}
	elsif ($l =~ /^\s*(\S+)(\s*.*)\{\s*$/) {
		# Start of a section
		my $ns = { 'name' => $1,
			   'type' => 1,
			   'indent' => scalar(@stack),
			   'file' => $file,
			   'line' => $slnum,
			   'eline' => $lnum,
			   'members' => [ ] };
		my $value = $2;
		$ns->{'words'} = [ &split_words($value) ];
		$ns->{'value'} = $ns->{'words'}->[0];
		push(@stack, $addto);
		push(@$addto, $ns);
		$addto = $ns->{'members'};
		}
	elsif ($l =~ /^\s*}/ && @stack) {
		# End of a section
		$addto = pop(@stack);
		$addto->[@$addto-1]->{'eline'} = $lnum;
		}
	elsif ($l =~ /^\s*(\S+)((\s+("([^"]*)"|'([^']*)'|[^ ;]+))*);/) {
		# Found a directive
		my ($name, $value) = ($1, $2);
		my @words = &split_words($value);
		if ($name eq "include" && !$noinc) {
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
				    'line' => $slnum,
				    'eline' => $lnum };
			push(@$addto, $dir);
                        if (@stack) {
                                my $lastaddto = $stack[$#stack];
                                $lastaddto->[@$lastaddto - 1]->{'eline'} = $lnum;
                                }
			}
		}
	elsif ($l =~ /\S/) {
		print STDERR "Invalid Nginx config line $l at $lnum\n";
		}
	$lnum++;
	}
return \@rv;
}

# split_words(string)
# Convert a string of bare or quoted words into a list
sub split_words
{
my ($value) = @_;
my @words;
while($value =~ s/^\s+"([^"]+)"// ||
      $value =~ s/^\s+'([^']+)'// ||
      $value =~ s/^\s+(\S+)//) {
	push(@words, $1);
	}
return @words;
}

# get_add_to_file(name)
# Returns the file to add new servers to, if any
sub get_add_to_file
{
my ($name) = @_;
if (!$config{'add_to'}) {
	return undef;
	}
elsif (-d $config{'add_to'}) {
	$name =~ s/[^a-zA-Z0-9\.\_\-]//g;
	if ($name) {
		return $config{'add_to'}."/".$name.".conf";
		}
	}
else {
	return $config{'add_to'};
	}
return undef;
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
my @rv = map { $_->{'words'}->[0] || $_->{'value'} } &find($name, $conf);
return wantarray ? @rv : $rv[0];
}

# find_recursive(name, [&config|&parent])
# Returns all objects under some parent with the given name
sub find_recursive
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
	if ($c->{'type'}) {
		push(@rv, &find_recursive($name, $c));
		}
        }
return wantarray ? @rv : $rv[0];
}

# save_directive(&parent, name|&oldobjects, &newvalues|&newobjects, [&before])
# Updates the values of some named directive
sub save_directive
{
my ($parent, $name_or_oldstructs, $values, $before) = @_;
$values = [ $values ] if (!ref($values));
my $oldstructs = ref($name_or_oldstructs) ? $name_or_oldstructs :
			[ &find($name_or_oldstructs, $parent) ];
my $name = !ref($name_or_oldstructs) ? $name_or_oldstructs :
	   @$name_or_oldstructs ? $name_or_oldstructs->[0]->{'name'} : undef;
my $newstructs = [ map { &value_to_struct($name, $_) } @$values ];
for(my $i=0; $i<@$newstructs || $i<@$oldstructs; $i++) {
	my $o = $i<@$oldstructs ? $oldstructs->[$i] : undef;
	my $n = $i<@$newstructs ? $newstructs->[$i] : undef;
	my $file = $o ? $o->{'file'} :
		   $n && $n->{'file'} ? $n->{'file'} : $parent->{'file'};
	my $lref = &read_file_lines($file);
	push(@open_config_files, $file);
	if ($i<@$newstructs && $i<@$oldstructs) {
		# Updating some directive
		my $olen = $o->{'eline'} - $o->{'line'} + 1;
		my @lines = &make_directive_lines($n, $parent->{'indent'}+1);
		$o->{'name'} = $n->{'name'};
		$o->{'value'} = $n->{'words'}->[0];
		$o->{'words'} = $n->{'words'};
		splice(@$lref, $o->{'line'}, $olen, @lines);
		if ($olen != scalar(@lines)) {
			# Renumber directives
			&renumber($file, $o->{'line'}, $olen - scalar(@lines));
			$o->{'eline'} = $o->{'line'} + scalar(@lines) - 1;
			}
		}
	elsif ($i<@$newstructs) {
		# Adding a directive
		my @lines;
		$n->{'value'} = $n->{'words'}->[0];
		if ($n->{'file'}) {
			# New file, add at start
			@lines = &make_directive_lines($n, 0);
			$n->{'line'} = 0;
			$n->{'eline'} = scalar(@lines) - 1;
			$n->{'indent'} = 0 if ($n->{'type'});
			&recursive_set_file($n, $n->{'file'}, $n->{'line'});
			unshift(@{$parent->{'members'}}, $n);
			}
		elsif ($before) {
			# Insert into parent before some other directive
			@lines = &make_directive_lines(
					$n, $parent->{'indent'} + 1);
			$n->{'line'} = $before->{'line'};
			$n->{'eline'} = $n->{'line'} + scalar(@lines) - 1;
			&recursive_set_file($n, $file, $n->{'line'});
			&renumber($file, $n->{'line'}-1, scalar(@lines));
			$n->{'indent'} = $parent->{'indent'} + 1
				if ($n->{'type'});
			my $idx = &indexof($before, @{$parent->{'members'}});
			if ($idx >= 0) {
				splice(@{$parent->{'members'}}, $idx, 0, $n);
				}
			else {
				push(@{$parent->{'members'}}, $n);
				}
			}
		else {
			# Insert into parent at end
			@lines = &make_directive_lines(
					$n, $parent->{'indent'} + 1);
			$n->{'line'} = $parent->{'eline'};
			$n->{'eline'} = $n->{'line'} + scalar(@lines) - 1;
			&recursive_set_file($n, $file, $n->{'line'});
			&renumber($file, $parent->{'eline'}-1, scalar(@lines));
			$n->{'indent'} = $parent->{'indent'} + 1
				if ($n->{'type'});
			push(@{$parent->{'members'}}, $n);
			}
		splice(@$lref, $n->{'line'}, 0, @lines);
		}
	elsif ($i<@$oldstructs) {
		# Removing a directive
		my $olen = $o->{'eline'} - $o->{'line'} + 1;
		splice(@$lref, $o->{'line'}, $olen);
		my $idx = &indexof($o, @{$parent->{'members'}});
		if ($idx >= 0) {
			splice(@{$parent->{'members'}}, $idx, 1);
			}
		&renumber($file, $o->{'line'}, -$olen);
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

# recursive_set_file(&parent, filename, start-line)
# Sets the file on some object and all children
sub recursive_set_file
{
my ($parent, $file, $line) = @_;
$parent->{'file'} ||= $file;
$parent->{'line'} ||= $line;
$parent->{'eline'} ||= $parent->{'line'};
if ($parent->{'type'}) {
	my $n = 1;
	foreach my $dir (@{$parent->{'members'}}) {
		&recursive_set_file($dir, $file, $parent->{'line'} + $n);
		$n += ($dir->{'eline'} - $dir->{'line'} + 1);
		}
	$parent->{'eline'} = $parent->{'line'} + $n;
	}
}

# flush_config_file_lines([&parent])
# Flush all lines in the current config
sub flush_config_file_lines
{
my ($parent) = @_;
foreach my $f (&unique(@open_config_files)) {
	&flush_file_lines($f);
	}
@open_config_files = ( );
}

# lock_all_config_files([&parent])
# Locks all files used in the current config
sub lock_all_config_files
{
my ($parent) = @_;
@lock_all_config_files_cache = &get_all_config_files($parent);
foreach my $f (@lock_all_config_files_cache) {
	&lock_file($f);
	}
}

# unlock_all_config_files([&parent])
# Un-locks all files used in the current config
sub unlock_all_config_files
{
my ($parent) = @_;
foreach my $f (reverse(@lock_all_config_files_cache)) {
	&unlock_file($f);
	}
@lock_all_config_files_cache = ();
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
my @w = @{$dir->{'words'}};
if ($dir->{'type'}) {
	# Multi-line
	if ($dir->{'name'} eq 'if') {
		push(@rv, $dir->{'name'}.' ('.&join_words(@w).') {');
		}
	else {
		push(@rv, $dir->{'name'}.(@w ? " ".&join_words(@w) : "")." {");
		}
	foreach my $m (@{$dir->{'members'}}) {
		push(@rv, &make_directive_lines($m, 1));
		}
	push(@rv, "}");
	}
else {
	# Single line
	push(@rv, $dir->{'name'}." ".&join_words(@w).";");
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
	$value->{'name'} ||= $name;
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
			  'context' => $context eq '-' ? undef :
					[ split(/,/, $context) ],
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
				'http_ssi', 'http_userid', 'http_index',
				'http_uwsgi', 'http_log', 'core' );
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
return 0 if ($dir->{'context'} && $parent &&
	     &indexof($parent->{'name'}, @{$dir->{'context'}}) < 0);
my @mods = &list_nginx_modules();
#return 0 if (&indexof($dir->{'module'}, @mods) < 0);
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

# nginx_opt_input(name, &parent, size, prefix, suffix, [multi-value])
# Returns HTML for an optional text field
sub nginx_opt_input
{
my ($name, $parent, $size, $prefix, $suffix, $multi) = @_;
return undef if (!&supported_directive($name, $parent));
my $obj = &find($name, $parent);
my $value = $multi ? &join_words(@{$obj->{'words'}}) : $obj->{'value'};
my $def = &get_default($name);
return &ui_table_row($text{'opt_'.$name},
	&ui_opt_textbox($name, $value, $size,
			$text{'default'}.($def ? " ($def)" : ""), $prefix).
	$suffix, $size > 40 ? 3 : 1);
}

# nginx_opt_parse(name, &parent, &in, [regex], [&validator], [multi-value])
# Updates the config with input from nginx_opt_input
sub nginx_opt_parse
{
my ($name, $parent, $in, $regexp, $vfunc, $multi) = @_;
return undef if (!&supported_directive($name, $parent));
$in ||= \%in;
if ($in->{$name."_def"}) {
	&save_directive($parent, $name, [ ]);
	}
else {
	my $v = $in->{$name};
	my @w = $multi ? &split_quoted_string($v) : ( $v );
	$v eq '' && &error(&text('opt_missing', $text{'opt_'.$name}));
	!$regexp || $v =~ /$regexp/ || &error($text{'opt_e'.$name} || $name);
	my $err = $vfunc && &$vfunc($v, $name);
	$err && &error($err);
	&save_directive($parent, $name, [ { 'name' => $name,
					    'words' => \@w } ]);
	}
}

# nginx_text_input(name, &parent, size, suffix, [multi-value])
# Returns HTML for a non-optional text field
sub nginx_text_input
{
my ($name, $parent, $size, $suffix, $multi) = @_;
return undef if (!&supported_directive($name, $parent));
my $obj = &find($name, $parent);
my $value = $multi ? &join_words(@{$obj->{'words'}}) : $obj->{'value'};
$suffix ||= "";
return &ui_table_row($text{'opt_'.$name},
	&ui_textbox($name, $value, $size).$suffix, $size > 40 ? 3 : 1);
}

# nginx_text_parse(name, &parent, &in, [regex], [&validator], [multi-value])
# Updates the config with input from nginx_text_input
sub nginx_text_parse
{
my ($name, $parent, $in, $regexp, $vfunc, $multi) = @_;
return undef if (!&supported_directive($name, $parent));
$in ||= \%in;
my $v = $in->{$name};
my @w = $multi ? &split_quoted_string($v) : ( $v );
foreach my $wv (@w) {
	$wv eq '' && &error(&text('opt_missing', $text{'opt_'.$name}));
	!$regexp || $wv =~ /$regexp/ || &error($text{'opt_e'.$name});
	my $err = $vfunc && &$vfunc($wv, $name);
	$err && &error($err);
	}
&save_directive($parent, $name, [ { 'name' => $name,
				    'words' => \@w } ]);
}

# nginx_error_log_input(name, &parent)
# Returns HTML specifically for setting the error_log directive
sub nginx_error_log_input
{
my ($name, $parent) = @_;
return undef if (!&supported_directive($name, $parent));
my $obj = &find($name, $parent);
my $def = $parent->{'name'} eq 'server' ? $text{'opt_global'}
					: &get_default($name);
$def =~ s/^\$\{prefix\}\///;
return &ui_table_row($text{'opt_'.$name},
	&ui_radio($name."_def", $obj ? 0 : 1,
		  [ [ 1, $text{'default'}.($def ? " ($def)" : "")."<br>" ],
		    [ 0, $text{'logs_file'} ] ])." ".
	&ui_textbox($name, $obj ? $obj->{'words'}->[0] : undef, 40)." ".
	$text{'logs_level'}." ".
	&ui_select($name."_level", $obj ? $obj->{'words'}->[1] : "",
		   [ [ "", "&lt;$text{'default'}&gt;" ],
		     "debug", "info", "notice", "warn", "error", "crit" ]));
}

# nginx_error_log_parse(name, &parent, &in)
# Validate input from nginx_error_log_input
sub nginx_error_log_parse
{
my ($name, $parent, $in) = @_;
return undef if (!&supported_directive($name, $parent));
$in ||= \%in;
if ($in->{$name."_def"}) {
	&save_directive($parent, $name, [ ]);
        }
else {
	$in->{$name} || &error(&text('opt_missing', $text{'opt_'.$name}));
	$in->{$name} =~ /^\/\S+$/ || &error($text{'opt_e'.$name});
	my @w = ( $in->{$name} );
	push(@w, $in->{$name."_level"}) if ($in->{$name."_level"});
	&save_directive($parent, $name, [ { 'name' => $name,
					    'words' => \@w } ]);
	}
}

# nginx_access_log_input(name, &parent)
# Returns HTML specifically for setting the access_log directive
sub nginx_access_log_input
{
my ($name, $parent) = @_;
return undef if (!&supported_directive($name, $parent));
my $obj = &find($name, $parent);
my $mode = !$obj ? 1 : $obj->{'value'} eq 'off' ? 2 : 0;
my $buffer = $mode == 0 && $obj->{'words'}->[2] =~ /buffer=(\S+)/ ? $1 : "";
my $def = $parent->{'name'} eq 'server' ? $text{'opt_global'}
					: &get_default($name);
return &ui_table_row($text{'opt_'.$name},
	&ui_radio($name."_def", $mode,
		[ [ 1, $text{'default'}.($def ? " ($def)" : "")."<br>" ],
		  [ 2, $text{'logs_disabled'}."<br>" ],
		  [ 0, $text{'logs_file'} ] ])." ".
	&ui_textbox($name, $mode == 0 ? $obj->{'words'}->[0] : undef, 40)." ".
	$text{'logs_format'}." ".
	&ui_select($name."_format", $mode == 0 ? $obj->{'words'}->[1] : "",
		   [ [ "", "&lt;$text{'default'}&gt;" ],
		     &list_log_formats($parent) ])." ".
	$text{'logs_buffer'}." ".
	&ui_textbox($name."_buffer", $buffer, 6));
}

# nginx_access_log_parse(name, &parent, &in)
# Validate input from nginx_access_log_input
sub nginx_access_log_parse
{
my ($name, $parent, $in) = @_;
return undef if (!&supported_directive($name, $parent));
$in ||= \%in;
if ($in->{$name."_def"} == 1) {
	&save_directive($parent, $name, [ ]);
        }
elsif ($in->{$name."_def"} == 2) {
	&save_directive($parent, $name, [ "off" ]);
	}
else {
	$in->{$name} || &error(&text('opt_missing', $text{'opt_'.$name}));
	$in->{$name} =~ /^\/\S+$/ || &error($text{'opt_e'.$name});
	my @w = ( $in->{$name} );
	push(@w, $in->{$name."_format"}) if ($in->{$name."_format"});
	my $buffer = $in->{$name."_buffer"};
	if ($buffer) {
		$buffer =~ /^\d+[bKMGT]?$/i || &error($text{'logs_ebuffer'});
		push(@w, "buffer=$buffer");
		}
	&save_directive($parent, $name, [ { 'name' => $name,
					    'words' => \@w } ]);
	}
}

# nginx_user_input(name, &parent)
# Returns HTML for a user field with an optional group
sub nginx_user_input
{
my ($name, $parent) = @_;
return undef if (!&supported_directive($name, $parent));
my $obj = &find($name, $parent);
my $def = &get_default($name);
return &ui_table_row($text{'opt_'.$name},
	&ui_radio($name."_def", $obj ? 0 : 1,
		  [ [ 1, $text{'default'}.($def ? " ($def)" : "")."<br>" ],
		    [ 0, $text{'misc_username'} ] ])." ".
	&ui_user_textbox($name, $obj ? $obj->{'words'}->[0] : "")." ".
	$text{'misc_group'}." ".
	&ui_group_textbox($name."_group", $obj ? $obj->{'words'}->[1] : ""));
}

# nginx_user_parse(name, &parent, &in)
# Validate input from nginx_user_input
sub nginx_user_parse
{
my ($name, $parent, $in) = @_;
return undef if (!&supported_directive($name, $parent));
$in ||= \%in;
if ($in->{$name."_def"} == 1) {
	&save_directive($parent, $name, [ ]);
        }
else {
	$in->{$name} || &error(&text('opt_missing', $text{'opt_'.$name}));
	defined(getpwnam($in->{$name})) || &error($text{'misc_euser'});
	my @w = ( $in->{$name} );
	my $group = $in->{$name."_group"};
	if ($group) {
		defined(getgrnam($group)) || &error($text{'misc_egroup'});
		push(@w, $group);
		}
	&save_directive($parent, $name, [ { 'name' => $name,
					    'words' => \@w } ]);
	}
}

# nginx_logformat_input(name, parent)
# Returns HTML for entering multiple log formats
sub nginx_logformat_input
{
my ($name, $parent) = @_;
return undef if (!&supported_directive($name, $parent));
my @obj = &find($name, $parent);
my $ftable = &ui_columns_start([ $text{'logs_fname'},
				 $text{'logs_ftext'} ]);
my $i = 0;
foreach my $o (@obj, { 'words' => [ ] }) {
	my @w = @{$o->{'words'}};
	$ftable .= &ui_columns_row([
		&ui_textbox($name."_name_$i", shift(@w), 20),
		&ui_textbox($name."_text_$i", join(" ", @w), 60),
		]);
	$i++;
	}
$ftable .= &ui_columns_end();
return &ui_table_row($text{'opt_'.$name}, $ftable, 3);
}

# nginx_logformat_parse(name, &parent, &in)
# Validate input from nginx_logformat_input
sub nginx_logformat_parse
{
my ($name, $parent, $in) = @_;
return undef if (!&supported_directive($name, $parent));
$in ||= \%in;
my @obj;
for(my $i=0; defined(my $fname = $in{$name."_name_$i"}); $i++) {
	next if (!$fname);
	my $ftext = $in{$name."_text_$i"};
	$fname =~ /^[a-zA-Z0-9\-\.\_]+$/ ||
		&error(&text('logs_efname', $fname));
	$ftext =~ /\S/ || &error(&text('logs_etext', $fname));
	push(@obj, { 'name' => $name,
		     'words' => [ $fname, $ftext ] });
	}
&save_directive($parent, $name, \@obj);
}

# nginx_multi_input(name, &parent, &options)
# Returns HTML for selecting multiple options
sub nginx_multi_input
{
my ($name, $parent, $opts) = @_;
return undef if (!&supported_directive($name, $parent));
my $def = &get_default($name);
my $obj = &find($name, $parent);
return &ui_table_row($text{'opt_'.$name},
        &ui_radio($name."_def", $obj ? 0 : 1,
		  [ [ 1, $text{'default'}.($def ? " ($def)" : "") ],
		    [ 0, $text{'opt_selected'}."<br>" ] ])." ".
	&ui_select($name, $obj ? $obj->{'words'} : [ ], $opts, scalar(@$opts),
		   1, 1));
}

# nginx_multi_parse(name, &parent)
# Validate input from nginx_multi_input
sub nginx_multi_parse
{
my ($name, $parent, $in) = @_;
return undef if (!&supported_directive($name, $parent));
$in ||= \%in;
if ($in->{$name."_def"} == 1) {
        &save_directive($parent, $name, [ ]);
        }
else {
	my @w = split(/\0/, $in->{$name});
	@w || &error(&text('opt_missing', $text{'opt_'.$name}));
	&save_directive($parent, $name, [ { 'name' => $name,
					    'words' => \@w } ]);
	}
}

# nginx_param_input(name, &parent, [name-text, value-text])
# Returns HTML for entering multiple name value paramters
sub nginx_param_input
{
my ($name, $parent, $ntext, $vtext) = @_;
$ntext ||= $text{'fcgi_pname'};
$vtext ||= $text{'fcgi_pvalue'};
return undef if (!&supported_directive($name, $parent));
my @obj = &find($name, $parent);
my $ftable = &ui_columns_start([ $ntext, $vtext ]);
my $i = 0;
foreach my $o (@obj, { 'words' => [ ] }) {
	my @w = @{$o->{'words'}};
	$ftable .= &ui_columns_row([
		&ui_textbox($name."_name_$i", shift(@w), 20),
		&ui_textbox($name."_value_$i", join(" ", @w), 60),
		]);
	$i++;
	}
$ftable .= &ui_columns_end();
return &ui_table_row($text{'opt_'.$name}, $ftable, 3);
}

# nginx_params_parse(name, &parent, &in)
# Parses inputs from nginx_param_input
sub nginx_params_parse
{
my ($name, $parent, $in) = @_;
return undef if (!&supported_directive($name, $parent));
$in ||= \%in;
my @obj;
for(my $i=0; defined(my $pname = $in{$name."_name_$i"}); $i++) {
	next if (!$pname);
	my $pvalue = $in{$name."_value_$i"};
	$pname =~ /^[a-zA-Z0-9\-\.\_]+$/ ||
		&error(&text('fcgi_epname', $pname));
	$pvalue =~ /\S/ || &error(&text('fcgi_epvalue', $pname));
	push(@obj, { 'name' => $name,
		     'words' => [ $pname, $pvalue ] });
	}
&save_directive($parent, $name, \@obj);
}

# nginx_opt_list_input(name, &parent, size, prefix, suffix)
# Returns HTML for an optional text field with multiple values
sub nginx_opt_list_input
{
my ($name, $parent, $size, $prefix, $suffix) = @_;
return undef if (!&supported_directive($name, $parent));
my $obj = &find($name, $parent);
my $value = $obj ? join(" ", @{$obj->{'words'}}) : "";
my $def = &get_default($name);
return &ui_table_row($text{'opt_'.$name},
	&ui_opt_textbox($name, $value, $size,
			$text{'default'}.($def ? " ($def)" : ""), $prefix).
	$suffix, $size > 40 ? 3 : 1);
}

# nginx_opt_list_parse(name, &parent, &in, [regex], [&validator])
# Updates the config with input from nginx_opt_list_input
sub nginx_opt_list_parse
{
my ($name, $parent, $in, $regexp, $vfunc) = @_;
return undef if (!&supported_directive($name, $parent));
$in ||= \%in;
if ($in->{$name."_def"}) {
	&save_directive($parent, $name, [ ]);
	}
else {
	my @v = &split_quoted_string($in->{$name});
	@v || &error(&text('opt_missing', $text{'opt_'.$name}));
	foreach my $v (@v) {
		!$regexp || $v =~ /$regexp/ ||
			&error(&text('opt_e'.$name, $v) || $name);
		my $err = $vfunc && &$vfunc($v, $name);
		$err && &error($err);
		}
	&save_directive($parent, $name, [ { 'name' => $name,
					    'words' => \@v } ]);
	}
}

# nginx_textarea_input(name, &parent, width, height)
# Returns HTML for entering the values of multiple directives of the same type,
# in a text area
sub nginx_textarea_input
{
my ($name, $parent, $width, $height) = @_;
return undef if (!&supported_directive($name, $parent));
my @obj = &find($name, $parent);
return &ui_table_row($text{'opt_'.$name},
		     &ui_textarea($name,
			join("\n", map { $_->{'words'}->[0] } @obj),
			$height, $width), 3);
}

# nginx_textarea_parse(name, &parent, &in, [&regex], [&validator])
# Parses inputs from nginx_param_input
sub nginx_textarea_parse
{
my ($name, $parent, $in, $regexp, $vfunc) = @_;
return undef if (!&supported_directive($name, $parent));
$in ||= \%in;
my @obj;
foreach my $v (split(/\r?\n/, $in->{$name})) {
	!$regexp || $v =~ /$regexp/ ||
		&error(&text('opt_e'.$name, $v) || $name);
	my $err = $vfunc && &$vfunc($v, $name);
	$err && &error($err);
	push(@obj, { 'name' => $name,
		     'words' => [ $v ] });
	}
&save_directive($parent, $name, \@obj);
}

# nginx_access_input(name1, name2, &parent)
# Returns HTML for setting allow and deny directives
sub nginx_access_input
{
my ($allow, $deny, $parent) = @_;
return undef if (!&supported_directive($allow, $parent));
my @obj = sort { $a->{'line'} <=> $b->{'line'} }
	       (&find($allow, $parent), &find($deny, $parent));
my $table = &ui_columns_start([ $text{'access_mode'},
				$text{'access_value'} ], 100, 0,
			      [ "nowrap", "nowrap" ]);
my $i =0;
foreach my $o (@obj, { }, { }) {
	my $v = $o->{'value'};
	$v = "" if (lc($v) eq "all");
	$table .= &ui_columns_row([
		&ui_select($allow."_mode_".$i,
			   $o->{'name'},
			   [ [ "", "&nbsp;" ],
			     [ "allow", $text{'access_allow'} ],
			     [ "deny", $text{'access_deny'} ] ]),
		&ui_opt_textbox($allow."_addr_".$i, $v, 30,
			        $text{'access_all'}, $text{'access_addr'}),
		]);
	$i++;
	}
$table .= &ui_columns_end();
return &ui_table_row($text{'opt_'.$allow}, $table, 3);
}

# nginx_access_parse(name1, name2, &parent, &in)
# Parse inputs from nginx_access_input
sub nginx_access_parse
{
my ($allow, $deny, $parent, $in) = @_;
return undef if (!&supported_directive($allow, $parent));
$in ||= \%in;
my @obj;
my @old = sort { $a->{'line'} <=> $b->{'line'} }
               (&find($allow, $parent), &find($deny, $parent));
for(my $i=0; defined(my $mode = $in->{$allow."_mode_".$i}); $i++) {
	next if (!$mode);
	my $addr;
	if ($in->{$allow."_addr_".$i."_def"}) {
		$addr = "all";
		}
	else {
		$addr = $in->{$allow."_addr_".$i};
		$addr || &error(&text('access_eaddrnone', $i+1));
		&check_ipaddress($addr) ||
		   $addr =~ /^(\S+)\/(\d+)$/ &&
		     &check_ipaddress("$1") && $2 > 0 && $2 <= 32 ||
			&error(&text('access_eaddr', $addr));
		}
	push(@obj, { 'name' => $mode,
		     'words' => [ $addr ] });
	}
&save_directive($parent, \@old, \@obj);
}

# nginx_realm_input(name, &parent)
# Returns HTML for entering an authentication realm
sub nginx_realm_input
{
my ($name, $parent) = @_;
return undef if (!&supported_directive($name, $parent));
my $value = &find_value($name, $parent);
my $def = &get_default($name);
return &ui_table_row($text{'opt_'.$name},
	&ui_radio($name."_def",
		  !$value ? 1 : $value eq "off" ? 2 : 0,
		  [ [ 1, $text{'default'}.($def ? " ($def)" : "") ],
		    [ 2, $text{'access_off'} ],
		    [ 0, $text{'access_realm'}." ".
			 &ui_textbox($name, $value eq "off" ? "" : $value, 40) ]
		  ]), 3);
}

# nginx_realm_parse(name, &parent, &in)
# Updates the config with input from nginx_realm_input
sub nginx_realm_parse
{
my ($name, $parent, $in) = @_;
return undef if (!&supported_directive($name, $parent));
$in ||= \%in;
if ($in->{$name."_def"} == 1) {
	&save_directive($parent, $name, [ ]);
	}
elsif ($in->{$name."_def"} == 2) {
	&save_directive($parent, $name, [ "off" ]);
	}
else {
	my $v = $in->{$name};
	$v eq '' && &error(&text('opt_missing', $text{'opt_'.$name}));
	&save_directive($parent, $name, [ $v ]);
	}
}

# nginx_passfile_input(name, &parent, server-id, path)
# Returns HTML for a password file field
sub nginx_passfile_input
{
my ($name, $parent, $id, $path) = @_;
my $value = &find_value($name, $parent);
my $edit;
if ($value =~ /^\/\S/) {
	$edit = " <a href='list_users.cgi?file=".&urlize($value).
		"&id=".&urlize($id)."&path=".&urlize($path)."'>".
		$text{'access_edit'}."</a>";
	}
return &nginx_opt_input($name, $parent, 50, $text{'access_pfile'},
			&file_chooser_button($name).$edit);
}

# nginx_passfile_parse(name, &parent, &in)
# Parse input from nginx_passfile_input
sub nginx_passfile_parse
{
my ($name, $parent, $in) = @_;
$in ||= \%in;
$in->{$name."_def"} || &can_directory($in->{$name}) ||
	&error(&text('access_ecannot',
		     "<tt>".&html_escape($in->{$name})."</tt>",
		     "<tt>".&html_escape($access{'root'})."</tt>"));
&nginx_opt_parse($name, $parent, $in, undef,
		 sub { return $_[0] !~ /^\// ? $text{'access_eabsolute'} :
			      -d $_[0] ? $text{'access_edir'} : undef });
}

# nginx_rewrite_input(name, &parent)
# Returns HTML for setting rewrite directives
sub nginx_rewrite_input
{
my ($name, $parent) = @_;
return undef if (!&supported_directive($name, $parent));
my @obj = &find($name, $parent);
my $table = &ui_columns_start([ $text{'rewrite_from'},
				$text{'rewrite_to'},
				$text{'rewrite_flag'} ], 100, 0,
			      [ "nowrap", "nowrap" ]);
my $i =0;
foreach my $o (@obj, { }, { }) {
	$table .= &ui_columns_row([
		&ui_textbox($name."_from_$i", $o->{'words'}->[0], 30),
		&ui_textbox($name."_to_$i", $o->{'words'}->[1], 40),
		&ui_select($name."_flag_$i", $o->{'words'}->[2],
			   [ map { [ $_, $text{'rewrite_'.$_} ] }
				 ('last', 'break', 'redirect', 'permanent') ]),
		]);
	$i++;
	}
$table .= &ui_columns_end();
return &ui_table_row($text{'opt_'.$name}, $table, 3);
}

# nginx_rewrite_parse(name1, name2, &parent, &in)
# Parse inputs from nginx_rewrite_input
sub nginx_rewrite_parse
{
my ($name, $parent, $in) = @_;
return undef if (!&supported_directive($name, $parent));
$in ||= \%in;
my @obj;
for(my $i=0; defined(my $from = $in->{$name."_from_".$i}); $i++) {
	next if (!$from);
	$from =~ /^\S+$/ || &error(&text('rewrite_efrom', $i+1));
	my $to = $in->{$name."_to_".$i};
	$to =~ /^\S+$/ || &error(&text('rewrite_eto', $i+1));
	my $flag = $in->{$name."_flag_".$i};
	push(@obj, { 'name' => $name,
		     'words' => [ $from, $to, $flag ] });
	}
&save_directive($parent, $name, \@obj);
}

# list_log_formats([&server])
# Returns a list of all log format names
sub list_log_formats
{
my ($server) = @_;
my $parent = &get_config_parent();
my @rv = ( "combined" );
my $http = &find("http", $parent);
foreach my $l (&find("log_format", $http)) {
	push(@rv, $l->{'words'}->[0]);
	}
if ($server && $server->{'name'} eq 'server') {
	foreach my $l (&find("log_format", $server)) {
		push(@rv, $l->{'words'}->[0]);
		}
	}
return &unique(@rv);
}

# is_nginx_running()
# Returns the PID if nginx is running
sub is_nginx_running
{
my $parent = &get_config_parent();
my $pidfile = &find_value("pid", $parent);
$pidfile ||= &get_default("pid");
$pidfile ||= $config{'pid_file'};
if ($pidfile =~ /^\//) {
	return &check_pid_file($pidfile);
	}
else {
	my ($pid) = &find_byname("nginx");
	return $pid;
	}
}

# stop_nginx()
# Attempt to stop nginx, return an error on failure or undef on success
sub stop_nginx
{
my $out = &backquote_logged("$config{'stop_cmd'} 2>&1 </dev/null");
return $? ? $out : undef;
}

# start_nginx()
# Attempt to start nginx, return an error on failure or undef on success
sub start_nginx
{
my $out = &backquote_logged("$config{'start_cmd'} 2>&1 </dev/null");
return $? ? $out : undef;
}

# apply_nginx()
# Attempt to apply the nginx config, return an error on failure or undef
# on success
sub apply_nginx
{
my $out = &backquote_logged("$config{'apply_cmd'} 2>&1 </dev/null");
return $? ? $out : undef;
}

# test_config()
# Returns an error message if the config is invalid
sub test_config
{
&clean_language() if (defined(&clean_language));
my $out = &backquote_logged("$config{'nginx_cmd'} -t 2>&1 </dev/null");
&reset_environment() if (defined(&clean_language));
return $? || $out !~ /syntax\s+is\s+ok/ ? $out : undef;
}

# find_server(id)
# Convenience function to find an HTTP server object with some ID
sub find_server
{
my ($id) = @_;
my $conf = &get_config();
my $http = &find("http", $conf);
return undef if (!$http);
my @servers = &find("server", $http);
my ($idname, $idrootdir) = split(/;/, $id);
foreach my $s (@servers) {
	my $name = &find_value("server_name", $s);
	next if ($idname ne $name);
	my $rootdir = &find_value("root", $s);
	if (!$rootdir) {
		my @locs = &find("location", $s);
		my ($rootloc) = grep { $_->{'value'} eq '/' } @locs;
		$rootdir = $rootloc ? &find_value("root", $rootloc) : "";
		}
	next if ($idrootdir ne $rootdir);
	return $s;
	}
return undef;
}

# server_id(&server)
# Given a server, return a unique ID for it as used by the module
sub server_id
{
my ($s) = @_;
my $name = &find_value("server_name", $s);
my $rootdir = &find_value("root", $s);
if (!$rootdir) {
	my @locs = &find("location", $s);
	my ($rootloc) = grep { $_->{'value'} eq '/' } @locs;
	if ($rootloc) {
		$rootdir = &find_value("root", $rootloc);
		}
	$rootdir ||= "";
	}
return $name.";".$rootdir;
}

# find_domain_server(&domain)
# Returns the object for a server for some domain
sub find_domain_server
{
my ($d) = @_;
my $conf = &get_config();
my $http = &find("http", $conf);
return undef if (!$http);
my @servers = &find("server", $http);
foreach my $s (@servers) {
	my $obj = &find("server_name", $s);
	foreach my $name (@{$obj->{'words'}}) {
		if (lc($name) eq lc($d->{'dom'}) ||
		    lc($name) eq "www.".lc($d->{'dom'}) ||
		    lc($name) eq "*.".lc($d->{'dom'})) {
			return $s;
			}
		}
	}
return undef;
}

# find_location(&server, path)
# Finds the location with some path in a given server object
sub find_location
{
my ($server, $path) = @_;
foreach my $l (&find("location", $server)) {
	my @w = @{$l->{'words'}};
	return $l if ($w[$#w] eq $path);
	}
return undef;
}

# split_ip_port(string)
# Given an ip:port pair as used in a listen directive, split them up
sub split_ip_port
{
my ($l) = @_;
if ($l =~ /^\d+$/) {
	return (undef, $l);
	}
elsif ($l =~ /^\[(\S+)\]:(\d+)$/) {
	return ($1, $2);
	}
elsif ($l =~ /^\[(\S+)\]$/) {
	return ($1, 80);
	}
elsif ($l =~ /^(\S+):(\d+)$/) {
	return ($1, $2);
	}
else {
	return ($l, 80);
	}
}

# server_desc(&server)
# Returns a description of a virtual host
sub server_desc
{
my ($server) = @_;
my $name = &find_value("server_name", $server);
return $name ? &text('server_desc', "<tt>".&html_escape($name)."</tt>")
	     : $text{'server_descnone'};
}

# location_desc(&server, &location)
# Returns a description of a location in a virtual host
sub location_desc
{
my ($server, $location) = @_;
my $name = &find_value("server_name", $server);
return $name ? &text('location_desc', "<tt>".&html_escape($name)."</tt>",
		     "<tt>".&html_escape($location->{'value'})."</tt>")
	     : &text('location_descnone',
		     "<tt>".&html_escape($location->{'value'})."</tt>");
}

# match_desc(string)
# Converts a location match type like ~ into a human-readable mode
sub match_desc
{
my ($m) = @_;
return $m eq "=" ? $text{'match_exact'} :
       $m eq "~" ? $text{'match_case'} :
       $m eq "~*" ? $text{'match_nocase'} :
       $m eq "^~" ? $text{'match_noregexp'} :
       $m eq "\@" ? $text{'match_named'} :
       $m eq "" ? $text{'match_default'} :
		  "Unknown match type $m";
}

sub list_match_types
{
return ("", "=", "~", "~*", "^~", "\@");
}

# create_server_link(&server)
# Creates a link from a directory like sites-enabled to sites-available for
# a new virtual host
sub create_server_link
{
my ($server) = @_;
if ($config{'add_link'}) {
	my $link = $server->{'file'};
	$link =~ s/^.*\///;
	$link = $config{'add_link'}."/".$link;
	&symlink_logged($server->{'file'}, $link);
	}
}

# delete_server_link(&server)
# Deletes the link from a directory like sites-enabled to sites-available for
# a virtual host being removed
sub delete_server_link
{
my ($server) = @_;
if ($config{'add_link'}) {
	my $file = $server->{'file'};
        my $short = $file;
        $short =~ s/^.*\///;
        opendir(LINKDIR, $config{'add_link'});
        foreach my $f (readdir(LINKDIR)) {
                if ($f ne "." && $f ne ".." &&
                    (&resolve_links($config{'add_link'}."/".$f) eq $file ||
                     $short eq $f)) {
                        &unlink_logged($config{'add_link'}."/".$f);
                        }
                }
        closedir(LINKDIR);
        }
}

# delete_server_file_if_empty(&server)
# If the file for a server is empty, delete it
sub delete_server_file_if_empty
{
my ($server) = @_;
my $lref = &read_file_lines($server->{'file'}, 1);
my $count = 0;
foreach my $l (@$lref) {
	$count++ if ($l =~ /\S/);
	}
if (!$count) {
	&unlink_logged($server->{'file'});
	}
}

# valid_cert_file(filename)
# Returns an error message if a cert file is invalid, or undef if OK
sub valid_cert_file
{
my ($file) = @_;
-r $file && !-d $file || return $text{'ssl_ecertfile'};
my $data = &read_file_contents($file);
my @lines = grep { /\S/ } split(/\r?\n/, $data);
my $begin = "-----BEGIN CERTIFICATE-----";
my $end = "-----END CERTIFICATE-----";
$data =~ /$begin/ ||
	return &text('ssl_ecertbegin', "-----BEGIN CERTIFICATE-----");
$data =~ /$end/ ||
	return &text('ssl_ecertend', "-----END CERTIFICATE-----");
for(my $i=0; $i<@lines; $i++) {
        $lines[$i] =~ /^-----(BEGIN|END)/ ||
            $lines[$i] =~ /^[A-Za-z0-9\+\/=]+$/ ||
		return &text('ssl_ecertline', $i+1);
        }
@lines > 4 || return &text('ssl_ecertlines', scalar(@lines));
return undef;
}

# valid_key_file(filename)
# Returns an error message if a key file is invalid, or undef if OK
sub valid_key_file
{
my ($file) = @_;
-r $file && !-d $file || return $text{'ssl_ekeyfile'};
my $data = &read_file_contents($file);
my @lines = grep { /\S/ } split(/\r?\n/, $data);
my $begin = "-----BEGIN (RSA )?PRIVATE KEY-----";
my $end = "-----END (RSA )?PRIVATE KEY-----";
$data =~ /$begin/ ||
	return &text('ssl_ekeybegin', "-----BEGIN PRIVATE KEY-----");
$data =~ /$end/ ||
	return &text('ssl_ekeyend', "-----END PRIVATE KEY-----");
for(my $i=0; $i<@lines; $i++) {
        $lines[$i] =~ /^-----(BEGIN|END)/ ||
	    $lines[$i] =~ /^[A-Za-z0-9\+\/=]+$/ ||
		return &text('ssl_ekeyline', $i+1);
        }
@lines > 4 || return &text('ssl_ekeylines', scalar(@lines));
return undef;
}

# can_edit_server(&server)
# Returns 1 if some server can be managed
sub can_edit_server
{
my ($server) = @_;
return 1 if (!$access{'vhosts'});
my $name = &find_value("server_name", $server);
return 0 if (!$name);
return &indexoflc($name, split(/\s+/, $access{'vhosts'})) >= 0;
}

# can_directory(dir)
# Check if some directory is under one of the allowed roots
sub can_directory
{
my ($dir) = @_;
foreach my $root (split(/\s+/, $access{'root'})) {
	return 1 if (&is_under_directory($root, $dir));
	}
return 0;
}

# switch_write_user(mode)
# If mode is 1, switch to another user for writing password files.
# If 0, switch back to root.
sub switch_write_user
{
my ($mode) = @_;
return if ($access{'user'} eq 'root');
if ($mode) {
	my @uinfo = getpwnam($access{'user'});
	@uinfo || &error("Write user $access{'user'} does not exist!");
	$) = $uinfo[3]." ".join(" ", $uinfo[2], &other_groups($uinfo[0]));
	$> = $uinfo[2];
	}
else {
	$) = 0;
	$> = 0;
	}
}

# recursive_change_directives(&parent, old-value, new-value, [suffix-too],
# 			      [prefix-too], [infix-too])
# Change all directives who have a value that is the old value to the new one
sub recursive_change_directives
{
my ($parent, $oldv, $newv, $suffix, $prefix, $infix) = @_;
foreach my $dir (@{$parent->{'members'}}) {
	my $changed = 0;
	foreach my $w (@{$dir->{'words'}}) {
		if ($infix && $w =~ /\Q$oldv\E/) {
			$w =~ s/\Q$oldv\E/$newv/g;
			$changed++;
			}
		elsif ($suffix && $w =~ /\Q$oldv\E$/) {
			$w =~ s/\Q$oldv\E$/$newv/g;
			$changed++;
			}
		elsif ($prefix && $w =~ /^\Q$oldv\E/) {
			$w =~ s/^\Q$oldv\E/$newv/g;
			$changed++;
			}
		elsif ($w eq $oldv) {
			$w = $newv;
			$changed++;
			}
		}
	if ($changed) {
		&save_directive($parent, [ $dir ], [ $dir ]);
		}
	if ($dir->{'type'}) {
		&recursive_change_directives($dir, $oldv, $newv,
					     $suffix, $prefix);
		}
	}
}

# list_available_fcgid_php_versions(&domain)
# List PHP versions that can be used in FCGId mode
sub list_available_fcgid_php_versions
{
my @vers = &virtual_server::list_available_php_versions(undef, "fcgid");
my @rv;
foreach my $v (@vers) {
	if ($v->[1]) {
		&clean_environment();
		my $out = &backquote_command("$v->[1] -h 2>&1 </dev/null");
		&reset_environment();
		if (!$? && $out =~ /\s-b\s/) {
			push(@rv, $v);
			}
		}
	}
return @rv;
}

# get_domain_php_version(&domain)
# Returns the PHP version number and binary path for the best PHP installed
sub get_domain_php_version
{
my ($d) = @_;
my @vers = sort { $b->[0] <=> $a->[0] } &list_available_fcgid_php_versions($d);
@vers || return ( );
if ($d->{'nginx_php_version'}) {
	# Try to get the version the domain is using
	my ($tver) = grep { $_->[0] eq $d->{'nginx_php_version'} } @vers;
	if ($tver) {
		return @$tver;
		}
	}
# Fall back to the first one available
my $cmd = $vers[0]->[1];
$cmd || return ( );
return @{$vers[0]};
}

# create_loop_script()
# Returns the path to a script that runs PHP in a loop
sub create_loop_script
{
foreach my $looper ("/usr/bin/php-loop.pl", "/etc/php-loop.pl") {
	if (&copy_source_dest("$module_root_directory/php-loop.pl", $looper)) {
		return $looper;
		}
	}
&error("Could not copy php-loop.pl to anywhere!");
}

# get_php_fcgi_server_command(&domain, port|file)
# Returns the PHP CGI command and a hash ref of environment variables
sub get_php_fcgi_server_command
{
my ($d, $port) = @_;
my ($ver, $basecmd) = &get_domain_php_version($d);
$basecmd || return ( );
my $cmd = $basecmd;
my $log = "$d->{'home'}/logs/php.log";
my $piddir = "/var/php-nginx";
if (!-d $piddir) {
	&make_dir($piddir, 0777);
	}
my $pidfile = "$piddir/$d->{'id'}.php.pid";
if ($port =~ /^\d+$/) {
	$cmd .= " -b 127.0.0.1:$port";
	}
else {
	$cmd .= " -b $port";
	}
my %envs_to_set = ( 'PHPRC', $d->{'home'}."/etc/php".$ver );
if ($d->{'nginx_php_children'} && $d->{'nginx_php_children'} > 1) {
	$envs_to_set{'PHP_FCGI_CHILDREN'} = $d->{'nginx_php_children'};
	}
$cmd = &create_loop_script()." ".$cmd;
return ($cmd, \%envs_to_set, $log, $pidfile, $basecmd);
}

# setup_php_fcgi_server(&domain)
# Starts up a PHP process running as the domain user, and enables it at boot.
# Returns an OK flag and the port number selected to listen on.
sub setup_php_fcgi_server
{
my ($d) =  @_;
my $port;

if (!$config{'php_socket'}) {
	# Find ports used by domains
	my %used;
	foreach my $od (&virtual_server::list_domains()) {
		if ($od->{'id'} ne $d->{'id'} && $od->{'nginx_php_port'}) {
			$used{$od->{'nginx_php_port'}}++;
			}
		}

	# Find a free port
	$port = 9100;
	my $s;
	socket($s, PF_INET, SOCK_STREAM, getprotobyname('tcp')) ||
		return (0, "Socket failed : $!");
	setsockopt($s, SOL_SOCKET, SO_REUSEADDR, pack("l", 1));
	while(1) {
		last if (!$used{$port} &&
			 bind($s, sockaddr_in($port, INADDR_ANY)));
		$port++;
		}
	close($s);
	}
else {
	# Use socket file. First work out directory for it
	my $socketdir = "/var/php-nginx";
	if (!-d $socketdir) {
		&make_dir($socketdir, 0777);
		}
	my $domdir = "$socketdir/$d->{'id'}.sock";
	if (!-d $domdir) {
		&make_dir($domdir, 0770);
		}
	my $user = &get_nginx_user();
	&set_ownership_permissions($user, $d->{'gid'}, undef, $domdir);
	$port = "$domdir/socket";
	}

# Get the command
my ($cmd, $envs_to_set, $log, $pidfile, $basecmd) =
	&get_php_fcgi_server_command($d, $port);
$cmd || return (0, $text{'fcgid_ecmd'});

# Check that the PHP command supports the -b flag
&clean_environment();
my $out = &backquote_command("$basecmd -h 2>&1 </dev/null");
&reset_environment();
if ($?) {
	$out = &virtual_server::html_tags_to_text($out, 1, 1);
	return (0, &text('fcgid_ecmdexec', "<tt>$basecmd</tt>",
			 "<tt>$out</tt>"));
	}
if ($out !~ /\s-b\s/) {
	return (0, &text('fcgid_ecmdb', "<tt>$basecmd</tt>"));
	}

# Create init script
&foreign_require("init");
my $old_init_mode = $init::init_mode;
if ($init::init_mode eq "upstart") {
	$init::init_mode = "init";
	}
my $name = &init_script_name($d);
my $envs = join(" ", map { $_."=".$envs_to_set->{$_} } keys %$envs_to_set);
my %cmds_abs = (
	'echo', &has_command('echo'),
	'cat', &has_command('cat'),
	'chmod', &has_command('chmod'),
	'kill', &has_command('kill'),
	'sleep', &has_command('sleep'),
);
&init::enable_at_boot($name,
	      "Starts Nginx PHP FastCGI server for $d->{'dom'} (Virtualmin)",
	      &command_as_user($d->{'user'}, 0,
		"$envs $cmd >>$log 2>&1 </dev/null")." & $cmds_abs{'echo'} \$! >$pidfile && $cmds_abs{'chmod'} +r $pidfile",
	      &command_as_user($d->{'user'}, 0,
		"$cmds_abs{'kill'} `$cmds_abs{'cat'} $pidfile`")." ; $cmds_abs{'sleep'} 1",
	      undef,
	      { 'fork' => 1,
		'pidfile' => $pidfile },
	      );
$init::init_mode = $old_init_mode;

# Launch it, and save the PID
&init::start_action($name);

return (1, $port);
}

# delete_php_fcgi_server(&domain)
# Shut down the fcgid server process, and delete it from starting at boot
sub delete_php_fcgi_server
{
my ($d) = @_;

# Stop the server
&foreign_require("init");
my $name = &init_script_name($d);
&init::stop_action($name);

# Delete init script
my $old_init_mode = $init::init_mode;
if ($init::init_mode eq "upstart") {
        $init::init_mode = "init";
        }
&init::disable_at_boot($name);
&init::delete_at_boot($name);
$init::init_mode = $old_init_mode;

# Previously we created init scripts under system
if ($init::init_mode eq "systemd") {
	my $old_init_mode = $init::init_mode;
        $init::init_mode = "init";
	&init::disable_at_boot($name);
	&init::delete_at_boot($name);
	$init::init_mode = $old_init_mode;
	}

# Delete socket file, if any
if ($d->{'nginx_php_port'} =~ /^(\/\S+)\/socket$/) {
	my $domdir = $1;
	&unlink_file($d->{'nginx_php_port'});
	&unlink_file($domdir);
	}
}

# init_script_name(&domain)
# Returns the name of the init script for the FCGId server
sub init_script_name
{
my ($d) = @_;
my $name = "php-fcgi-$d->{'dom'}";
$name =~ s/\./-/g;
return $name;
}

# find_php_fcgi_server(&domain)
# Returns the full path to the PHP command used by this domain's fcgi server
sub find_php_fcgi_server
{
my ($d) = @_;           

&foreign_require("init");
my $old_init_mode = $init::init_mode;
if ($init::init_mode eq "upstart" ||
    $init::init_mode eq "systemd") {
        $init::init_mode = "init";
        }

# Find the script that runs php
my $name = "php-fcgi-$d->{'dom'}";
my $oldname = $name;
$name =~ s/\./-/g;
my $script;
foreach my $n ($name, $oldname) {
	my $fn;
	if ($init::init_mode eq "init") {
		$fn = &init::action_filename($n);
		}
	elsif ($init::init_mode eq "rc") {
		my @rcs = &init::list_rc_scripts();
		my ($rc) = grep { $_->{'name'} eq $n } @rcs;
		if ($rc) {
			$fn = $rc->{'file'};
			}
		}
	if ($fn && -r $fn) {
		$script = $fn;
		last;
		}
	}
$init::init_mode = $old_init_mode;
return undef if (!$script);

# Extract the PHP command from it
my $lref = &read_file_lines($script, 1);
my $cmd;
foreach my $l (@$lref) {
	if ($l =~ /su\s+(\S+)\s+-c\s+(.*)/ &&
	    $1 eq $d->{'user'}) {
		# Possible command line - need to unquotemeta
		my $sucmd = $2;
		$sucmd = eval "\"$sucmd\"";
		if ($sucmd =~ /php-loop.pl\s+(\S+)/) {
			$cmd = $1;
			last;
			}
		}
	}
return $cmd;
}

# list_fastcgi_params(&server)
# Returns a list of param names and values needed for fastCGI
sub list_fastcgi_params
{
my ($server) = @_;
my $root = &find_value("root", $server);
$root ||= '$realpath_root';
my @rv = (
	[ 'GATEWAY_INTERFACE', 'CGI/1.1' ],
	[ 'SERVER_SOFTWARE',   'nginx' ],
	[ 'QUERY_STRING',      '$query_string' ],
	[ 'REQUEST_METHOD',    '$request_method' ],
	[ 'CONTENT_TYPE',      '$content_type' ],
	[ 'CONTENT_LENGTH',    '$content_length' ],
	[ 'SCRIPT_FILENAME',   $root.'$fastcgi_script_name' ],
	[ 'SCRIPT_NAME',       '$fastcgi_script_name' ],
	[ 'REQUEST_URI',       '$request_uri' ],
	[ 'DOCUMENT_URI',      '$document_uri' ],
	[ 'DOCUMENT_ROOT',     $root ],
	[ 'SERVER_PROTOCOL',   '$server_protocol' ],
	[ 'REMOTE_ADDR',       '$remote_addr' ],
	[ 'REMOTE_PORT',       '$remote_port' ],
	[ 'SERVER_ADDR',       '$server_addr' ],
	[ 'SERVER_PORT',       '$server_port' ],
	[ 'SERVER_NAME',       '$server_name' ],
	[ 'PATH_INFO',         '$fastcgi_path_info' ],
       );
my $ver = &get_nginx_version();
if ($ver =~ /^(\d+)\./ && $1 >= 2 ||
    $ver =~ /^1\.(\d+)\./ && $1 >= 2 ||
    $ver =~ /^1\.1\.(\d+)/ && $1 >= 11) {
	# Only in Nginx 1.1.11+
	push(@rv, [ 'HTTPS', '$https' ]);
	}
return @rv;
}

# find_before_location(&parent, path)
# Finds the first location with a path shorter than the one given
sub find_before_location
{
my ($parent, $path) = @_;
my @locs = &find("location", $parent);
foreach my $l (@locs) {
	if (length($l->{'words'}->[0]) <= length($path)) {
		return $l;
		}
	}
return undef;
}

# setup_fcgiwrap_server(&domain)
# Starts up a fcgiwrap process running as the domain user, and enables it
# at boot time. Returns an OK flag and the port number selected to listen on.
sub setup_fcgiwrap_server
{
my ($d) =  @_;
my $port;

# Work out socket file for fcgiwrap
my $socketdir = "/var/fcgiwrap";
if (!-d $socketdir) {
	&make_dir($socketdir, 0777);
	}
my $domdir = "$socketdir/$d->{'id'}.sock";
if (!-d $domdir) {
	&make_dir($domdir, 0770);
	}
my $user = &get_nginx_user();
&set_ownership_permissions($user, $d->{'gid'}, undef, $domdir);
my $port = "$domdir/socket";

# Get the command
my ($cmd, $envs_to_set, $log, $pidfile, $basecmd) =
	&get_fcgiwrap_server_command($d, $port);
$cmd || return (0, $text{'fcgid_ecmd'});

# Create init script
&foreign_require("init");
my $old_init_mode = $init::init_mode;
if ($init::init_mode eq "upstart") {
	$init::init_mode = "init";
	}
my $name = &init_script_name($d);
&init::enable_at_boot(
		$name,
		"Nginx fcgiwrap server for $d->{'dom'} (Virtualmin)",
		$cmd,
		undef,
		undef,
		{ 'opts' => {
			  'user'   => $d->{'user'},
			  'group'  => $d->{'user'},
			  'stop'   => 0,
			  'reload' => 0,
			  'logstd' => "$log",
			  'logerr' => "${log}_error"
		}},
		);
$init::init_mode = $old_init_mode;

# Launch it, and save the PID
&init::start_action($name);

return (1, $port);
}



# url_to_upstream(url)
# Converts a URL like http://www.foo.com/ to an upstream host:port spec
sub url_to_upstream
{
my ($url) = @_;
my ($host, $port) = &parse_http_url($url);
$port ||= 80;
return $host.":".$port;
}

# upstream_to_url(host:port)
# Converts a host:port spec to a URL
sub upstream_to_url
{
my ($hp) = @_;
my ($host, $port) = split(/:/, $hp);
return "http://".$host.($port == 80 ? "" : ":".$port);
}

# validate_balancer_urls(url, ...)
# Checks a bunch of URLs for syntax and resolvability
sub validate_balancer_urls
{
foreach my $u (@_) {
	my ($host, $port) = &parse_http_url($u);
	return &text('redirect_eurl', $u) if (!$host);
	&to_ipaddress($host) || &to_ip6address($host) ||
		return &text('redirect_eurlhost', $host);
	}
return undef;
}

# split_ssl_certs(data)
# Returns an array of all SSL certs in some file
sub split_ssl_certs
{
my ($data) = @_;
my @rv;
my $idx = -1;
foreach my $l (split(/\r?\n/, $data)) {
	if ($l =~ /^\-+BEGIN/) {
		$idx++;
		push(@rv, $l."\n");
		}
	elsif ($idx >= 0 && $l =~ /\S/) {
		$rv[$idx] .= $l."\n";
		}
	}
return @rv;
}

# recursive_clear_lines(&directive, ...)
# Remove any file and line fields from directives
sub recursive_clear_lines
{
foreach my $e (@_) {
	delete($e->{'file'});
	delete($e->{'line'});
	delete($e->{'eline'});
	if ($e->{'type'}) {
		&recursive_clear_lines(@{$e->{'members'}});
		}
	}
}

1;
