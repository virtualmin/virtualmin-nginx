#!/usr/bin/perl
# Simple script to run a sub-process in a loop
use strict;
use warnings;
use POSIX;

our $dead = 0;
our $childpid = 0;

$SIG{'TERM'} = sub {
		$dead = 1;
		if ($childpid) {
			kill('TERM', $childpid);
			sleep(1);	# Give it time to clean up
			kill('KILL', $childpid);
		}
		exit(1);
	};

while(!$dead) {
	if (!-x $ARGV[0]) {
		print STDERR "PHP command $ARGV[0] does not exist!\n";
		exit(2);
		}
	my $start = time();
	$childpid = fork();
	if ($childpid == 0) {
		exec(@ARGV);
		exit(1);
		}
	waitpid($childpid, 0);

	if (time() - $start < 10) {
		# Crashed within 10 seconds .. throttle restart
		sleep(5);
		}
	}
