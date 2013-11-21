use 5.006;
use strict;
use warnings;

package Try::Tiny::Retry;
# ABSTRACT: Extends Try::Tiny to allow retries
# VERSION

use parent 'Exporter';
our @EXPORT      = qw(retry retry_if);
our @EXPORT_OK   = ( @EXPORT, qw/delay delay_exp/ );
our %EXPORT_TAGS = ( all => [@EXPORT_OK] );

use Carp;
$Carp::Internal{ +__PACKAGE__ }++;

use Try::Tiny;

BEGIN {
    eval "use Sub::Name; 1" or *{subname} = sub { 1 }
}

sub retry(&;@) { ## no critic
    my ( $try, @code_refs ) = @_;

    # name the block if we have Sub::Name
    my $caller = caller;
    subname( "${caller}::retry {...} " => $try );

    my ( $delay, @conditions, @rest );

    # we need to save this here, the eval block will be in scalar context due
    # to $failed
    my $wantarray = wantarray;

    # find labeled blocks in the argument list: retry_if and delay tag by blessing
    foreach my $code_ref (@code_refs) {
        if ( ref($code_ref) eq 'Try::Tiny::Retry::RetryIf' ) {
            push @conditions, $$code_ref;
        }
        elsif ( ref($code_ref) eq 'Try::Tiny::Retry::Delay' ) {
            croak 'A retry() may not be followed by multiple delay blocks'
              if $delay;
            $delay = $$code_ref;
        }
        else {
            push @rest, $code_ref;
        }
    }

    # Default retry 10 times with 100 msec exponential backoff
    if ( !defined $delay ) {
        my ($code_ref) = delay_exp( [ 10, 100000 ] );
        $delay = $$code_ref;
    }

    my @ret;
    my $retry = sub {
        my $count = 0;
        RETRY: {
            $count++;
            my $redo;
            try {
                # evaluate the try block in the correct context
                if ($wantarray) {
                    @ret = $try->();
                }
                elsif ( defined $wantarray ) {
                    $ret[0] = $try->();
                }
                else {
                    $try->();
                }
            }
            catch {
                my $err = $_;
                # if there are conditions, rethrow unless at least one is met
                if (@conditions) {
                    die $err unless grep { $_->($err) } @conditions;
                }
                # rethow if delay function signals stop with undef
                my $continue = eval { $delay->($count) };
                die $@ if $@;
                die $err unless defined $continue;
                $redo++;
            };
            redo RETRY if $redo;
        }
        return $wantarray ? @ret : $ret[0];
    };

    return try( \&$retry, @rest );
}

sub retry_if(&;@) { ## no critic
    my ( $block, @rest ) = @_;
    return ( bless( \$block, 'Try::Tiny::Retry::RetryIf' ), @rest, );
}

sub delay(&;@) {    ## no critic
    my ( $block, @rest ) = @_;
    return ( bless( \$block, 'Try::Tiny::Retry::Delay' ), @rest, );
}

=func delay_exp

    retry { ... }
    delay_exp [ 3, 10000 ] # 3 tries, 10000 µsec
    catch { ... };

This function is an exponential-backoff delay-function generator.  The delay
between attempts is randomly selected between 0 and an upper bound. The upper
bound doubles after each failure.

It requires an array reference as an argument. The first element is the number
of tries allowed.  The second element is the starting upper bound in
microseconds.

Given number of tries C<N> and upper bound C<U>, the expected cumulative
delay time if all attempts fail is C<0.5 * U * ( 2^(N-1) - 1 )>.

=cut

sub delay_exp($;@) { ## no critic
    my ( $params, @rest ) = @_;
    croak "delay_exp requires an array reference argument"
      unless ref($params) eq 'ARRAY';
    my ( $n, $scale ) = @$params;

    require Time::HiRes;

    return delay {
        return if $_[0] >= $n;
        Time::HiRes::usleep( int rand( $scale * ( 1 << ( $_[0] - 1 ) ) ) );
    }, @rest;
}

1;

=for Pod::Coverage BUILD

=head1 SYNOPSIS

    use Try::Tiny::Retry;

=head1 DESCRIPTION

This module extends Try::Tiny to allow for retrying code several times
before failing.

=head1 USAGE

=head1 SEE ALSO

=for :list
* Maybe other modules do related things.

=cut

# vim: ts=4 sts=4 sw=4 et:
