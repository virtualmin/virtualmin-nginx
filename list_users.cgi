#!/usr/local/bin/perl
# Show users in one htpasswd-format file

use strict;
use warnings;
require 'virtualmin-nginx-lib.pl';
&foreign_require("htaccess-htpasswd");
our (%text, %in);
&ReadParse();
$in{'file'} || &error($text{'users_efile'});

&ui_print_header("<tt>".&html_escape($in{'file'})."</tt>",
		 $text{'users_title'}, "");

my $users = &htaccess_htpasswd::list_users($in{'file'});
my @links = ( "<a href='edit_user.cgi?new=1&file=".&urlize($in{'file'})."'>".
	      $text{'users_add'}."</a>" );
if (@$users) {
	print &ui_links_row(\@links);
	my @grid = map { my $h = "<a href='edit_user.cgi?user=".
				 &urlize($_->{'user'})."&file=".
				 &urlize($in{'file'})."'>".
				 &html_escape($_->{'user'})."</a>";
			 !$_->{'enabled'} ? "<i>$h</i>" : $h } @$users;
	print &ui_grid_table(\@grid, 4, 100);
	}
else {
	print "<b>$text{'users_none'}</b><p>\n";
	}
print &ui_links_row(\@links);

&ui_print_footer("", $text{'index_return'});

