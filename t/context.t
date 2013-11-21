use 5.006;
use strict;
use warnings;
use Test::More 0.96;
use Test::FailWarnings;

use Try::Tiny::Retry qw/:all/;
$Try::Tiny::Retry::DEFAULT_DELAY = 10; # shorten default delay

subtest 'scalar context' => sub {
    my $result = retry {
        my @array = 1 .. 10;
        return @array;
    };
    is( $result, 10, "correct result from retry block" );
};

subtest 'list context' => sub {
    my @result = retry {
        my @array = 1 .. 10;
        return @array;
    };
    is_deeply( \@result, [ 1 .. 10 ], "correct result from retry block" );
};

done_testing;
# COPYRIGHT

# vim: ts=4 sts=4 sw=4 et:
