use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'edit_ssi.cgi' );
strict_ok( 'edit_ssi.cgi' );
warnings_ok( 'edit_ssi.cgi' );
