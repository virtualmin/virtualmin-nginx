# Virtualmin API plugins for Nginx

use strict;
use warnings;
require 'virtualmin-nginx-lib.pl';
our (%text, %config, $module_name);

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
	if ($d->{'virt6'}) {
		push(@{$server->{'members'}},
			{ 'name' => 'listen',
			  'words' => [ "[".$d->{'ip6'}."]" ] });
		}

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
	&virtual_server::link_apache_logs($d, $alog, $elog);
	&virtual_server::register_post_action(\&print_apply_nginx);
	&$virtual_server::second_print($virtual_server::text{'setup_done'});

	# Set up fcgid server
	&$virtual_server::first_print($text{'feat_phpfcgid'});
	my ($ok, $port) = &setup_php_fcgi_server($d);
	if ($ok) {
		# Configure domain to use it for .php files
		&lock_all_config_files();
		&save_directive($server, "fastcgi_param",
			[ map { { 'words' => $_ } } &list_fastcgi_params() ]);
		my $ploc = { 'name' => 'location',
			     'words' => [ '~', '\.php$' ],
			     'type' => 1,
			     'members' => [
				{ 'name' => 'fastcgi_pass',
				  'words' => [ 'localhost:'.$port ],
				},
			     ],
			   };
		&save_directive($server, [ ], [ $ploc ]);
		&flush_config_file_lines();
		&unlock_all_config_files();
		&$virtual_server::second_print(
			$virtual_server::text{'setup_done'});
		}
	else {
		delete($d->{'nginx_php_port'});
		&$virtual_server::second_print(&text('feat_failed', $port));
		}


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

# feature_modify(&domain, &old-domain)
# Change the Nginx domain name or home directory
sub feature_modify
{
my ($d, $oldd) = @_;

if (!$d->{'alias'}) {
	# Changing a real virtual host
	&lock_all_config_files();
	my $changed = 0;

	# Update domain name in server_name
	if ($d->{'dom'} ne $oldd->{'dom'}) {
		&$virtual_server::first_print($text{'feat_modifydom'});
		my $server = &find_domain_server($oldd);
		if (!$server) {
			&$virtual_server::second_print(
				&text('feat_efind', $oldd->{'dom'}));
			return 0;
			}
		my $obj = &find("server_name", $server);
		foreach my $n (&domain_server_names($oldd)) {
			@{$obj->{'words'}} = grep { $_ ne $n }
						  @{$obj->{'words'}};
			}
		foreach my $n (&domain_server_names($d)) {
			if (&indexoflc($n, @{$obj->{'words'}}) < 0) {
				push(@{$obj->{'words'}}, $n);
				}
			}
		&save_directive($server, "server_name", [ $obj ]);
		&$virtual_server::second_print(
			$virtual_server::text{'setup_done'});
		$changed++;
		}

	# Update home directory in all directives
	if ($d->{'home'} ne $oldd->{'home'}) {
		&$virtual_server::first_print($text{'feat_modifyhome'});
		my $server = &find_domain_server($d);
		if (!$server) {
			&$virtual_server::second_print(
				&text('feat_efind', $d->{'dom'}));
			return 0;
			}
		&recursive_change_directives(
			$server, $oldd->{'home'}, $d->{'home'}, 0, 1);
		&$virtual_server::second_print(
			$virtual_server::text{'setup_done'});
		$changed++;
		}

	# Update IPv4 address
	if ($d->{'ip'} ne $oldd->{'ip'}) {
		&$virtual_server::first_print($text{'feat_modifyip'});
		my $server = &find_domain_server($d);
		if (!$server) {
			&$virtual_server::second_print(
				&text('feat_efind', $d->{'dom'}));
			return 0;
			}
		my @listen = &find("listen", $server);
		foreach my $l (@listen) {
			if ($l->{'words'}->[0] eq $oldd->{'ip'}) {
				$l->{'words'}->[0] = $d->{'ip'};
				}
			elsif ($l->{'words'}->[0] =~ /^(\S+):(\d+)$/ &&
			       $1 eq $oldd->{'ip'}) {
				$l->{'words'}->[0] = $d->{'ip'}.":".$2;
				}
			}
		&save_directive($server, "listen", \@listen);
		&$virtual_server::second_print(
			$virtual_server::text{'setup_done'});
		$changed++;
		}

	# Update IPv6 address (or add or remove)
	if ($d->{'ip6'} ne $oldd->{'ip6'} ||
	    $d->{'virt6'} != $oldd->{'virt6'}) {
		&$virtual_server::first_print($text{'feat_modifyip6'});
		my $server = &find_domain_server($d);
		if (!$server) {
			&$virtual_server::second_print(
				&text('feat_efind', $d->{'dom'}));
			return 0;
			}
		my @listen = &find("listen", $server);
		my @newlisten;
		my $ob = $oldd->{'virt6'} ? "[".$oldd->{'ip6'}."]" : "";
		my $nb = $d->{'virt6'} ? "[".$d->{'ip6'}."]" : "";
		foreach my $l (@listen) {
			my @w = @{$l->{'words'}};
			if ($ob && $w[0] eq $ob) {
				# Found old address with no port - replace
				# or remove
				if ($nb) {
					$w[0] = $nb;
					push(@newlisten, { 'words' => \@w });
					}
				}
			elsif ($ob && $w[0] =~ /^\Q$ob\E:(\d+)$/) {
				# Found old address with a port - replace with
				# same port or remove
				if ($nb) {
					$w[0] = $nb.":".$1;
					push(@newlisten, { 'words' => \@w });
					}
				}
			else {
				# Found un-related address, save it
				push(@newlisten, { 'words' => \@w });
				}
			}
		if ($d->{'virt6'} && !$oldd->{'virt6'}) {
			push(@newlisten, { 'words' => [ $nb ] });
			}
		&save_directive($server, "listen", \@newlisten);
		&$virtual_server::second_print(
			$virtual_server::text{'setup_done'});
		$changed++;
		}

	# Rename log files if needed
	my $old_alog = &get_nginx_log($d, 0);
	my $old_elog = &get_nginx_log($d, 1);
	my $new_alog = &virtual_server::get_apache_template_log($d, 0);
	my $new_elog = &virtual_server::get_apache_template_log($d, 1);
	if ($old_alog ne $new_alog) {
		&$virtual_server::first_print($text{'feat_modifylog'});
		my $server = &find_domain_server($d);
		if (!$server) {
			&$virtual_server::second_print(
				&text('feat_efind', $oldd->{'dom'}));
			return 0;
			}
		&save_directive($server, "access_log", [ $new_alog ]);
		&rename_logged($old_alog, $new_alog);
		if ($old_elog ne $new_elog) {
			&save_directive($server, "error_log", [ $new_elog ]);
			&rename_logged($old_elog, $new_elog);
			}
		&virtual_server::link_apache_logs($d, $new_alog, $new_elog);
		&$virtual_server::second_print(
			$virtual_server::text{'setup_done'});
		}

	# Flush files and restart
	&flush_config_file_lines();
	&unlock_all_config_files();
	if ($changed) {
		&virtual_server::register_post_action(\&print_apply_nginx);
		}

	# Rename config file name, if changed
	if ($d->{'dom'} ne $oldd->{'dom'}) {
		my $newfile = &get_add_to_file($d->{'dom'});
		my $server = &find_domain_server($d);
		if ($server->{'file'} ne $newfile &&
		    $server->{'file'} =~ /\Q$oldd->{'dom'}\E/) {
			&$virtual_server::first_print($text{'feat_modifyfile'});
			&delete_server_link($server);
			&rename_logged($server->{'file'}, $newfile);
			$server->{'file'} = $newfile;
			&create_server_link($server);
			&flush_config_cache();
			&$virtual_server::second_print(
				$virtual_server::text{'setup_done'});
			}
		}

	# Update fcgid user, by tearing down and re-running. Killing needs to
	# be done in the new home, as it may have been moved already
	if ($d->{'user'} ne $oldd->{'user'}) {
		my $oldd_copy = { %$oldd };
		$oldd_copy->{'home'} = $d->{'home'};
		&delete_php_fcgi_server($oldd_copy);
		&delete_php_fcgi_server($oldd);
		&setup_php_fcgi_server($d);
		}
	}
else {
	# Changing inside an alias
	&lock_all_config_files();
	my $changed = 0;

	# Change domain name in alias target
	if ($d->{'dom'} ne $oldd->{'dom'}) {
		&$virtual_server::first_print($text{'feat_modifyalias'});
		my $target = &virtual_server::get_domain($d->{'alias'});
		my $server = &find_domain_server($target);
		if (!$server) {
			&unlock_all_config_files();
			&$virtual_server::second_print(
				&text('feat_efind', $target->{'dom'}));
			return 0;
			}
		my $obj = &find("server_name", $server);
		foreach my $n (&domain_server_names($oldd)) {
			@{$obj->{'words'}} = grep { $_ ne $n }
						  @{$obj->{'words'}};
			}
		foreach my $n (&domain_server_names($d)) {
			push(@{$obj->{'words'}}, $n);
			}
		&save_directive($server, "server_name", [ $obj ]);
		$changed++;
		&$virtual_server::second_print(
			$virtual_server::text{'setup_done'});
		}

	# Flush files and restart
	&flush_config_file_lines();
	&unlock_all_config_files();
	if ($changed) {
		&virtual_server::register_post_action(\&print_apply_nginx);
		}

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
	&delete_php_fcgi_server($d);
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

# feature_disable(&domain)
# Disable the website by adding a redirect from /
sub feature_disable
{
my ($d) = @_;
if ($d->{'alias'}) {
	# Disabling is the same as deletion for an alias
	my $target = &virtual_server::get_domain($d->{'alias'});
	if ($target->{'disabled'}) {
		return 1;
		}
	$d->{'disable_alias_nginx_delete'} = 1;
	return &feature_delete($d);
	}
else {
	&$virtual_server::first_print($text{'feat_disable'});
	&lock_all_config_files();
	my $server = &find_domain_server($d);
	if (!$server) {
                &unlock_all_config_files();
                &$virtual_server::second_print(
                        &text('feat_efind', $d->{'dom'}));
                return 0;
		}
	my $tmpl = &virtual_server::get_template($d->{'template'});
	my @locs = &find("location", $server);
	my ($clash) = grep { $_->{'words'}->[0] eq '~' &&
			     $_->{'words'}->[1] eq '/.*' } @locs;

	if ($tmpl->{'disabled_url'} eq 'none') {
		# Disable is done via local HTML
		my $dis = &virtual_server::disabled_website_html($d);
		my $msg = $tmpl->{'disabled_web'} eq 'none' ?
			"<h1>Website Disabled</h1>\n" :
			join("\n", split(/\t/, $tmpl->{'disabled_web'}));
		$msg = &virtual_server::substitute_domain_template($msg, $d);
		my $fh = "DISABLED";
		&open_lock_tempfile($fh, ">$dis");
		&print_tempfile($fh, $msg);
		&close_tempfile($fh);
		&set_ownership_permissions(
			undef, undef, 0644, $virtual_server::disabled_website);

		# Add location to force use of it
		if (!$clash) {
			$dis =~ /^(.*)(\/[^\/]+)$/;
			my ($disdir, $disfile) = ($1, $2);
			my $loc =
			    { 'name' => 'location',
			      'words' => [ '~', '/.*' ],
			      'type' => 1,
			      'members' => [
				{ 'name' => 'root',
				  'words' => [ $disdir ] },
				{ 'name' => 'rewrite',
				  'words' => [ '^/.*', $disfile, 'break' ] },
			      ],
			    };
			&save_directive($server, [ ], [ $loc ], 1);
			}
		}
	else {
		# Disable is done via redirect
		my $url = &virtual_server::substitute_domain_template(
				$tmpl->{'disabled_url'}, $d);
		if (!$clash) {
			my $loc =
			    { 'name' => 'location',
			      'words' => [ '~', '/.*' ],
			      'type' => 1,
			      'members' => [
				{ 'name' => 'rewrite',
				  'words' => [ '^/.*', $url, 'break' ] },
			      ],
			    };
			&save_directive($server, [ ], [ $loc ], 1);
			}
		}

	&flush_config_file_lines();
        &unlock_all_config_files();
        &virtual_server::register_post_action(\&print_apply_nginx);

	&$virtual_server::second_print($virtual_server::text{'setup_done'});
	}
}

# feature_enable(&domain)
# Undo the effects of feature_disable
sub feature_enable
{
my ($d) = @_;
if ($d->{'alias'}) {
	# Enabling alias is the same as re-setting it up
	if ($d->{'disable_alias_nginx_delete'}) {
		delete($d->{'disable_alias_nginx_delete'});
		return &feature_setup($d);
		}
	return 1;
	}
else {
	&$virtual_server::first_print($text{'feat_enable'});
	&lock_all_config_files();
	my $server = &find_domain_server($d);
	if (!$server) {
                &unlock_all_config_files();
                &$virtual_server::second_print(
                        &text('feat_efind', $d->{'dom'}));
                return 0;
		}

	my @locs = &find("location", $server);
	my ($loc) = grep { $_->{'words'}->[0] eq '~' &&
			   $_->{'words'}->[1] eq '/.*' } @locs;
	if ($loc) {
		my $rewrite = &find_value("rewrite", $loc);
		if ($rewrite eq '^/.*') {
			&save_directive($server, [ $loc ], [ ]);
			}
		}

	&flush_config_file_lines();
        &unlock_all_config_files();
        &virtual_server::register_post_action(\&print_apply_nginx);

	&$virtual_server::second_print($virtual_server::text{'setup_done'});
	}
}

# feature_validate(&domain)
# Checks if this feature is properly setup for the virtual server, and returns
# an error message if any problem is found
sub feature_validate
{
my ($d) = @_;

# Does server exist?
my $server = &find_domain_server($d);
return &text('feat_evalidate',
	"<tt>".&virtual_server::show_domain_name($d)."</tt>") if (!$server);

# Check root directory
if (!$d->{'alias'}) {
	my $rootdir = &find_value("root", $server);
	my $phd = &virtual_server::public_html_dir($d);
	return &text('feat_evalidateroot',
		      "<tt>".&html_escape($rootdir)."</tt>",
		      "<tt>".&html_escape($phd)."</tt>") if ($rootdir ne $phd);
	}

# Is alias target what we expect?
if ($d->{'alias'}) {
	my $target = &virtual_server::get_domain($d->{'alias'});
	my $targetserver = &find_domain_server($target);
	return &text('feat_evalidatetarget',
		     "<tt>".&virtual_server::show_domain_name($target)."</tt>")
		if (!$targetserver);
	return &text('feat_evalidatediff',
		     "<tt>".&virtual_server::show_domain_name($target)."</tt>")
		if ($targetserver ne $server);
	}

# Check for IPs
if (!$d->{'alias'}) {
	my @listen = &find_value("listen", $server);
	my $found = 0;
	foreach my $l (@listen) {
		$found++ if ($l eq $d->{'ip'} ||
			     $l =~ /^\Q$d->{'ip'}\E:/);
		}
	$found || return &text('feat_evalidateip', $d->{'ip'});
	if ($d->{'virt6'}) {
		my $found6 = 0;
		foreach my $l (@listen) {
			$found6++ if ($l eq "[".$d->{'ip6'}."]" ||
				      $l =~ /^\[\Q$d->{'ip'}\E\]:/);
			}
		$found6 || return &text('feat_evalidateip6', $d->{'ip6'});
		}
	}

return undef;
}

# feature_webmin(&main-domain, &all-domains)
# Returns a list of webmin module names and ACL hash references to be set for
# the Webmin user when this feature is enabled
# (optional)
sub feature_webmin
{
my ($d, $alld) = @_;
my @doms = map { $_->{'dom'} } grep { $_->{$module_name} } @$alld;
if (@doms) {
	return ( [ $module_name,
		   { 'vhosts' => join(' ', @doms),
		     'root' => $d->{'home'},
		     'global' => 0,
		     'logs' => 0,
		     'user' => $d->{'user'},
		     'edit' => 0,
		     'stop' => 0,
		   } ] );
	}
else {
	return ( );
	}
}

# feature_links(&domain)
# Returns an array of link objects for webmin modules for this feature
sub feature_links
{
my ($d) = @_;
my $server = &find_domain_server($d);
return ( ) if (!$server);
return ( { 'mod' => $module_name,
	   'desc' => $text{'feat_edit'},
	   'page' => 'edit_server.cgi?id='.&server_id($server),
	   'cat' => 'services' } );
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

# feature_provides_web()
sub feature_provides_web
{
return 1;	# Nginx is a webserver
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

