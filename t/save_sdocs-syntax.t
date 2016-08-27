use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'save_sdocs.cgi' );
strict_ok( 'save_sdocs.cgi' );
warnings_ok( 'save_sdocs.cgi' );
