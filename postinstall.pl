use strict;
use warnings;
no warnings 'uninitialized';
BEGIN { push(@INC, ".."); };
eval "use WebminCore;";

our (%config, $config_directory, $module_config_file);
&init_config();

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

sub migrate_to_stock_nginx_config
{
my ($oldmod, $newmod) = @_;
my @shared = qw(nginx_config add_to add_link nginx_cmd start_cmd stop_cmd
		apply_cmd pid_file);
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

sub migrate_to_stock_nginx_acls
{
my ($oldmod, $newmod) = @_;
return if (!&foreign_check("acl"));
&foreign_require("acl");

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
	&migrate_to_stock_nginx_acl($user->{'name'}, 0, $oldmod, $newmod,
				    $changed);
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
				    $changed);
	}
}

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

sub replace_module_list
{
my ($mods, $oldmod, $newmod) = @_;
my ($list, $changed) =
	&replace_acl_module([ split(/\s+/, $mods || "") ], $oldmod, $newmod);
return (join(" ", @$list), $changed);
}

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

sub migrate_to_stock_nginx_acl
{
my ($name, $group, $oldmod, $newmod, $granted) = @_;
my %oldacl = $group ? &get_group_module_acl($name, $oldmod, 1)
		    : &get_module_acl($name, $oldmod, 0, 1);
return if (!%oldacl && !$granted);

my %newacl = $group ? &get_group_module_acl($name, $newmod, 1)
		    : &get_module_acl($name, $newmod, 0, 1);
# Keep any explicit stock nginx ACL customizations, but seed missing values
# from the legacy Virtualmin Nginx ACL.
my %merged = (%oldacl, %newacl);
$merged{'create'} = 0 if (!defined($merged{'create'}));

if ($group) {
	&save_group_module_acl(\%merged, $name, $newmod, 1);
	}
else {
	&save_module_acl(\%merged, $name, $newmod, 1);
	}
}

1;
