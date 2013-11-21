use 5.006;
use strict;
use warnings;
use Test::More 0.96;

use Try::Tiny::Retry qw/:all/;
$Try::Tiny::Retry::_DEFAULT_DELAY = 10; # shorten default delay

subtest 'default retry and fail' => sub {
    my $count  = 0;
    my $caught = '';
    my @err;
    retry {
        pass("try $count");
        die "ick" if ++$count < 13;
    }
    catch {
        $caught = $_;
    };
    is( $count, 10, "correct number of retries" );
    like( $caught, qr/^ick/, "caught exception when retries failed" );
};

subtest 'default retry and succeed' => sub {
    my $count  = 0;
    my $caught = '';
    my @err;
    retry {
        pass("try $count");
        die "ick" if ++$count < 6;
    }
    catch {
        $caught = $_;
    };
    is( $count,  6,  "correct number of retries" );
    is( $caught, "", "no exceptions caught" );
};

done_testing;
# COPYRIGHT

# vim: ts=4 sts=4 sw=4 et:
