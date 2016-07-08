use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'save_docs.cgi' );
strict_ok( 'save_docs.cgi' );
warnings_ok( 'save_docs.cgi' );
