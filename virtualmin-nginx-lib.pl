# Common functions for Virtualmin's Nginx feature

use strict;
use warnings;
no warnings 'recursion';
use Socket;

BEGIN { push(@INC, ".."); };
eval "use WebminCore;";
&init_config();
our %access = &get_module_acl();
our (%config, %text, %in, $module_root_directory);

&foreign_require("nginx");
&sync_nginx_module_config();

# nginx_webmin_module()
# Returns the stock Webmin Nginx module that owns the shared UI/config logic.
sub nginx_webmin_module
{
return "nginx";
}

# sync_nginx_module_config()
# Use the stock Nginx module as the source of truth for shared service paths
# while keeping Virtualmin-only settings in this module's config.
sub sync_nginx_module_config
{
foreach my $k (qw(nginx_config add_to add_link nginx_cmd start_cmd stop_cmd apply_cmd pid_file)) {
	$config{$k} = $nginx::config{$k} if (defined($nginx::config{$k}));
	}
$config{'rotate_cmd'} ||= $nginx::config{'apply_cmd'};
}

sub find_domain_server
{
my ($d) = @_;
my $conf = &nginx::get_config();
my $http = &nginx::find("http", $conf);
return undef if (!$http);
my @servers = &nginx::find("server", $http);
foreach my $s (@servers) {
	my $obj = &nginx::find("server_name", $s);
	foreach my $name (@{$obj->{'words'}}) {
		if (defined($name) && (lc($name) eq lc($d->{'dom'}) ||
				       lc($name) eq "www.".lc($d->{'dom'}) ||
				       lc($name) eq "*.".lc($d->{'dom'}))) {
			return $s;
			}
		}
	}
return undef;
}

sub resolve_php_fpm_version
{
my ($d, $avail, $save) = @_;
my @avail = $avail ? @$avail
		   : &virtual_server::list_available_php_versions($d, "fpm");
@avail = sort {
	&virtual_server::compare_version_numbers($a->[0], $b->[0])
	} @avail;
return undef if (!@avail);

my $stored = $d->{'php_fpm_version'};
my $resolved;
if ($stored) {
	# Only trust the saved version if the matching pool file exists.
	my ($match) = grep { $_->[0] eq $stored } @avail;
	if ($match) {
		my $conf = &virtual_server::get_php_fpm_config($stored);
		my $file = $conf ? $conf->{'dir'}."/".$d->{'id'}.".conf" : undef;
		$resolved = $stored if ($file && -r $file);
		}
	}

$resolved ||= &virtual_server::detect_php_fpm_version($d);
if (!$resolved) {
	my $tmpl = &virtual_server::get_template($d->{'template'});
	if ($tmpl->{'web_phpver'}) {
		my ($match) = grep { $_->[0] eq $tmpl->{'web_phpver'} } @avail;
		$resolved = $match ? $match->[0] : undef;
		}
	}
$resolved ||= $avail[$#avail]->[0];

if ($resolved && $resolved ne $stored) {
	$d->{'php_fpm_version'} = $resolved;
	if ($save) {
		&virtual_server::lock_domain($d);
		&virtual_server::save_domain($d);
		&virtual_server::unlock_domain($d);
		}
	}
return $resolved;
}

# get_php_location_custom_members([&existing])
# Returns directives in the PHP location block that Virtualmin does not
# manage directly
sub get_php_location_custom_members
{
my ($loc) = @_;
my %managed = map { $_, 1 }
	('default_type', 'try_files', 'fastcgi_split_path_info',
	 'fastcgi_pass');
return $loc ? grep { !$managed{$_->{'name'}} } @{$loc->{'members'}} : ();
}

# get_php_location_struct([&existing], port|socket, split-path-regexp)
# Builds the standard PHP location block for an active handler, while keeping
# any unrelated custom directives from the existing block; keeping this in one
# builder lets PHP mode changes replace the whole location consistently
sub get_php_location_struct
{
my ($loc, $port, $splitre) = @_;
my @keep = &get_php_location_custom_members($loc);
my $pass = $port =~ /^\d+$/ ? "127.0.0.1:".$port : "unix:".$port;
return {
	'name' => 'location',
	'words' => $loc ? [ @{$loc->{'words'}} ] : [ '~', '\.php(/|$)' ],
	'type' => 1,
	'members' => [
		{ 'name' => 'default_type',
		  'words' => [ 'application/x-httpd-php' ],
		},
		{ 'name' => 'try_files',
		  'words' => [ '$uri', '$fastcgi_script_name', '=404' ],
		},
		{ 'name' => 'fastcgi_split_path_info',
		  'words' => [ &split_quoted_string($splitre) ],
		},
		{ 'name' => 'fastcgi_pass',
		  'words' => [ $pass ],
		},
		@keep,
	],
};
}

# get_php_disabled_location_struct([&existing])
# Builds the PHP location block for disabled PHP, while keeping any unrelated
# custom directives from the existing block
sub get_php_disabled_location_struct
{
my ($loc) = @_;
my @keep = &get_php_location_custom_members($loc);
return {
	'name' => 'location',
	'words' => $loc ? [ @{$loc->{'words'}} ] : [ '~', '\.php(/|$)' ],
	'type' => 1,
	'members' => [
		{ 'name' => 'default_type',
		  'words' => [ 'text/plain' ],
		},
		{ 'name' => 'try_files',
		  'words' => [ '$uri', '$fastcgi_script_name', '=404' ],
		},
		@keep,
	] };
}

# split_ip_port(string)
# Given an ip:port pair as used in a listen directive, split them up
sub recursive_change_directives
{
my ($parent, $oldv, $newv, $suffix, $prefix, $infix, $skip) = @_;
return if (!$oldv);
foreach my $dir (@{$parent->{'members'}}) {
	if (!$skip || &indexof($dir->{'name'}, @$skip) < 0) {
		my $changed = 0;
		foreach my $w (@{$dir->{'words'}}) {
			my $ow = $w;
			if ($infix && $w =~ /\Q$oldv\E/) {
				$w =~ s/\Q$oldv\E/$newv/g;
				$changed++;
				}
			elsif ($suffix && $w =~ /\Q$oldv\E$/) {
				$w =~ s/\Q$oldv\E$/$newv/;
				$changed++;
				}
			elsif ($prefix && $w =~ /^\Q$oldv\E/) {
				$w =~ s/^\Q$oldv\E/$newv/;
				$changed++;
				}
			elsif ($w eq $oldv) {
				$w = $newv;
				$changed++;
				}
			if ($ow ne $w) {
				print STDERR "changed $ow to $w\n";
				}
			}
		if ($changed) {
			&nginx::save_directive($parent, [ $dir ], [ $dir ]);
			}
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
if (defined(&init::enable_at_boot_as_user)) {
	# Init system can run commands as the user
	&init::enable_at_boot_as_user($name,
		      "Starts Nginx PHP FastCGI server for $d->{'dom'} (Virtualmin)",
		      "$envs $cmd >>$log 2>&1 </dev/null & $cmds_abs{'echo'} \$! >$pidfile",
		      "$cmds_abs{'kill'} `$cmds_abs{'cat'} $pidfile`",
		      undef,
		      { 'fork' => 1,
			'pidfile' => $pidfile },
		      $d->{'user'},
		      );

	}
else {
	# Older Webmin requires use of command_as_user
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
	}
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
if ($d->{'nginx_php_port'} && $d->{'nginx_php_port'} =~ /^(\/\S+)\/socket$/) {
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
my $root = &nginx::find_value("root", $server);
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
my $ver = &nginx::get_nginx_version();
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
my @locs = &nginx::find("location", $parent);
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
my ($cmd, $log, $pidfile) = &get_fcgiwrap_server_command($d, $port);
$cmd || return (0, $text{'fcgid_ecmd'});

# Create init script
&foreign_require("init");
my $old_init_mode = $init::init_mode;
if ($init::init_mode eq "upstart") {
	$init::init_mode = "init";
	}
my $name = &init_script_fcgiwrap_name($d);
my %cmds_abs = (
	'echo', &has_command('echo'),
	'cat', &has_command('cat'),
	'chmod', &has_command('chmod'),
	'kill', &has_command('kill'),
	'sleep', &has_command('sleep'),
	'fuser', &has_command('fuser'),
	'rm', &has_command('rm'),
	);
if (defined(&init::enable_at_boot_as_user)) {
	# Init system can run commands as the user
	&init::enable_at_boot_as_user($name,
		      "Nginx FCGIwrap server for $d->{'dom'} (Virtualmin)",
		      "$cmds_abs{'rm'} -f $port ; $cmd >>$log 2>&1 </dev/null & $cmds_abs{'echo'} \$! >$pidfile && sleep 2 && $cmds_abs{'chmod'} 777 $port",
		      "$cmds_abs{'kill'} `$cmds_abs{'cat'} $pidfile` ; ".
		      "$cmds_abs{'sleep'} 1 ; ".
		      "$cmds_abs{'rm'} -f $port",
		      undef,
		      { 'fork' => 1,
			'pidfile' => $pidfile },
		      $d->{'user'},
		      );
	}
else {
	# Older Webmin requires use of command_as_user
	&init::enable_at_boot($name,
		      "Nginx FCGIwrap server for $d->{'dom'} (Virtualmin)",
		      &command_as_user($d->{'user'}, 0,
			"$cmd >>$log 2>&1 </dev/null")." & $cmds_abs{'echo'} \$! >$pidfile && $cmds_abs{'chmod'} +r $pidfile && sleep 2 && $cmds_abs{'chmod'} 777 $port",
		      &command_as_user($d->{'user'}, 0,
			"$cmds_abs{'kill'} `$cmds_abs{'cat'} $pidfile`").
			" ; $cmds_abs{'sleep'} 1".
			($cmds_abs{'fuser'} ? " ; $cmds_abs{'fuser'} $port | xargs kill"
					    : "").
			" ; $cmds_abs{'rm'} -f $port",
		      undef,
		      { 'fork' => 1,
			'pidfile' => $pidfile },
		      );
	}
$init::init_mode = $old_init_mode;

# Launch it, and save the PID
&init::start_action($name);

return (1, $port);
}

# delete_fcgiwrap_server(&domain)
# Shut down the fcgiwrap process, and delete it from starting at boot
sub delete_fcgiwrap_server
{
my ($d) = @_;

# Stop the server
&foreign_require("init");
my $name = &init_script_fcgiwrap_name($d);
&init::stop_action($name);

# Delete init script
my $old_init_mode = $init::init_mode;
if ($init::init_mode eq "upstart") {
        $init::init_mode = "init";
        }
&init::disable_at_boot($name);
&init::delete_at_boot($name);
$init::init_mode = $old_init_mode;

# Delete socket file, if any
if ($d->{'nginx_fcgiwrap_port'} &&
    $d->{'nginx_fcgiwrap_port'} =~ /^(\/\S+)\/socket$/) {
	my $domdir = $1;
	&unlink_file($d->{'nginx_fcgiwrap_port'});
	&unlink_file($domdir);
	}
}

# get_fcgiwrap_server_command(&domain, port)
# Returns a command to run the fcgiwrap server, log file and PID file
sub get_fcgiwrap_server_command
{
my ($d, $port) = @_;
my $cmd = &has_command("fcgiwrap");
$cmd .= " -s unix:".$port;
my $log = "$d->{'home'}/logs/fcgiwrap.log";
my $piddir = "/var/php-nginx";
if (!-d $piddir) {
	&make_dir($piddir, 0777);
	}
my $pidfile = "$piddir/$d->{'id'}.fcgiwrap.pid";
return ($cmd, $log, $pidfile);
}

# init_script_fcgiwrap_name(&domain)
# Returns the name of the init script for the FCGId server
sub init_script_fcgiwrap_name
{
my ($d) = @_;
my $name = "fcgiwrap-$d->{'dom'}";
$name =~ s/\./-/g;
return $name;
}

# url_to_upstream(url)
# Converts a URL like http://www.foo.com/ to an upstream host:port spec
sub url_to_upstream
{
my ($url) = @_;
my ($host, $port, $uds) = &parse_backend($url);
return $port if ($uds);
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
# Checks a bunch of URLs for syntax and resolvability.
# If socket is used, it is not checked for resolvability.
sub validate_balancer_urls
{
foreach my $u (@_) {
	my ($host, $port, $uds) = &parse_backend($u);
	# Check for valid URL
	if (!$uds) {
		return &text('redirect_eurl', $u) if (!$host);
		&to_ipaddress($host) || &to_ip6address($host) ||
			return &text('redirect_eurlhost', $host);
		}
	# Socket is not checked for resolvability and already validated
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

# parse_backend(url|sock)
# Parses a URL into host and port or unix domain socket and
# sets a flag if it is socket
sub parse_backend
{
my ($url) = @_;
if ($url =~ /^http:\/\/(unix:\/\S+)/) {
	return (undef, $1, 1);
	}
else {
	my ($host, $port) = &parse_http_url($url);
	return ($host, $port, 0);
	}
return (undef, undef, undef);
}

1;
