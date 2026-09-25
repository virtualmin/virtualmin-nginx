#!/usr/bin/perl
# Check log access through real Nginx reopen and logrotate operations on a VM.

use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);

plan skip_all => 'Set VIRTUALMIN_NGINX_LOG_TEST=1 on a disposable VM'
	unless $ENV{'VIRTUALMIN_NGINX_LOG_TEST'} && $^O eq 'linux' && $> == 0;
my ($root) = grep { -f "$_/WebminCore.pm" }
	($ENV{'WEBMIN_ROOT'} || '', '/usr/libexec/webmin', '/usr/share/webmin');
die "Webmin root not found\n" unless $root;
$ENV{'WEBMIN_CONFIG'} ||= '/etc/webmin';
$ENV{'WEBMIN_VAR'} ||= '/var/webmin';
chdir("$root/virtual-server") or die $!;
$0 = "$root/virtual-server/log-permissions-test.pl";
unshift(@INC, $root);
require WebminCore;
WebminCore->import();
init_config();
foreign_require('virtual-server');
foreign_require('virtualmin-nginx', 'virtual_feature.pl');

# Isolate the server and its logs from the VM's existing Nginx instance.
my $tmp = tempdir('nginx-log-permissions-XXXXXX', TMPDIR => 1, CLEANUP => 1);
chmod(0755, $tmp) or die $!;
my $nginx = has_command('nginx') or die "Nginx not found\n";
my $worker = virtualmin_nginx::get_nginx_user();
my @worker = getpwnam($worker);
die "Nginx worker user not found\n" unless @worker;
my $user = 'nlp'.time().$$;
my $other = $user.'x';
my @users;
my $started;
my $conf = "$tmp/nginx.conf";
my @server = ($nginx, '-p', "$tmp/", '-c', $conf);
my $test_pid = $$;

# command(@args): Run a bounded command and keep its output out of TAP.
sub command
{
my (@args) = @_;
my $pid = fork();
die "fork: $!" if !defined($pid);
if (!$pid) {
	# Commands need no input; retain diagnostics until the test exits.
	open(STDIN, '<', '/dev/null') or die $!;
	open(STDOUT, '>>', "$tmp/commands.log") or die $!;
	open(STDERR, '>&', STDOUT) or die $!;
	exec('timeout', '30', @args);
	die "exec: $!";
	}
waitpid($pid, 0);
return $?;
}

# write_text(file, text): Write a fixture or configuration file.
sub write_text
{
my ($file, $text) = @_;
open(my $fh, '>', $file) or die "$file: $!";
print $fh $text;
close($fh) or die "$file: $!";
}

# Stop only the isolated server and remove the locked test accounts.
END {
	my $status = $?;
	if ($tmp && $$ == $test_pid) {
		command(@server, '-s', 'quit') if $started;
		for (1..50) {
			last if !-e "$tmp/nginx.pid";
			select(undef, undef, undef, 0.1);
			}
		foreach my $name (reverse @users) {
			$status ||= 1 if command('userdel', $name);
			}
		if ($status && -f "$tmp/commands.log") {
			open(my $fh, '<', "$tmp/commands.log") or die $!;
			diag(do { local $/; <$fh> });
			close($fh);
			}
		}
	$? = $status;
}

# No passwords are created: these accounts are used only through runuser.
foreach my $name ($user, $other) {
	die "Fixture account already exists\n" if defined(getpwnam($name));
	command('useradd', '--no-create-home', '--user-group',
		'--home-dir', "$tmp/home", '--shell', '/sbin/nologin', $name) == 0
		or die "Cannot create test account\n";
	push(@users, $name);
	}
my @owner = getpwnam($user);
my $d = { user => $user, uid => $owner[2], gid => $owner[3],
	ugid => $owner[3], home => "$tmp/home", dom => 'log-permissions.invalid' };
mkdir($d->{'home'}) or die $!;
my @logs = map { "$tmp/${_}_log" } ('access', 'error');

# Seed old-style archives to check that repairing a log also repairs history.
foreach my $log (@logs) {
	write_text($log, "active fixture\n");
	write_text($log.'.5', "archive fixture\n");
	command('gzip', $log.'.5') == 0 or die "Cannot compress fixture\n";
	chown($worker[2], $worker[3], $log, $log.'.5.gz');
	chmod(0660, $log, $log.'.5.gz');
	virtualmin_nginx::set_nginx_log_permissions($d, $log);
	is(command('runuser', '-u', $user, '--', 'gzip', '-t', $log.'.5.gz'),
		0, 'domain owner can read a repaired archive');
	}

# Use a Unix socket so this test needs no free TCP port or service restart.
write_text($conf, "user $worker;\nworker_processes 1;\npid $tmp/nginx.pid;\n".
	"error_log $logs[1];\nevents {}\nhttp {\n".
	join('', map { "    ${_}_temp_path $tmp/$_;\n" }
		qw(client_body proxy fastcgi uwsgi scgi)).
	"    server {\n        listen unix:$tmp/nginx.sock;\n".
	"        access_log $logs[0];\n        location / { return 200 'log test'; }\n".
	"    }\n}\n");
command(@server) == 0 or die "Cannot start isolated Nginx\n";
$started = 1;

# Reopening must preserve domain access, even when Nginx takes ownership.
is(command(@server, '-s', 'reopen'), 0, 'Nginx accepts a log reopen');
select(undef, undef, undef, 0.3);
foreach my $log (@logs) {
	my @st = stat($log);
	is($st[4], $worker[2], 'Nginx owns the reopened log');
	is($st[5], $owner[3], 'domain group owns the reopened log');
	is($st[2] & 0777, 0660, 'log remains private to its owner and group');
	is(command('runuser', '-u', $user, '--', 'test', '-r', $log),
		0, 'domain owner can read the reopened log');
	ok(command('runuser', '-u', $other, '--', 'test', '-r', $log),
		'another domain user cannot read the log');
	}

# Inherit each file's group when logrotate creates the next active log.
write_text("$tmp/logrotate.conf", join(' ', @logs)." {\n".
	"    rotate 6\n    compress\n    missingok\n    create\n    sharedscripts\n".
	"    postrotate\n        ".join(' ', map { quote_path($_) }
		(@server, '-s', 'reopen'))."\n    endscript\n}\n");
for my $round (1, 2) {
	is(command('curl', '--fail', '--silent', '--unix-socket', "$tmp/nginx.sock",
		"http://localhost/round$round"), 0, "round $round request succeeds");
	open(my $fh, '<', $logs[0]) or die $!;
	like(do { local $/; <$fh> }, qr/GET \/round$round /,
		"round $round request is written to the access log");
	close($fh);
	is(command('logrotate', '--force', '--state', "$tmp/rotation.state",
		"$tmp/logrotate.conf"), 0, "round $round log rotation succeeds");
	select(undef, undef, undef, 0.3);
	foreach my $log (@logs) {
		foreach my $file ($log, $log.'.1.gz') {
			my @st = stat($file);
			is($st[5], $owner[3], "round $round keeps the domain group");
			is($st[2] & 0777, 0660, "round $round keeps mode 0660");
			is(command('runuser', '-u', $user, '--', 'test', '-r', $file),
				0, "round $round domain owner can read active and rotated logs");
			ok(command('runuser', '-u', $other, '--', 'test', '-r', $file),
				"round $round another domain user cannot read the logs");
			}
		}
	}

# Imported domains may have only the owner's primary group recorded.
my $imported = { %$d };
delete($imported->{'gid'});
virtualmin_nginx::set_nginx_log_permissions($imported, $logs[0]);
is((stat($logs[0]))[5], $owner[3], 'primary group is used when domain gid is absent');

done_testing();
