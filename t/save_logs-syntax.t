use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'save_logs.cgi' );
strict_ok( 'save_logs.cgi' );
warnings_ok( 'save_logs.cgi' );
