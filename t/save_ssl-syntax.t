use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'save_ssl.cgi' );
strict_ok( 'save_ssl.cgi' );
warnings_ok( 'save_ssl.cgi' );
