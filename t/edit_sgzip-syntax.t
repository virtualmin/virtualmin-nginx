use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'edit_sgzip.cgi' );
strict_ok( 'edit_sgzip.cgi' );
warnings_ok( 'edit_sgzip.cgi' );
