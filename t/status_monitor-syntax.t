use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'status_monitor.pl' );
strict_ok( 'status_monitor.pl' );
warnings_ok( 'status_monitor.pl' );
