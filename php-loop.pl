#!/usr/bin/perl
# Simple script to run a sub-process in a loop

use POSIX;

$dead = 0;

$SIG{'TERM'} = sub { $dead = 1;
		     if ($childpid) {
			kill(TERM, $childpid);
			sleep(1);	# Give it time to clean up
			kill(KILL, $childpid);
		        }
		     exit(1);
		   };

while(!$dead) {
	$start = time();
	$childpid = fork();
	if ($childpid == 0) {
		exec(@ARGV);
		}
	waitpid($childpid, 0);

	if (time() - $start < 10) {
		# Crashed within 10 seconds .. throttle restart
		sleep(5);
		}
	}

