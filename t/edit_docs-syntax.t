use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'edit_docs.cgi' );
strict_ok( 'edit_docs.cgi' );
warnings_ok( 'edit_docs.cgi' );
