use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'edit_ssl.cgi' );
strict_ok( 'edit_ssl.cgi' );
warnings_ok( 'edit_ssl.cgi' );
