use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'edit_logs.cgi' );
strict_ok( 'edit_logs.cgi' );
warnings_ok( 'edit_logs.cgi' );
