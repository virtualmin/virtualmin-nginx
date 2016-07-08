use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'save_ssi.cgi' );
strict_ok( 'save_ssi.cgi' );
warnings_ok( 'save_ssi.cgi' );
