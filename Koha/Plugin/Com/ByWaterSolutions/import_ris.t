#!/usr/bin/perl

use lib '../../../..';
use File::Slurp;
use Koha::Plugin::Com::ByWaterSolutions::ImportRIS;

my $text = read_file('example.ris');

my $marc =
  Koha::Plugin::Com::ByWaterSolutions::ImportRIS::to_marc(undef, { data => $text } );
