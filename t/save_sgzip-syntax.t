use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'save_sgzip.cgi' );
strict_ok( 'save_sgzip.cgi' );
warnings_ok( 'save_sgzip.cgi' );
