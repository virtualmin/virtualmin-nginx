#!/usr/bin/perl
use strict;
use warnings;

my @mods;
my %donemod;
foreach my $l (&download("http://wiki.nginx.org/DirectiveIndex")) {
	if ($l =~ /href="\/(Nginx([^"]*)Module)"/) {
		my $page = $1;
		my $mod = $2;
		$mod =~ s/([A-Z])/_$1/g;
		$mod =~ s/^_//;
		$mod = lc($mod);
		push(@mods, [ $page, $mod ]) if (!$donemod{$mod}++);
		}
	}
push(@mods, [ "CoreModule", "core" ]);

my @dirs;
foreach my $m (@mods) {
	my ($page, $mod) = @$m;
	my $dir;
	foreach my $l (&download("http://wiki.nginx.org/$page")) {
		if ($l =~ /<b>syntax:<\/b> (<i>)?([^< ]+)/i) {
			$dir = { 'name' => $2,
				 'mod' => $mod };
			push(@dirs, $dir);
			}
		elsif ($l =~ /<b>default:<\/b> <i>([^<]+)</i && $dir) {
			$dir->{'default'} = $1;
			$dir->{'default'} =~ s/^\Q$dir->{'name'}\E\s+//;
			if ($dir->{'default'} eq 'compile-time option' ||
			    $dir->{'default'} eq 'system dependent' ||
			    $dir->{'default'} =~ /No value specified/) {
				$dir->{'default'} = '';
				}
			$dir->{'default'} =~ s/;\s*$//;
			}
		elsif ($l =~ /<b>context:<\/b> <i>([^<]+)</i && $dir) {
			$dir->{'context'} = $1;
			$dir->{'context'} =~ s/\s//g;
			$dir->{'context'} =~ s/\([^\)]+\)//g;
			$dir = undef;
			}
		}
	}

foreach my $dir (@dirs) {
	print join("\t", $dir->{'mod'}, $dir->{'name'}, $dir->{'default'} || "-", $dir->{'context'} || "-"),"\n";
	}

sub download
{
my ($url) = @_;
my @lines = `wget -O - -q $url 2>/dev/null`;
return @lines;
}
