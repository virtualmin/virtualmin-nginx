use strict;
use warnings;
no warnings 'uninitialized';
BEGIN { push(@INC, ".."); };
eval "use WebminCore;";

our (%config, $config_directory, $module_config_file);
&init_config();

# module_install()
# Entry point called by Webmin after module install or upgrade
sub module_install
{
&migrate_to_stock_nginx_module();
}

# migrate_to_stock_nginx_module()
# Moves shared Webmin Nginx config and ACLs from the legacy Virtualmin plugin
# namespace to the stock nginx module
sub migrate_to_stock_nginx_module
{
my $oldmod = "virtualmin-nginx";
my $newmod = "nginx";
return if ($config{'stock_nginx_migrated'});
return if (!&foreign_check($newmod));

&migrate_to_stock_nginx_config($oldmod, $newmod);
&migrate_to_stock_nginx_virtualmin_config($oldmod, $newmod);
&migrate_to_stock_nginx_acls($oldmod, $newmod);

$config{'stock_nginx_migrated'} = 1;
&lock_file($module_config_file);
&save_module_config(\%config, $oldmod);
&unlock_file($module_config_file);
}

# migrate_to_stock_nginx_config(old-module, new-module)
# Copies shared Nginx service/config paths into the stock nginx module config,
# then removes those shared keys from this wrapper module
sub migrate_to_stock_nginx_config
{
my ($oldmod, $newmod) = @_;
my @shared = qw(nginx_config add_to add_link nginx_cmd start_cmd stop_cmd
		apply_cmd pid_file extra_dirs);
my %nginx_config = &foreign_config($newmod);
my $changed_nginx = 0;

foreach my $k (@shared) {
	next if (!exists($config{$k}));
	if (!exists($nginx_config{$k}) || $nginx_config{$k} ne $config{$k}) {
		$nginx_config{$k} = $config{$k};
		$changed_nginx = 1;
		}
	delete($config{$k});
	}

if ($changed_nginx) {
	my $nginx_config_file = "$config_directory/$newmod/config";
	&lock_file($nginx_config_file);
	&save_module_config(\%nginx_config, $newmod);
	&unlock_file($nginx_config_file);
	}
}

# migrate_to_stock_nginx_virtualmin_config(old-module, new-module)
# Re-points Virtualmin global, template and domain-owner module references from
# the wrapper module to the stock nginx module
sub migrate_to_stock_nginx_virtualmin_config
{
my ($oldmod, $newmod) = @_;
return if (!&foreign_check("virtual-server"));

my %vconfig = &foreign_config("virtual-server");
my $changed = 0;
my $oldavail = "avail_".$oldmod;
my $newavail = "avail_".$newmod;

if (exists($vconfig{$oldavail})) {
	if (!exists($vconfig{$newavail}) || $vconfig{$newavail} eq "") {
		$vconfig{$newavail} = $vconfig{$oldavail};
		}
	delete($vconfig{$oldavail});
	$changed = 1;
	}

if (defined($vconfig{'webmin_modules'})) {
	my ($modules, $mchanged) =
		&replace_module_list($vconfig{'webmin_modules'},
				     $oldmod, $newmod);
	if ($mchanged) {
		$vconfig{'webmin_modules'} = $modules;
		$changed = 1;
		}
	}

if ($changed) {
	my $vconfig_file = "$config_directory/virtual-server/config";
	&lock_file($vconfig_file);
	&save_module_config(\%vconfig, "virtual-server");
	&unlock_file($vconfig_file);
	}

my $templates_dir = "$config_directory/virtual-server/templates";
if (opendir(my $dir, $templates_dir)) {
	foreach my $f (readdir($dir)) {
		next if ($f eq "." || $f eq "..");
		my $file = "$templates_dir/$f";
		next if (!-f $file);
		my %tmpl;
		&lock_file($file);
		if (&read_file($file, \%tmpl)) {
			my $tchanged = 0;
			if (defined($tmpl{'avail'})) {
				my ($avail, $achanged) =
					&replace_avail_module($tmpl{'avail'},
							      $oldmod,
							      $newmod);
				if ($achanged) {
					$tmpl{'avail'} = $avail;
					$tchanged = 1;
					}
				}
			if (defined($tmpl{'webmin_modules'})) {
				my ($modules, $mchanged) =
					&replace_module_list(
						$tmpl{'webmin_modules'},
						$oldmod, $newmod);
				if ($mchanged) {
					$tmpl{'webmin_modules'} = $modules;
					$tchanged = 1;
					}
				}
			&write_file($file, \%tmpl) if ($tchanged);
			}
		&unlock_file($file);
		}
	closedir($dir);
	}

my $domains_dir = "$config_directory/virtual-server/domains";
if (opendir(my $dir, $domains_dir)) {
	foreach my $f (readdir($dir)) {
		next if ($f eq "." || $f eq "..");
		my $file = "$domains_dir/$f";
		next if (!-f $file);
		my %dom;
		&lock_file($file);
		if (&read_file($file, \%dom) &&
		    defined($dom{'webmin_modules'})) {
			my ($modules, $mchanged) =
				&replace_module_list($dom{'webmin_modules'},
						     $oldmod, $newmod);
			if ($mchanged) {
				$dom{'webmin_modules'} = $modules;
				&write_file($file, \%dom);
				}
			}
		&unlock_file($file);
		}
	closedir($dir);
	}
}

# migrate_to_stock_nginx_acls(old-module, new-module)
# Keeps the wrapper module enabled where it was already granted, adds the stock
# nginx module beside it, and migrates shared ACL values to the stock module
sub migrate_to_stock_nginx_acls
{
my ($oldmod, $newmod) = @_;
return if (!&foreign_check("acl"));
&foreign_require("acl");
my $have_virtual_server = &foreign_check("virtual-server");
&foreign_require("virtual-server") if ($have_virtual_server);

foreach my $user (&acl::list_users()) {
	my $changed = 0;
	foreach my $k ("modules", "ownmods") {
		my ($modules, $mchanged) =
			&add_acl_module($user->{$k}, $oldmod, $newmod);
		if ($mchanged) {
			$user->{$k} = $modules;
			$changed = 1;
			}
		}
	&acl::modify_user($user->{'name'}, $user) if ($changed);
	my $domain = $have_virtual_server ?
		&virtual_server::get_domain_by("user", $user->{'name'},
					       "parent", "") : undef;
	my $domain_user = $user->{'readonly'} eq "virtual-server" || $domain;
	&migrate_to_stock_nginx_acl($user->{'name'}, 0, $oldmod, $newmod,
				    $changed, $domain_user);
	}

foreach my $group (&acl::list_groups()) {
	my $changed = 0;
	foreach my $k ("modules", "ownmods") {
		my ($modules, $mchanged) =
			&add_acl_module($group->{$k}, $oldmod, $newmod);
		if ($mchanged) {
			$group->{$k} = $modules;
			$changed = 1;
			}
		}
	&acl::modify_group($group->{'name'}, $group) if ($changed);
	&migrate_to_stock_nginx_acl($group->{'name'}, 1, $oldmod, $newmod,
				    $changed, 0);
	}
}

# add_acl_module(&modules, old-module, new-module)
# If old-module is present in a Webmin ACL list, add new-module too without
# changing the original grant
sub add_acl_module
{
my ($mods, $oldmod, $newmod) = @_;
my @old = @{$mods || []};
return ([ @old ], 0) if (&indexof($oldmod, @old) < 0);

my @new;
my %seen;
my $changed = 0;

foreach my $m (@old, $newmod) {
	if ($seen{$m}++) {
		$changed = 1;
		next;
		}
	push(@new, $m);
	}

$changed = 1 if (&indexof($newmod, @old) < 0);
return (\@new, $changed);
}

# replace_acl_module(&modules, old-module, new-module)
# Replaces old-module with new-module in an array-style module list and dedupes
# entries. Used by space-separated Virtualmin config lists via replace_module_list
sub replace_acl_module
{
my ($mods, $oldmod, $newmod) = @_;
my @old = @{$mods || []};
return ([ @old ], 0) if (&indexof($oldmod, @old) < 0);

my @new;
my %seen;
my $changed = 0;

foreach my $m (@old) {
	if ($m eq $oldmod) {
		$m = $newmod;
		$changed = 1;
		}
	if ($seen{$m}++) {
		$changed = 1;
		next;
		}
	push(@new, $m);
	}

return (\@new, $changed);
}

# replace_module_list(modules-string, old-module, new-module)
# Replaces a module name in Virtualmin's space-separated webmin_modules values
sub replace_module_list
{
my ($mods, $oldmod, $newmod) = @_;
my ($list, $changed) =
	&replace_acl_module([ split(/\s+/, $mods || "") ], $oldmod, $newmod);
return (join(" ", @$list), $changed);
}

# replace_avail_module(avail-string, old-module, new-module)
# Replaces a module name in template availability entries like module=value,
# preserving the existing availability value
sub replace_avail_module
{
my ($avail, $oldmod, $newmod) = @_;
my @old = split(/\s+/, $avail || "");
my $has_old = grep { (split(/=/, $_, 2))[0] eq $oldmod } @old;
return ($avail, 0) if (!$has_old);
my $has_new = grep { (split(/=/, $_, 2))[0] eq $newmod } @old;
my @new;
my %seen;
my $changed = 0;

foreach my $entry (@old) {
	my ($mod, $value) = split(/=/, $entry, 2);
	if ($mod eq $oldmod) {
		$changed = 1;
		next if ($has_new);
		$mod = $newmod;
		$has_new = 1;
		}
	if ($seen{$mod}++) {
		$changed = 1;
		next;
		}
	push(@new, defined($value) ? $mod."=".$value : $mod);
	}

return (join(" ", @new), $changed);
}

# migrate_to_stock_nginx_acl(user-or-group, is-group, old-module, new-module,
#                            module-granted, domain-user)
# Copies explicit legacy ACL values into the stock nginx ACL, while preserving
# any values already customized on the stock nginx module
sub migrate_to_stock_nginx_acl
{
my ($name, $group, $oldmod, $newmod, $granted, $domain_user) = @_;
my %oldacl = $group ? &get_group_module_acl($name, $oldmod, 1)
		    : &get_module_acl($name, $oldmod, 0, 1);
return if (!%oldacl && !$granted);

my %newacl = $group ? &get_group_module_acl($name, $newmod, 1)
		    : &get_module_acl($name, $newmod, 0, 1);
# Preserve explicit stock nginx ACL customizations for admin-style ACLs, while
# forcing domain-scoped ACLs into safe Virtualmin-managed defaults
my %merged = (%oldacl, %newacl);
my $domain_acl = $domain_user || &is_domain_scoped_nginx_acl(\%merged);
if ($domain_acl) {
	$merged{'noconfig'} = 1;
	$merged{'create'} = 0;
	}
elsif (!defined($merged{'create'})) {
	$merged{'create'} = 1;
	}

if ($group) {
	&save_group_module_acl(\%merged, $name, $newmod, 1);
	}
else {
	&save_module_acl(\%merged, $name, $newmod, 1);
	}
}

# is_domain_scoped_nginx_acl(&acl)
# Returns true for ACLs that should be treated as Virtualmin domain-owner ACLs
sub is_domain_scoped_nginx_acl
{
my ($acl) = @_;
return 1 if ($acl->{'vhosts'});
return 1 if (defined($acl->{'root'}) && $acl->{'root'} ne "" &&
	     $acl->{'root'} ne "/");
return 0;
}

1;
