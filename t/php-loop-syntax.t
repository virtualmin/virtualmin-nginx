use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'php-loop.pl' );
strict_ok( 'php-loop.pl' );
warnings_ok( 'php-loop.pl' );
