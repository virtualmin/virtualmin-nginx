
do 'virtualmin-nginx-lib.pl';

# acl_security_form(&options)
# Output HTML for editing security options for the acl module
sub acl_security_form
{
my ($o) = @_;

# Allowed virtual hosts
print &ui_table_row($text{'acl_vhosts'},
	&ui_radio("vhosts_def", $o->{'vhosts'} ? 0 : 1,
		  [ [ 1, $text{'acl_hosts1'} ],
		    [ 0, $text{'acl_hosts0'} ] ])."<br>\n".
	&ui_textarea("vhosts", join("\n", split(/\s+/, $o->{'hosts'})), 5, 30));

# Allow directories for locations


# Can edit global settings?


# Write password files as user

}

# acl_security_save(&options)
# Parse the form for security options for the acl module
sub acl_security_save
{
my ($o) = @_;
}

