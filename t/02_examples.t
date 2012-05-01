#!/usr/bin/perl
# Copyright (C) 2003-2005  Joshua Hoblitt

use strict;
use warnings;

use lib qw( ./lib );

use Test::More tests => 7;

use DateTime::Format::Salesforce;

# parse_datetime
my $base_year = 2000;
my $base_month = "01";
my $salesforce = DateTime::Format::Salesforce->new(
    base_datetime => DateTime->new( year => $base_year, month => $base_month ),
);

{
    #YYYY-MM-DDThh:mm:ss.ss[+-]hhmm
    my $dt = $salesforce->parse_datetime( '1999-11-02T23:12:00.456+0400' );
    is( $dt->iso8601, '1999-11-02T23:12:00' );
    is( $dt->nanosecond, 456_000_000 );
    is( $dt->time_zone->name, '+0400' );
}
{
    #YYYY-MM-DDThh:mm:ss.ss[+-]hhmm
    my $dt = $salesforce->parse_datetime( '2012-04-24T10:39:00.921-0630' );
    is( $dt->iso8601, '2012-04-24T10:39:00' );
    is( $dt->nanosecond, 921_000_000 );
    is( $dt->time_zone->name, '-0630' );
}
# just check a counter-case to prove we're not accepting any old rubbish:
eval {
    my $dt = $salesforce->parse_datetime( '20091210T090000.00+01:00' );
};
like( $@, qr/Invalid date format/ );

