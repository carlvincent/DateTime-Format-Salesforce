#!/usr/bin/perl

# Copyright (C) 2012 Carl Vincent 
# based on DateTime::Format::ISO8601 by Joshua Hoblitt

use strict;
use warnings;

use lib qw( ./lib );

use Test::More tests => 2;

BEGIN { use_ok( 'DateTime::Format::Salesforce' ); }

my $object = DateTime::Format::Salesforce->new;
isa_ok( $object, 'DateTime::Format::Salesforce' );
