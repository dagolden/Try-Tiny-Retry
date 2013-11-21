use 5.006;
use strict;
use warnings;

package Try::Tiny::Retry;
# ABSTRACT: Extends Try::Tiny to allow retries
# VERSION

use parent 'Exporter';
our @EXPORT      = qw/retry retry_if try catch finally/;
our @EXPORT_OK   = ( @EXPORT, qw/delay delay_exp/ );
our %EXPORT_TAGS = ( all => [@EXPORT_OK] );

use Carp;
$Carp::Internal{ +__PACKAGE__ }++;

use Try::Tiny;

BEGIN {
    eval "use Sub::Name; 1" or *{subname} = sub { 1 }
}

our $DEFAULT_DELAY = 1e5;

sub delay(&;@) { ## no critic
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

sub delay_exp(&;@) { ## no critic
    my ( $params, @rest ) = @_;
##    croak "delay_exp requires an array reference argument"
##      unless ref($params) eq 'ARRAY';
    my ( $n, $scale ) = $params->();

    require Time::HiRes;

    return delay {
        return if $_[0] >= $n;
        Time::HiRes::usleep( int rand( $scale * ( 1 << ( $_[0] - 1 ) ) ) );
    }, @rest;
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
        my ($code_ref) = delay_exp { 10, $DEFAULT_DELAY };
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
                    my $met = 0;
                    for my $c (@conditions) {
                        local $_ = $err; # protect from modification
                        $met++ if $c->();
                    }
                    die $err unless $met;
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
1;

=for Pod::Coverage BUILD

=head1 SYNOPSIS

Use just like L<Try::Tiny>, but with C<retry> instead of C<try>. By default,
C<retry> will try 10 times with exponential backoff:

    use Try::Tiny::Retry;

    retry   { ... }
    catch   { ... }
    finally { ... };

Or, you can retry only if the error matches some conditions:

    use Try::Tiny::Retry;

    retry   { ... }
    retry_if { /could not connect/ }
    catch { ... };

Or, you can customize the number of tries and delay timing:

    use Try::Tiny::Retry ':all';

    retry       { ... }
    delay_exp   [ 5, 1e6 ] # 5 tries, 1 second exponential-backoff
    catch       { ... };

=head1 DESCRIPTION

This module extends Try::Tiny to allow for retrying code several times
before failing.

=head1 USAGE

By default, Try::Tiny::Retry exports C<retry> and C<retry_if>, plus C<try>,
C<catch> and C<finally> from L<Try::Tiny>.  You can optional export C<delay> or
C<delay_exp>.  Or you can get everything with the C<:all> tag.

If you are also loading L<Try::Tiny> for some reason, just import the functions
you need:

    use Try::Tiny;
    use Try::Tiny::Retry qw/retry delay_exp/;

=head1 SEE ALSO

There are other retry modules on CPAN, but none of them worked seamlessly with
L<Try::Tiny>.

=for :list
* L<Action::Retry> — OO (Moo) or functional; various delay strategies; supports
  conditions
* L<AnyEvent::Retry> — OO (Moose) and event-driven; various delay strategies
* L<Attempt> — functional; simple retry constant sleep time
* L<Retry> — OO (Moose) with fixed exponential backoff; supports callbacks
  on every iteration
* L<Sub::Retry> — functional; simple retry with constant sleep time;
  supports conditions

=cut

# vim: ts=4 sts=4 sw=4 et:
