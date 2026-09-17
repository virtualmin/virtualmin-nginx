#!/usr/bin/perl
# Run the real creation CGI with form input on a disposable VM.

use strict;
use warnings;
no warnings 'once';
use File::Basename ();
use File::Temp ();

die "Enable VIRTUALMIN_NGINX_CONCURRENT_TEST on a disposable Linux VM\n"
	unless $ENV{'VIRTUALMIN_NGINX_CONCURRENT_TEST'} && $^O eq 'linux' && $> == 0;
my ($domain, $passfile, $template) = @ARGV;
die "domain, password file and template required\n"
	unless $domain && $passfile && defined($template);
my ($root) = grep { -f "$_/WebminCore.pm" }
	($ENV{'WEBMIN_ROOT'} || '', '/usr/libexec/webmin', '/usr/share/webmin');
die "Webmin root not found\n" unless $root;
$ENV{'WEBMIN_CONFIG'} ||= '/etc/webmin';
$ENV{'WEBMIN_VAR'} ||= '/var/webmin';
# Theme rendering depends on MiniServ callbacks that direct CGI execution lacks.
$ENV{'THEME_DIRS'} = '';
$ENV{'SERVER_ROOT'} = $root;
$ENV{'SCRIPT_FILENAME'} = "$root/virtual-server/domain_setup.cgi";
$ENV{'REMOTE_USER'} = $ENV{'BASE_REMOTE_USER'} = 'root';
$ENV{'SCRIPT_NAME'} = '/virtual-server/domain_setup.cgi';
$ENV{'SERVER_NAME'} = 'localhost';
$ENV{'SERVER_PORT'} = 10000;
$ENV{'HTTP_HOST'} = 'localhost:10000';
$ENV{'REQUEST_URI'} = '/virtual-server/domain_setup.cgi';
$ENV{'HTTPS'} = 'ON';
$ENV{'REMOTE_ADDR'} = '127.0.0.1';
$ENV{'HTTP_REFERER'} = 'https://localhost:10000/virtual-server/';
chdir("$root/virtual-server") or die $!;
$0 = "$root/virtual-server/domain_setup.cgi";
unshift(@INC, $root);

# Use the same root execution context as the CLI, then let the CGI validate
# the submitted fields and create the domain without stubbing its functions.
package virtual_server;
$main::no_acl_check = 1;
$main::error_must_die = 1;
require './virtual-server-lib.pl';
die "Fixture domain already exists\n" if get_domain_by('dom', $domain);
my $tmpl = get_template($template);
die "Fixture template must disable emails and ACME\n"
	if $tmpl->{'mail_on'} ne 'none' || $tmpl->{'ssl_auto_letsencrypt'};
my $plan = get_default_plan();
my %form = (
	dom => $domain, owner => 'Nginx CGI concurrency test',
	template => $template, plan => $plan->{'id'},
	vpass => read_file_contents($passfile),
	vuser_def => 1, mgroup_def => 1, group_def => 1, email_def => 1,
	prefix_def => 1, db_def => 1, quota_def => 1, uquota_def => 1,
	bwlimit_def => 1, mailboxlimit_def => 1, aliaslimit_def => 1,
	dbslimit_def => 1, doms_def => 1, dns_ip_def => 1, dns_ip6_def => 1,
	virt => 0, virt6 => get_default_ip6() ? 0 : -2,
	confirm_warnings => 1,
);
$form{'vpass'} =~ s/\r?\n\z//;
foreach my $f (list_available_features()) {
	$form{$f->{'feature'}} = 1 if $f->{'default'} && $f->{'enabled'};
}
my $body = join('&', map { urlize($_).'='.urlize($form{$_}) } sort keys %form);
$ENV{'CONTENT_TYPE'} = 'application/x-www-form-urlencoded';
$ENV{'CONTENT_LENGTH'} = length($body);
$ENV{'REQUEST_METHOD'} = 'POST';
$ENV{'QUERY_STRING'} = '';
my ($input, $input_file) = File::Temp::tempfile('domain-form-XXXXXX',
	DIR => File::Basename::dirname($passfile), UNLINK => 0);
print $input $body;
close($input) or die "form input: $!";
open(STDIN, '<', $input_file) or die "form input: $!";
unlink($input_file);
do './domain_setup.cgi';
die $@ if $@;
die "CGI did not create the domain\n" unless get_domain_by('dom', $domain);
