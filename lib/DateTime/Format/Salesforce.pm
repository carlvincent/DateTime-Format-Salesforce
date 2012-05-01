# Copyright (C) 2012 Carl Vincent 
# based on DateTime::Format::ISO8601 by Joshua Hoblitt

package DateTime::Format::Salesforce;

use strict;
use warnings;

use vars qw( $VERSION );
$VERSION = '0.01_01';

use Carp qw( croak );
use DateTime;
use DateTime::Format::Builder;
use Params::Validate qw( validate validate_pos BOOLEAN OBJECT SCALAR );

{
    my $default_legacy_year;
    sub DefaultLegacyYear {
        my $class = shift;

        ( $default_legacy_year ) = validate_pos( @_,
            {
                type        => BOOLEAN,
                callbacks   => {
                    'is 0, 1, or undef' =>
                        sub { ! defined( $_[0] ) || $_[0] == 0 || $_[0] == 1 },
                },
            }
        ) if @_;

        return $default_legacy_year;
    }
}
__PACKAGE__->DefaultLegacyYear( 1 );

{
    my $default_cut_off_year;
    sub DefaultCutOffYear {
        my $class = shift;

        ( $default_cut_off_year ) = validate_pos( @_,
            {
                type        => SCALAR,
                callbacks   => {
                    'is between 0 and 99' =>
                        sub { $_[0] >= 0 && $_[0] <= 99 },
                },
            }
        ) if @_;

        return $default_cut_off_year;
    }
}
# the same default value as DT::F::Mail
__PACKAGE__->DefaultCutOffYear( 49 );

sub new {
    my( $class ) = shift;

    my %args = validate( @_,
        {
            base_datetime => {
                type        => OBJECT,
                can         => 'utc_rd_values',
                optional    => 1,
            },
            legacy_year => {
                type        => BOOLEAN,
                default     => $class->DefaultLegacyYear,
                callbacks   => {
                    'is 0, 1, or undef' =>
                        sub { ! defined( $_[0] ) || $_[0] == 0 || $_[0] == 1 },
                },
            },
            cut_off_year => {
                type        => SCALAR,
                default     => $class->DefaultCutOffYear,
                callbacks   => {
                    'is between 0 and 99' =>
                        sub { $_[0] >= 0 && $_[0] <= 99 },
                },
            },
        }
    );

    $class = ref( $class ) || $class;

    my $self = bless( \%args, $class );

    if ( $args{ base_datetime } ) {
        $self->set_base_datetime( object => $args{ base_datetime } );
    }

    return( $self );
}

# lifted from DateTime
sub clone { bless { %{ $_[0] } }, ref $_[0] }

sub base_datetime { $_[0]->{ base_datetime } }

sub set_base_datetime {
    my $self = shift;

    my %args = validate( @_,
        {
            object => {
                type        => OBJECT,
                can         => 'utc_rd_values',
            },
        }
    );
       
    # ISO8601 only allows years 0 to 9999
    # this implimentation ignores the needs of expanded formats
    my $dt = DateTime->from_object( object => $args{ object } );
    my $lower_bound = DateTime->new( year => 0 );
    my $upper_bound = DateTime->new( year => 10000 );

    if ( $dt < $lower_bound ) {
        croak "base_datetime must be greater then or equal to ",
            $lower_bound->iso8601;
    }
    if ( $dt >= $upper_bound ) {
        croak "base_datetime must be less then ", $upper_bound->iso8601;
    }

    $self->{ base_datetime } = $dt;

    return $self;
}

sub legacy_year { $_[0]->{ legacy_year } }

sub set_legacy_year {
    my $self = shift;

    my @args = validate_pos( @_,
        {
            type        => BOOLEAN,
            callbacks   => {
                'is 0, 1, or undef' =>
                    sub { ! defined( $_[0] ) || $_[0] == 0 || $_[0] == 1 },
            },
        }
    );

    $self->{ legacy_year } = $args[0];

    return $self;
}

sub cut_off_year { $_[0]->{ cut_off_year } }

sub set_cut_off_year {
    my $self = shift;

    my @args = validate_pos( @_,
        {
            type        => SCALAR,
            callbacks   => {
                'is between 0 and 99' =>
                    sub { $_[0] >= 0 && $_[0] <= 99 },
            },
        }
    );

    $self->{ cut_off_year } = $args[0];

    return $self;
}

DateTime::Format::Builder->create_class(
    parsers => {
        parse_datetime => [
            {
                #YYYY-MM-DDThh:mm:ss.ss[+-]hh:mm 1985-04-12T10:15:30.5+01:00 1985-04-12T10:15:30.5-05:00
                regex  => qr/^ (\d{4}) -  (\d\d) - (\d\d)
                            T?? (\d\d) : (\d\d) : (\d\d) [\.,] (\d+)
                            ([+-] \d\d \d\d) $/x,
                params => [ qw( year month day hour minute second nanosecond time_zone ) ],
                postprocess => [
                    \&_fractional_second,
                    \&_normalize_offset,
                ],
            },
        ],

    }
);
sub _fractional_second {
    my %p = @_;

    $p{ parsed }{ nanosecond } = ".$p{ parsed }{ nanosecond }" * 10**9; 

    return 1;
}

sub _normalize_offset {
    my %p = @_;

    $p{ parsed }{ time_zone } =~ s/://;

    if( length $p{ parsed }{ time_zone } == 3 ) {
        $p{ parsed }{ time_zone }  .= '00';
    }

    return 1;
}

1;
__END__
=head1 NAME

DateTime::Format::Salesforce - Parses datetime strings from the Salesforce API

=head1 SYNOPSIS

    use DateTime::Format::Salesforce;
    
    my $dt = DateTime::Format::Salesforce->parse_datetime( $str );
    
    or 
    
    my $parser = DateTime::Format::Salesforce->new;
    my $dt = $parser->parse_datetime( $str );
    
=head1 DESCRIPTION

Parses datetime formats returned by the Salesforce REST API. These claim to 
by ISO 8601 but subtly deviate from the standard, and hence can't be parsed
by L<DateTime::Format::ISO8601>. This code is based heavily on that module
and supports only the formats received from Salesforce.

=head1 USAGE

=head2 Import Parameters

This module accepts no arguments to it's C<import> method.

=head2 Methods

=head3 Constructors

=over 4

=item * new( ... )

Accepts an optional hash.

    my $iso8601 = DateTime::Format::ISO8601->new(
                    base_datetime => $dt,
                    cut_off_year  => 42,
                    legacy_year   => 1,
                );

=over 4

=item * base_datetime

A C<DateTime> object that will be used to fill in missing information from
incomplete date/time formats.

This key is optional.

=item * cut_off_year

A integer representing the cut-off point between interpreting 2-digits years
as 19xx or 20xx. 

    2-digit years <  legacy_year will be interpreted as 20xx
    2-digit years >= legacy_year will be untreated as 19xx

This key defaults to the value of C<DefaultCutOffYear>.

=item * legacy_year

A boolean value controlling if a 2-digit year is interpreted as being in the
current century (unless a C<base_datetime> is set) or if C<cut_off_year>
should be used to place the year in either 20xx or 19xx.

This key defaults to the value of C<DefaultLegacyYear>.

=back

=back

=head3 Object Methods

=over 4

=item * base_datetime

Returns a C<DateTime> object if a C<base_datetime> has been set.

=item * set_base_datetime( object => $object )

Accepts a C<DateTime> object that will be used to fill in missing information
from incomplete date/time formats.

=item * cut_off_year

Returns a integer representing the cut-off point between interpreting
2-digits years as 19xx or 20xx. 

=item * set_cut_off_year( $int )

Accepts a integer representing the cut-off point between interpreting
2-digits years as 19xx or 20xx. 

    2-digit years <  legacy_year will be interpreted as 20xx
    2-digit years >= legacy_year will be interpreted as 19xx

=item * legacy_year

Returns a boolean value indicating the 2-digit year handling behavior.

=item * set_legacy_year( $bool )

Accepts a boolean value controlling if a 2-digit year is interpreted as being
in the current century (unless a C<base_datetime> is set) or if
C<cut_off_year> should be used to place the year in either 20xx or 19xx.

=back

=head3 Class Methods

=over 4

=item * DefaultCutOffYear( $int )

Accepts a integer representing the cut-off point for 2-digit years when
calling C<parse_*> as class methods and the default value for C<cut_off_year>
when creating objects.  If called with no parameters this method will return
the default value for C<cut_off_year>.

=item * DefaultLegacyYear( $bool )

Accepts a boolean value controlling the legacy year behavior when calling
C<parse_*> as class methods and the default value for C<legacy_year> when
creating objects.  If called with no parameters this method will return the
default value for C<legacy_year>.

=back

=head3 Parser(s)

These may be called as either class or object methods.

=over 4

=item * parse_datetime

Please see the L</FORMATS> section.

=back

=head1 FORMATS

=over 4

=item * YYYY-MM-DDThh:mm:ss.ss[+-]hhmm

    1999-11-02T23:12:00.456+0400

=back

=head1 CREDITS

Credit to all the contributors to L<DateTime::Format::ISO8601> on whose work
this module is shamelessly built.

=head1 SUPPORT
 
Support for this module is provided via the <datetime@perl.org> email list.
See L<http://lists.perl.org/> for more details.

=head1 AUTHOR
 
Carl Vincent <carl.vincent@netskills.ac.uk>
 
=head1 COPYRIGHT
 
Copyright (c) 2012 Carl Vincent. All rights reserved. This program is
free software; you can redistribute it and/or modify it under the same terms as
Perl itself.

The full text of the licenses can be found in the I<LICENSE> file included with
this module, or in L<perlartistic> and L<perlgpl> as supplied with Perl 5.8.1
and later.
 
=head1 SEE ALSO

L<DateTime>, L<DateTime::Format::ISO8601>, L<DateTime::Format::Builder>,
L<http://datetime.perl.org/>
 
=cut