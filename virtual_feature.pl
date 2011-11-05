# Virtualmin API plugins for Nginx

use strict;
use warnings;
require 'virtualmin-nginx-lib.pl';
our (%text, %config);

# feature_name()
# Returns a short name for this feature
sub feature_name
{
return $text{'feat_name'};
}

# feature_losing(&domain)
# Returns a description of what will be deleted when this feature is removed
sub feature_losing
{
return $text{'feat_losing'};
}

# feature_disname(&domain)
# Returns a description of what will be turned off when this feature is disabled
sub feature_disname
{
return $text{'feat_disname'};
}

# feature_label(in-edit-form)
# Returns the name of this feature, as displayed on the domain creation and
# editing form
sub feature_label
{
return $text{'feat_label'};
}

sub feature_hlink
{
return "label";
}

# feature_check()
# Checks if Nginx is actually installed, returns an error if not
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

# feature_depends(&domain)
# Nginx needs a Unix login for the domain
sub feature_depends
{
my ($d) = @_;
return $text{'feat_edepunix'} if (!$d->{'unix'} && !$d->{'parent'});
return $text{'feat_edepdir'} if (!$d->{'dir'} && !$d->{'alias'});
return $text{'feat_eapache'} if ($d->{'web'});
return undef;
}

# feature_clash(&domain, [field])
# Returns undef if there is no clash for this domain for this feature, or
# an error message if so
sub feature_clash
{
my ($d, $field) = @_;
if (!$field || $field eq 'dom') {
	my $s = &find_domain_server($d);
	return $text{'feat_clash'} if ($s);
	}
return undef;
}

# feature_suitable([&parentdom], [&aliasdom], [&subdom])
# Returns 1 if some feature can be used with the specified alias and
# parent domains
sub feature_suitable
{
my ($parentdom, $aliasdom, $subdom) = @_;
return $subdom ? 0 : 1;
}

# feature_import(domain-name, user-name, db-name)
# Returns 1 if this feature is already enabled for some domain being imported,
# or 0 if not
sub feature_import
{
my ($dname, $user, $db) = @_;
return &find_domain_server({ 'dom' => $dname }) ? 1 : 0;
}

# feature_setup(&domain)
# Called when this feature is added, with the domain object as a parameter
sub feature_setup
{
my ($d) = @_;

if (!$d->{'alias'}) {
	# Create a whole new server
	&$virtual_server::first_print($text{'feat_setup'});
	&lock_all_config_files();
	my $conf = &get_config();
	my $http = &find("http", $conf);

	# Create the server object
	my $server = { 'name' => 'server',
                       'type' => 1,
                       'words' => [ ],
                       'members' => [ ] };
	$server->{'file'} = &get_add_to_file($d->{'dom'});

	# Add domain name field
	push(@{$server->{'members'}},
		{ 'name' => 'server_name',
		  'words' => [ &domain_server_names($d) ] });

	# Add listen on the correct IP
	push(@{$server->{'members'}},
		{ 'name' => 'listen',
		  'words' => [ $d->{'ip'} ] });

	# Set the root correctly
	push(@{$server->{'members'}},
		{ 'name' => 'root',
		  'words' => [ &virtual_server::public_html_dir($d) ] });

	# Allow sensible index files
	push(@{$server->{'members'}},
                { 'name' => 'index',
		  'words' => [ 'index.html', 'index.htm', 'index.php' ] });

	# Add a location for the root
	push(@{$server->{'members'}},
		{ 'name' => 'location',
		  'words' => [ '/' ],
		  'type' => 1,
		  'members' => [
			{ 'name' => 'root',
			  'words' => [ &virtual_server::public_html_dir($d) ] },			],
		});

	# Add log files
	my $alog = &virtual_server::get_apache_template_log($d, 0);
	push(@{$server->{'members'}},
                { 'name' => 'access_log',
		  'words' => [ $alog ] });
	my $elog = &virtual_server::get_apache_template_log($d, 1);
	push(@{$server->{'members'}},
                { 'name' => 'error_log',
		  'words' => [ $elog ] });

	&save_directive($http, [ ], [ $server ]);
	&flush_config_file_lines();
	&unlock_all_config_files();
	&create_server_link($server);
	&virtual_server::setup_apache_logs($d, $alog, $elog);
	&virtual_server::register_post_action(\&print_apply_nginx);

	# Set up fcgid server
	# XXX

	&$virtual_server::second_print($virtual_server::text{'setup_done'});

	# Add the user nginx runs as to the domain's group
	my $web_user = &get_nginx_user();
	if ($web_user) {
		&virtual_server::add_user_to_domain_group(
			$d, $web_user, 'setup_webuser');
		}

	return 1;
	}
else {
	# Add to existing one as an alias
	&$virtual_server::first_print($text{'feat_setupalias'});
	&lock_all_config_files();
	my $target = &virtual_server::get_domain($d->{'alias'});
	my $server = &find_domain_server($target);
	if (!$server) {
		&unlock_all_config_files();
		&$virtual_server::second_print(
			&text('feat_efind', $target->{'dom'}));
		return 0;
		}

	my $obj = &find("server_name", $server);
	foreach my $n (&domain_server_names($d)) {
		if (&indexoflc($n, @{$obj->{'words'}}) < 0) {
			push(@{$obj->{'words'}}, $n);
			}
		}
	&save_directive($server, "server_name", [ $obj ]);

	&flush_config_file_lines();
	&unlock_all_config_files();
	&virtual_server::register_post_action(\&print_apply_nginx);

	&$virtual_server::second_print($virtual_server::text{'setup_done'});
	return 1;
	}
}

# feature_delete(&domain)
# Remove the Nginx virtual host for a domain
sub feature_delete
{
my ($d) = @_;

if (!$d->{'alias'}) {
	# Remove the whole server
	&$virtual_server::first_print($text{'feat_delete'});
	&lock_all_config_files();
	my $conf = &get_config();
	my $http = &find("http", $conf);
	my $server = &find_domain_server($d);
	if (!$server) {
                &unlock_all_config_files();
                &$virtual_server::second_print(
                        &text('feat_efind', $d->{'dom'}));
                return 0;
		}
	my $alog = &get_nginx_log($d, 0);
	my $elog = &get_nginx_log($d, 1);
	&save_directive($http, [ $server ], [ ]);
	&flush_config_file_lines();
	&unlock_all_config_files();
	&delete_server_link($server);
	&delete_server_file_if_empty($server);
	&virtual_server::register_post_action(\&print_apply_nginx);
	&$virtual_server::second_print($virtual_server::text{'setup_done'});

	# Remove log files too, if outside home
	if ($alog && !&is_under_directory($d->{'home'}, $alog)) {
		&$virtual_server::first_print($text{'feat_deletelogs'});
		&unlink_file($alog);
		if ($elog && !&is_under_directory($d->{'home'}, $elog)) {
			&unlink_file($elog);
			}
		&$virtual_server::second_print(
			$virtual_server::text{'setup_done'});
		}

	return 1;
	}
else {
	# Delete from alias
	&$virtual_server::first_print($text{'feat_deletealias'});
	&lock_all_config_files();
	my $target = &virtual_server::get_domain($d->{'alias'});
	my $server = &find_domain_server($target);
	if (!$server) {
		&unlock_all_config_files();
		&$virtual_server::second_print(
			&text('feat_efind', $target->{'dom'}));
		return 0;
		}

	my $obj = &find("server_name", $server);
	foreach my $n (&domain_server_names($d)) {
		@{$obj->{'words'}} = grep { $_ ne $n } @{$obj->{'words'}};
		}
	&save_directive($server, "server_name", [ $obj ]);

	&flush_config_file_lines();
	&unlock_all_config_files();
	&virtual_server::register_post_action(\&print_apply_nginx);

	&$virtual_server::second_print($virtual_server::text{'setup_done'});
	return 1;
	}
}

# print_apply_nginx()
# Restart Nginx, and print a message
sub print_apply_nginx
{
&$virtual_server::first_print($text{'feat_apply'});
if (&is_nginx_running()) {
	my $test = &test_config();
	if ($test) {
		&$virtual_server::second_print(
		    &text('feat_econfig', "<tt>".&html_escape($test)."</tt>"));
		}
	else {
		my $err = apply_nginx();
		if ($err) {
			&$virtual_server::second_print(
			    &text('feat_eapply',
				  "<tt>".&html_escape($test)."</tt>"));
			}
		else {
			&$virtual_server::second_print(
				$virtual_server::text{'setup_done'});
			}
		}
	}
else {
	&$virtual_server::second_print($text{'feat_notrunning'});
	}
}

# domain_server_names(&domain)
# Returns the list of server_name words for a domain
sub domain_server_names
{
my ($d) = @_;
return ( $d->{'dom'}, "www.".$d->{'dom'} );
}

# get_nginx_log(&domain, [errorlog])
# Returns the location of a log file for a domain's virtual host, or undef.
sub get_nginx_log
{
my ($d, $want_error) = @_;
my $s = &find_domain_server($d);
if ($s) {
	return &find_value($want_error ? "error_log" : "access_log", $s);
	}
return undef;
}

# get_nginx_user()
# Returns the use nginx runs as
sub get_nginx_user
{
my $conf = &get_config();
my $user = &find_value("user", $conf);
$user ||= &get_default("user");
return $user;
}

1;

