use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'edit_sdocs.cgi' );
strict_ok( 'edit_sdocs.cgi' );
warnings_ok( 'edit_sdocs.cgi' );
