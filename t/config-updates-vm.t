#!/usr/bin/perl
# Exercise plugin edits against a temporary config using installed Webmin APIs.

use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use POSIX ();

plan skip_all => 'Set VIRTUALMIN_NGINX_CONFIG_TEST=1 on a disposable VM'
	unless $ENV{'VIRTUALMIN_NGINX_CONFIG_TEST'} && $^O eq 'linux' && $> == 0;
my ($root) = grep { -f "$_/WebminCore.pm" }
	($ENV{'WEBMIN_ROOT'} || '', '/usr/libexec/webmin', '/usr/share/webmin');
die "Webmin root not found\n" unless $root;
$ENV{'WEBMIN_CONFIG'} ||= '/etc/webmin';
$ENV{'WEBMIN_VAR'} ||= '/var/webmin';
chdir("$root/virtual-server") or die $!;
$0 = "$root/virtual-server/config-test.pl";
unshift(@INC, $root);
require WebminCore;
WebminCore->import();
init_config();
foreign_require('virtual-server');
foreign_require('virtualmin-nginx', 'virtual_feature.pl');
foreign_require('virtualmin-nginx-ssl', 'virtual_feature.pl');

my $tmp = tempdir(CLEANUP => 1);
my $conf = "$tmp/nginx.conf";
my $d = { dom => 'beta.invalid', home => $tmp, ip => '127.0.0.1',
	web_sslport => 443, creating => 1,
	ssl_cert => "$tmp/cert", ssl_key => "$tmp/key",
	ssl_chain => "$tmp/chain", ssl_combined => "$tmp/combined" };
open(my $fh, '>', $conf) or die $!;
print $fh "http {\n";
foreach my $name ('alpha.invalid', 'beta.invalid') {
	print $fh "    server {\n        server_name $name;\n".
		"        listen 127.0.0.1:80;\n        root $tmp/public_html;\n";
	print $fh "        location ~ \\.php(/|\$) {\n".
		"            default_type application/x-httpd-php;\n        }\n"
		if $name eq 'beta.invalid';
	print $fh "    }\n";
	}
print $fh "}\n";
close($fh);
foreach my $file (qw(cert key chain combined)) {
	open(my $fh, '>', "$tmp/$file") or die $!;
	print $fh "fixture\n";
	close($fh);
	}

# Only config parsing and editing are under test here. Domain creation, real
# certificates, PHP pools and service reloads are covered by the CLI VM test.
{
no warnings qw(once redefine);
$main::error_must_die = 1;
$nginx::config{'nginx_config'} = $conf;
$nginx::last_config_change_flag = "$tmp/flag";
$nginx::last_restart_time_flag = "$tmp/restart";
$virtualmin_nginx::config{'listen_mode'} = 1;
$virtualmin_nginx::config{'http2'} = 0;
local *virtual_server::register_post_action = sub {};
local *virtual_server::get_template = sub { return {}; };
local *virtual_server::public_html_dir = sub { return "$_[0]->{'home'}/public_html"; };
local *virtual_server::find_matching_certificate = sub {};
local *virtual_server::generate_default_certificate = sub { return 1; };
local *virtual_server::refresh_ssl_cert_expiry = sub {};
local *virtual_server::sync_combined_ssl_cert = sub {};
local *virtual_server::validate_cert_format = sub { return undef; };
local *virtual_server::check_cert_key_match = sub { return undef; };
local *virtual_server::enable_domain_service_ssl_certs = sub {};
local *virtual_server::sync_domain_tlsa_records = sub {};
local *virtualmin_nginx::supports_http3 = sub { return 0; };
local $virtual_server::first_print = sub {};
local $virtual_server::second_print = sub {};
nginx::flush_config_cache();

my $writes = 0;
my $other_writer = sub {
	# The parent retains its parse while another process shifts beta's lines.
	my $count = shift || 1;
	nginx::get_config();
	my $first = $writes + 1;
	$writes += $count;
	my $pid = fork();
	die "fork: $!" if !defined($pid);
	if (!$pid) {
		nginx::lock_all_config_files();
		my $s = virtualmin_nginx::find_domain_server({dom => 'alpha.invalid'});
		nginx::save_directive($s, [], [map {
			{ name => 'add_header', words => ["X-$_", 'yes'] }
			} $first .. $writes]);
		nginx::flush_config_file_lines();
		nginx::unlock_all_config_files();
		POSIX::_exit(0);
		}
	waitpid($pid, 0);
	is($?, 0, 'competing writer succeeds');
	};
my $verify = sub {
	nginx::flush_config_cache();
	my $http = nginx::find('http', nginx::get_config());
	is(scalar(nginx::find('server', $http)),
		virtualmin_nginx::find_domain_server({dom => 'alpha.invalid'}),
		'first server remains at top level');
	my @servers = nginx::find('server', $http);
	is(scalar(@servers), 2, 'both server blocks survive');
	my @headers = nginx::find('add_header', $servers[0]);
	is(scalar(@headers), $writes, 'all competing edits are preserved');
	ok(!-e "$conf.lock", 'edit releases the outer lock');
	};
my $edit = sub {
	my ($name, $code, $check) = @_;
	subtest $name => sub {
		$other_writer->();
		is($code->(), undef, 'edit succeeds');
		$verify->();
		$check->() if $check;
		};
	};

$edit->('certificate update', sub {
	virtualmin_nginx::feature_save_web_ssl_file($d, 'cert', $d->{'ssl_cert'});
}, sub {
	is(nginx::find_value('ssl_certificate', virtualmin_nginx::find_domain_server($d)),
		$d->{'ssl_cert'}, 'certificate path is written');
});
$edit->('PHP disabled location', sub {
	virtualmin_nginx::feature_save_web_php_mode($d, 'none');
}, sub {
	my $s = virtualmin_nginx::find_domain_server($d);
	my $loc = nginx::find('location', $s);
	is(nginx::find_value('default_type', $loc), 'text/plain', 'PHP location is disabled');
});
$edit->('add redirect', sub {
	virtualmin_nginx::feature_create_web_redirect($d,
		{path => '/old', dest => 'https://example.com/new', http => 1, https => 1});
});
my ($redirect) = virtualmin_nginx::feature_list_web_redirects($d);
ok($redirect, 'redirect can be listed');
$edit->('delete previously listed redirect', sub {
	virtualmin_nginx::feature_delete_web_redirect($d, $redirect);
}, sub {
	my @redirects = virtualmin_nginx::feature_list_web_redirects($d);
	is(scalar(@redirects), 0, 'selected redirect is removed');
});
$edit->('add proxy', sub {
	virtualmin_nginx::feature_create_web_balancer($d,
		{path => '/proxy', urls => ['http://127.0.0.1:9000', 'http://127.0.0.1:9001']});
});
my ($balancer) = virtualmin_nginx::feature_list_web_balancers($d);
ok($balancer, 'balancer can be listed');
$edit->('modify previously listed proxy', sub {
	virtualmin_nginx::feature_modify_web_balancer($d,
		{path => '/proxy-new', urls => ['http://127.0.0.1:9002', 'http://127.0.0.1:9003']}, $balancer);
}, sub {
	my ($b) = virtualmin_nginx::feature_list_web_balancers($d);
	is_deeply($b->{'urls'}, ['http://127.0.0.1:9002', 'http://127.0.0.1:9003'],
		'upstream backends are updated');
});
($balancer) = virtualmin_nginx::feature_list_web_balancers($d);
is($balancer->{'path'}, '/proxy-new', 'proxy path is updated');
$edit->('delete previously listed proxy', sub {
	virtualmin_nginx::feature_delete_web_balancer($d, $balancer);
}, sub {
	my @balancers = virtualmin_nginx::feature_list_web_balancers($d);
	my @upstreams = nginx::find('upstream', nginx::find('http', nginx::get_config()));
	is(scalar(@balancers), 0, 'proxy location is removed');
	is(scalar(@upstreams), 0, 'unused upstream is removed');
});
$edit->('change document root', sub {
	virtualmin_nginx::feature_set_web_public_html_dir($d, 'other_html');
}, sub {
	is(nginx::find_value('root', virtualmin_nginx::find_domain_server($d)),
		"$tmp/other_html", 'document root is updated');
});
$edit->('change server names', sub {
	virtualmin_nginx::feature_save_web_server_names($d, ['beta.invalid', 'www.beta.invalid']);
}, sub {
	is_deeply(nginx::find('server_name', virtualmin_nginx::find_domain_server($d))->{'words'},
		['beta.invalid', 'www.beta.invalid'], 'server aliases are updated');
});
$edit->('add webmail redirects', sub {
	virtualmin_nginx::feature_add_web_webmail_redirect($d,
		{web_admin => 1, web_admindom => 'https://beta.invalid:10000/'});
});
$edit->('remove webmail redirects', sub {
	virtualmin_nginx::feature_remove_web_webmail_redirect($d);
}, sub {
	my @ifs = nginx::find('if', virtualmin_nginx::find_domain_server($d));
	is(scalar(@ifs), 0, 'webmail redirect blocks are removed');
});
subtest 'SSL setup with a nested certificate update' => sub {
	$other_writer->();
	virtualmin_nginx_ssl::feature_setup($d);
	$verify->();
	my $s = virtualmin_nginx::find_domain_server($d);
	is_deeply([map { $_->{'words'} } nginx::find('listen', $s)],
		[['127.0.0.1:80'], ['127.0.0.1:443', 'ssl']], 'SSL listener appears once');
	is(nginx::find_value('ssl_certificate', $s), $d->{'ssl_combined'},
		'nested update selects the combined certificate');
	virtualmin_nginx_ssl::feature_setup($d);
	$s = virtualmin_nginx::find_domain_server($d);
	is_deeply([map { $_->{'words'} } nginx::find('listen', $s)],
		[['127.0.0.1:80'], ['127.0.0.1:443', 'ssl']], 'repeated SSL setup does not duplicate listeners');
};
subtest 'invalid certificate does not retain the config lock' => sub {
	local *virtual_server::validate_cert_format = sub { return 'Invalid fixture certificate'; };
	is(virtualmin_nginx_ssl::feature_setup($d), 0, 'certificate validation fails');
	ok(!-e "$conf.lock", 'validation failure leaves the config unlocked');
};
subtest 'missing server does not retain the config lock' => sub {
	my $err = virtualmin_nginx::feature_save_web_ssl_file(
		{dom => 'missing.invalid'}, 'cert', $d->{'ssl_cert'});
	ok($err, 'missing server is reported');
	ok(!-e "$conf.lock", 'missing server leaves the config unlocked');
};

# CGI setup can take long enough for another domain to move the cached server.
# Exercise both paths separately so a failed edit cannot spoil the next case.
foreach my $enable (1, 0) {
	subtest $enable ? 'enable CGI after a competing edit' :
			 'disable CGI after a competing edit' => sub {
		open(my $fh, '>', $conf) or die $!;
		print $fh "http {\n";
		foreach my $name ('alpha.invalid', 'beta.invalid') {
			print $fh "    server {\n        server_name $name;\n".
				"        listen 127.0.0.1:80;\n        root $tmp/public_html;\n";
			print $fh "        location /cgi-bin/ {\n".
				"            fastcgi_pass unix:$tmp/$name.sock;\n        }\n"
				if $name eq 'alpha.invalid' || !$enable;
			print $fh "    }\n";
			}
		print $fh "}\n";
		close($fh);
		nginx::unflush_file_lines($conf);
		nginx::flush_config_cache();
		$writes = 0;
		my $cgi_domain = { %$d };
		$cgi_domain->{'nginx_fcgiwrap_port'} = "$tmp/beta.invalid.sock" if !$enable;
		local *virtualmin_nginx::setup_fcgiwrap_server = sub {
			return (1, "$tmp/beta.invalid.sock");
			};
		local *virtualmin_nginx::delete_fcgiwrap_server = sub {};
		local *virtual_server::lock_domain = sub {};
		local *virtual_server::save_domain = sub {};
		local *virtual_server::unlock_domain = sub {};
		$other_writer->(40);
		my $save = \&nginx::save_directive;
		local *nginx::save_directive = sub {
			ok(-e "$conf.lock", 'CGI writes hold the config lock');
			return $save->(@_);
			};
		is(virtualmin_nginx::feature_web_save_domain_cgi_mode(
			$cgi_domain, $enable ? 'fcgiwrap' : ''), undef, 'CGI change succeeds');
		$verify->();
		foreach my $name ('alpha.invalid', 'beta.invalid') {
			my $s = virtualmin_nginx::find_domain_server({ dom => $name });
			ok($s, "$name remains present") or next;
			my @cgi = grep { $_->{'words'}->[0] eq '/cgi-bin/' }
				nginx::find('location', $s);
			is(scalar(@cgi), $name eq 'alpha.invalid' || $enable ? 1 : 0,
				"$name has the expected CGI location count");
			is(nginx::find_value('fastcgi_pass', $cgi[0]), "unix:$tmp/$name.sock",
				"$name keeps its own CGI socket") if @cgi;
			}
		};
	}
}

done_testing();
