#!/usr/bin/perl
# Opt-in integration test: creates and deletes domains on a disposable VM.

use strict;
use warnings;
no warnings 'once';
use Test::More;
use File::Temp qw(tempdir);
use File::Basename qw(dirname);
use Cwd qw(abs_path);
use Time::HiRes qw(sleep time);

plan skip_all => 'Set VIRTUALMIN_NGINX_CONCURRENT_TEST=1 on a disposable VM'
	unless $ENV{'VIRTUALMIN_NGINX_CONCURRENT_TEST'} && $^O eq 'linux' && $> == 0;
my ($root) = grep { -f "$_/WebminCore.pm" }
	($ENV{'WEBMIN_ROOT'} || '', '/usr/libexec/webmin', '/usr/share/webmin');
die "Webmin root not found\n" unless $root;
my $cgi_helper = abs_path(dirname(__FILE__).'/create-domain-cgi.pl');
my $use_cgi = $ENV{'VIRTUALMIN_NGINX_CREATE_CGI'};
die "create-domain-cgi.pl must be alongside this test\n" if $use_cgi && !$cgi_helper;
$ENV{'WEBMIN_CONFIG'} ||= '/etc/webmin';
$ENV{'WEBMIN_VAR'} ||= '/var/webmin';
chdir("$root/virtual-server") or die $!;
$0 = "$root/virtual-server/concurrent-test.pl";
unshift(@INC, $root);
require WebminCore;
WebminCore->import();
init_config();
foreign_require('virtual-server');
foreign_require('virtualmin-nginx', 'virtual_feature.pl');
{ no warnings 'once'; $main::error_must_die = 1; }
# HTTP checks below need a running server, so fail early rather than
# blaming domain creation for a server left down by an earlier test
die "Nginx must be running before this test starts\n"
	if !nginx::is_nginx_running();

my $tmp = tempdir('nginx-concurrent-XXXXXX', TMPDIR => 1, CLEANUP => 0);
diag("Logs: $tmp");
my $tag = 'nc'.int(time()).$$;
my @domains;
my $passfile = "$tmp/password";
my $lognum = 0;
my $test_pid = $$;
my $cgi_template;
my $suffix = $ENV{'VIRTUALMIN_NGINX_TEST_SUFFIX'} || 'example.com';
my @ip6 = virtual_server::get_default_ip6() ? ('--default-ip6') : ();
my $tmpl = virtual_server::get_template(virtual_server::get_init_template());
die "The default template must enable FCGIwrap for this test\n"
	if $tmpl->{'web_cgimode'} ne 'fcgiwrap';

sub start_api
{
my (@args) = @_;
my $log = "$tmp/".(++$lognum).'-'.$args[0].'.log';
my @command = ($^X, "$root/virtual-server/$args[0].pl", @args[1..$#args]);
if ($args[0] eq 'create-domain' && $use_cgi) {
	@command = ($^X, $cgi_helper, $args[2], $passfile, $cgi_template->{'id'});
	}
my $pid = fork();
die "fork: $!" if !defined($pid);
if (!$pid) {
	open(STDOUT, '>', $log) or die $!;
	open(STDERR, '>&', STDOUT) or die $!;
	exec('timeout', '240', @command);
	die "exec: $!";
	}
return ($pid, $log);
}

sub finish_api
{
my ($pid, $log) = @_;
waitpid($pid, 0);
my $status = $?;
if ($status) {
	open(my $fh, '<', $log) or die $!;
	diag(do { local $/; <$fh> });
	}
return $status;
}

sub api
{
return finish_api(start_api(@_));
}

sub write_text
{
my ($file, $text) = @_;
open(my $fh, '>', $file) or die "$file: $!";
print $fh $text;
close($fh) or die "$file: $!";
}

# Keep fixture credentials on the VM and remove them even after a failed test.
my $mask = umask(0077);
write_text($passfile, virtual_server::random_password(32)."Aa1!\n");
umask($mask);
END {
	my $exit = $?;
	if ($tmp && $$ == $test_pid) {
		# Domains were created by child processes, so drop any cached list
		virtual_server::flush_virtualmin_caches();
		foreach my $dom (reverse @domains) {
			next if !virtual_server::get_domain_by('dom', $dom);
			my $status = api('delete-domain', '--domain', $dom);
			if ($status) {
				diag("Cleanup failed for $dom");
				$exit ||= 1;
				}
			}
		if ($cgi_template) {
			$exit ||= 1 if api('delete-template', '--id', $cgi_template->{'id'});
			}
		unlink($passfile) if $passfile;
		}
	$? = $exit;
}

# The web form reads notification and ACME settings from its template.
if ($use_cgi) {
	$cgi_template = { %$tmpl, id => undef, standard => 0, default => 0,
		name => $tag, mail_on => 'none', ssl_auto_letsencrypt => 0 };
	virtual_server::save_template($cgi_template);
	}

for my $round (1, 2) {
	my @pair = map { "$tag-$round-$_.$suffix" } qw(a b);
	my @running;
	foreach my $dom (@pair) {
		die "Fixture already exists: $dom\n"
			if virtual_server::get_domain_by('dom', $dom);
		push(@domains, $dom);
		push(@running, [start_api('create-domain', '--domain', $dom,
			'--desc', 'Nginx concurrency test', '--passfile', $passfile,
			'--default-features', '--default-ip', '--no-email',
			'--letsencrypt-never', @ip6)]);
		sleep(1) if @running == 1;
		}
	foreach my $run (@running) {
		is(finish_api(@$run), 0, "round $round concurrent creation succeeds");
		}
	is(system('nginx', '-t'), 0, "round $round config passes nginx -t");
	nginx::flush_config_cache();
	flush_webmin_caches();
	virtual_server::flush_virtualmin_caches();
	foreach my $dom (@pair) {
		# Domain files and lookup maps are read from the completed setup.
		my $d = virtual_server::get_domain_by('dom', $dom);
		ok($d, "$dom exists") or next;
		my $s = virtualmin_nginx::find_domain_server($d);
		ok($s, "$dom has a server block") or next;
		my @ssl = grep { grep { $_ eq 'ssl' } @{$_->{'words'}} }
			nginx::find('listen', $s);
		my %seen;
		ok(@ssl && !(grep { $seen{$_->{'words'}->[0]}++ } @ssl),
			"$dom has SSL listeners without duplicates");
		my @expected = $virtualmin_nginx::config{'listen_mode'} eq '0' ?
			('443', '[::]:443') :
			(($d->{'ip'} ? "$d->{'ip'}:443" : ()),
			 ($d->{'ip6'} ? "[$d->{'ip6'}]:443" : ()));
		is_deeply([sort keys %seen], [sort @expected],
			"$dom has the expected IPv4 and IPv6 SSL listeners");
		is(virtualmin_nginx::feature_get_web_php_mode($d), 'fpm',
			"$dom runs PHP through FPM");
		my @cgi = grep { $_->{'words'}->[0] eq '/cgi-bin/' }
			nginx::find('location', $s);
		is(scalar(@cgi), 1, "$dom has exactly one CGI location");
		if (@cgi) {
			is(nginx::find_value('root', $cgi[0]), "$d->{'home'}/cgi-bin",
				"$dom uses its own CGI directory");
			is(nginx::find_value('fastcgi_pass', $cgi[0]),
				"unix:$d->{'nginx_fcgiwrap_port'}", "$dom uses its own CGI socket");
			}
		is(api('validate-domains', '--domain', $dom, '--all-features'), 0,
			"$dom validates");
		my $phd = virtual_server::public_html_dir($d);
		write_text("$phd/concurrent.txt", "static-$dom");
		write_text("$phd/concurrent.php", "<?php echo 'php-$dom'; ?>");
		my $cgifile = "$d->{'home'}/cgi-bin/concurrent.cgi";
		write_text($cgifile,
			"#!/bin/sh\nprintf 'Content-Type: text/plain\\r\\n\\r\\ncgi-$dom'\n");
		chown($d->{'uid'}, $d->{'gid'}, $cgifile) == 1 or die "chown: $!";
		chmod(0755, $cgifile) == 1 or die "chmod: $!";
		foreach my $scheme ('http', 'https') {
			foreach my $kind ('txt', 'php', 'cgi') {
				my $path = $kind eq 'cgi' ? 'cgi-bin/concurrent.cgi' : "concurrent.$kind";
				my @cmd = ('curl', '--noproxy', '*', '-ksSfL', '--max-time', '15',
					'--resolve', "$dom:80:$d->{'ip'}",
					'--resolve', "$dom:443:$d->{'ip'}",
					"$scheme://$dom/$path");
				open(my $fh, '-|', @cmd) or die "curl: $!";
				my $body = do { local $/; <$fh> };
				close($fh);
				is($?, 0, "$scheme $kind request succeeds");
				is($body, ($kind eq 'txt' ? 'static-' : "$kind-").$dom,
					"$scheme serves the correct $kind content for $dom");
				}
			}
		}
	}

done_testing();
