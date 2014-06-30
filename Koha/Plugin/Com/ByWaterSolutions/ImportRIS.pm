package Koha::Plugin::Com::ByWaterSolutions::ImportRIS;

## It's good practive to use Modern::Perl
use Modern::Perl;

## Required for all plugins
use base qw(Koha::Plugins::Base);

## We will also need to include any Koha libraries we want to access
use MARC::Record;

## Here we set our plugin version
our $VERSION = 2.00;

## Here is our metadata, some keys are required, some are optional
our $metadata = {
    name   => 'RIS Importer',
    author => 'Kyle M Hall',
    description =>
'Adds the ability to import RIS citations as MARC using the "Stage MARC records for import" tool',
    date_authored   => '2014-06-16',
    date_updated    => '2014-06-16',
    minimum_version => '3.14',
    maximum_version => undef,
    version         => $VERSION,
};

## This is the minimum code required for a plugin's 'new' method
## More can be added, but none should be removed
sub new {
    my ( $class, $args ) = @_;

    ## We need to add our metadata here so our base class can access it
    $args->{'metadata'} = $metadata;
    $args->{'metadata'}->{'class'} = $class;

    ## Here, we call the 'new' method for our base class
    ## This runs some additional magic and checking
    ## and returns our actual $self
    my $self = $class->SUPER::new($args);

    return $self;
}

sub to_marc {
    my ( $self, $args ) = @_;

    my $data = $args->{data};

    my $batch = q{};

    my @citations = split( /\n\n/, $data );

    foreach my $c (@citations) {
        my $record = MARC::Record->new();

        my @tags = split( /([A-Z][A-Z,0-9])  - /, $c );
        @tags = map { $_ ne ""   ? $_ : () } @tags;
        @tags = map { $_ ne "\n" ? $_ : () } @tags;

        my $ris;
        while (@tags) {
            my $tag   = shift(@tags);
            my $value = shift(@tags);

            push( @{ $ris->{$tag} }, $value );
        }

        my $field;

        my $TY = $ris->{TY}->[0];
        chomp( $TY );

        unless ($TY) {
            warn "No TY field found! Skipping record!";
            next;
        }

        if ( $TY eq 'BOOK' || $TY eq 'CHAP') {

            # ISBN/ISSN (SN)
            map {
                $record->append_fields(
                    MARC::Field->new( '020', '#', '#', 'a' => $_ ),
                  )
            } @{ $ris->{SN} };

            # DOI (DO)
            map {
                $record->append_fields(
                    MARC::Field->new( '024', '7', '#', 'a' => $_, '2' => $_ ),
                  )
            } @{ $ris->{DO} };

            # Author (AU), Author Address (AD)
            foreach my $i ( 0 .. scalar @{ $ris->{AU} } - 1 ) {
                $field =
                  MARC::Field->new( '100', '1', '#', 'a' => $ris->{AU}->[$i] );

                $field->add_subfields( 'u' => $ris->{AD}->[$i] )
                  if $ris->{AD}->[$i];

                $record->append_fields($field);
            }

            # Title (TI), Secondary author (A2)
            my @subfields;
            push( @subfields, 'a' => $ris->{TI}->[0] ) if $ris->{TI}->[0];
            push( @subfields, 'a' => $ris->{A2}->[0] ) if $ris->{A2}->[0];
            $record->append_fields(
                MARC::Field->new( '245', '#', '#', @subfields ) )
              if @subfields;

            # Short Title (ST)
            map {
                $record->append_fields(
                    MARC::Field->new( '246', '2', '#', 'a' => $_ ),
                  )
            } @{ $ris->{ST} };

            # Section (SE)
            map {
                $record->append_fields(
                    MARC::Field->new( '246', '3', '#', 'n' => $_ ),
                  )
            } @{ $ris->{SE} };

            # Edition (ET)
            map {
                $record->append_fields(
                    MARC::Field->new( '250', '#', '#', 'a' => $_ ),
                  )
            } @{ $ris->{ET} };

            # Year (PY), Place Published (CY), Publisher (PB), Date (DA)
            if ( $ris->{PY} || $ris->{CY} || $ris->{PB} ) {
                my @subfield_a = map { +'a' => $_ } @{ $ris->{CY} };
                @subfield_a =
                  ( @subfield_a, map { +'a' => $_ } @{ $ris->{PB} } );
                my @subfield_c = map { +'c' => $_ } @{ $ris->{PY} };
                @subfield_c =
                  ( @subfield_c, map { +'c' => $_ } @{ $ris->{DA} } );
                my $field =
                  MARC::Field->new( '264', '1', '1', @subfield_a, @subfield_c );
                $record->append_fields($field);
            }

            # Number of Volumes (NV)
            map {
                $record->append_fields(
                    MARC::Field->new( '300', '#', '#', 'a' => $_ ),
                  )
            } @{ $ris->{NV} };

            # Pages (SP)
            map {
                $record->append_fields(
                    MARC::Field->new( '300', '#', '#', 'a' => $_ ),
                  )
            } @{ $ris->{SP} };

            # Volume (VL)
            map {
                $record->append_fields(
                    MARC::Field->new( '490', '#', '#', 'v' => $_ ),
                  )
            } @{ $ris->{VL} };

            # Notes (N1)
            map {
                $record->append_fields(
                    MARC::Field->new( '500', '#', '#', 'a' => $_ ),
                  )
            } @{ $ris->{N1} };

            # Abstract (AB)
            map {
                $record->append_fields(
                    MARC::Field->new( '520', '3', '#', 'a' => $_ ),
                  )
            } @{ $ris->{AB} };

            # Custom 1 (C1)
            map {
                $record->append_fields(
                    MARC::Field->new( '590', '#', '#', 'a' => $_ ),
                  )
            } @{ $ris->{C1} };

            # Keywords
            foreach my $kws ( @{ $ris->{KW} } ) {
                foreach my $kw ( split( /\n/, $kws ) ) {
                    next unless $kw;
                    $record->append_fields(
                        MARC::Field->new( '650', '#', '0', a => $kw ) );
                }
            }

            # Authors, tertiary (A3) and subsidiary (A4)
            foreach my $author ( @{ $ris->{A3} }, @{ $ris->{A4} } ) {
                $record->append_fields(
                    MARC::Field->new( '700', '1', '#', 'a' => $author ) );
            }

            # Secondary Title (T2), Number (M1)
            if ( $ris->{T2} ) {
                foreach my $i ( 0 .. scalar @{ $ris->{T2} } - 1 ) {
                    $field =
                      MARC::Field->new( '773', '1', '#',
                        't' => $ris->{T2}->[$i] );

                    $field->add_subfields( 'g' => $ris->{M1}->[$i] )
                      if $ris->{M1}->[$i];

                    $record->append_fields($field);
                }
            }

            # Original Publication (OP)
            map {
                $record->append_fields(
                    MARC::Field->new( '773', '#', '1', 'g' => $_ ),
                  )
            } @{ $ris->{OP} };

            # URL (UR)
            map {
                $record->append_fields(
                    MARC::Field->new( '856', '4', '#', 'u' => $_ ),
                  )
            } @{ $ris->{UR} };

        }
        elsif ( $TY eq 'CPAPER' ) {

            # ISBN/ISSN (SN)
            map {
                $record->append_fields(
                    MARC::Field->new( '020', '#', '#', 'a' => $_ ),
                  )
            } @{ $ris->{SN} };

            # DOI (DO)
            map {
                $record->append_fields(
                    MARC::Field->new( '024', '7', '#', 'a' => $_, '2' => $_ ),
                  )
            } @{ $ris->{DO} };

            # Author (AU), Author Address (AD)
            foreach my $i ( 0 .. scalar @{ $ris->{AU} } - 1 ) {
                $field =
                  MARC::Field->new( '100', '1', '#', 'a' => $ris->{AU}->[$i] );

                $field->add_subfields( 'u' => $ris->{AD}->[$i] )
                  if $ris->{AD}->[$i];

                $record->append_fields($field);
            }

            # Title (TI), Secondary author (A2)
            my @subfields;
            push( @subfields, 'a' => $ris->{TI}->[0] ) if $ris->{TI}->[0];
            push( @subfields, 'a' => $ris->{A2}->[0] ) if $ris->{A2}->[0];
            $record->append_fields(
                MARC::Field->new( '245', '#', '#', @subfields ) )
              if @subfields;

            # Short Title (ST)
            map {
                $record->append_fields(
                    MARC::Field->new( '246', '2', '#', 'a' => $_ ),
                  )
            } @{ $ris->{ST} };

            # Section (SE)
            map {
                $record->append_fields(
                    MARC::Field->new( '246', '3', '#', 'n' => $_ ),
                  )
            } @{ $ris->{SE} };

            # Edition (ET)
            map {
                $record->append_fields(
                    MARC::Field->new( '250', '#', '#', 'a' => $_ ),
                  )
            } @{ $ris->{ET} };

            # Year (PY), Place Published (CY), Publisher (PB), Date (DA)
            if ( $ris->{PY} || $ris->{CY} || $ris->{PB} ) {
                my @subfield_a = map { +'a' => $_ } @{ $ris->{CY} };
                @subfield_a =
                  ( @subfield_a, map { +'a' => $_ } @{ $ris->{PB} } );
                my @subfield_c = map { +'c' => $_ } @{ $ris->{PY} };
                @subfield_c =
                  ( @subfield_c, map { +'c' => $_ } @{ $ris->{DA} } );
                my $field =
                  MARC::Field->new( '264', '1', '1', @subfield_a, @subfield_c );
                $record->append_fields($field);
            }

            # Number of Volumes (NV)
            map {
                $record->append_fields(
                    MARC::Field->new( '300', '#', '#', 'a' => $_ ),
                  )
            } @{ $ris->{NV} };

            # Pages (SP)
            map {
                $record->append_fields(
                    MARC::Field->new( '300', '#', '#', 'a' => $_ ),
                  )
            } @{ $ris->{SP} };

            # Volume (VL)
            map {
                $record->append_fields(
                    MARC::Field->new( '490', '#', '#', 'v' => $_ ),
                  )
            } @{ $ris->{VL} };

            # Notes (N1)
            map {
                $record->append_fields(
                    MARC::Field->new( '500', '#', '#', 'a' => $_ ),
                  )
            } @{ $ris->{N1} };

            # Abstract (AB)
            map {
                $record->append_fields(
                    MARC::Field->new( '520', '3', '#', 'a' => $_ ),
                  )
            } @{ $ris->{AB} };

            # Custom 1 (C1)
            map {
                $record->append_fields(
                    MARC::Field->new( '590', '#', '#', 'a' => $_ ),
                  )
            } @{ $ris->{C1} };

            # Keywords
            foreach my $kws ( @{ $ris->{KW} } ) {
                foreach my $kw ( split( /\n/, $kws ) ) {
                    next unless $kw;
                    $record->append_fields(
                        MARC::Field->new( '650', '#', '0', a => $kw ) );
                }
            }

            # Authors, tertiary (A3) and subsidiary (A4)
            foreach my $author ( @{ $ris->{A3} }, @{ $ris->{A4} } ) {
                $record->append_fields(
                    MARC::Field->new( '700', '1', '#', 'a' => $author ) );
            }

            # Secondary Title (T2), Number (M1)
            if ( $ris->{T2} ) {
                foreach my $i ( 0 .. scalar @{ $ris->{T2} } - 1 ) {
                    $field =
                      MARC::Field->new( '773', '1', '#',
                        't' => $ris->{T2}->[$i] );

                    $field->add_subfields( 'g' => $ris->{M1}->[$i] )
                      if $ris->{M1}->[$i];

                    $record->append_fields($field);
                }
            }

            # URL (UR)
            map {
                $record->append_fields(
                    MARC::Field->new( '856', '4', '#', 'u' => $_ ),
                  )
            } @{ $ris->{UR} };

        }

        # Reference Type (TY)
        $record->append_fields(
            MARC::Field->new( '942', '#', '#', 'c' => $TY ) );

        print $record->as_formatted() . "\n\n";

        $batch .= $record->as_usmarc() . "\x1D";
    }

    return $batch;
}

sub map_nr_nr {
    my ($params);
    my $record        = $params->{record};
    my $ris           = $params->{ris};
    my $ris_field     = $params->{ris_field};
    my $marc_field    = $params->{marc_field};
    my $marc_subfield = $params->{marc_subfield};
    my $indicator_1   = $params->{indicator_1} // '#';
    my $indicator_2   = $params->{indicator_2} // '#';

    $record->append_fields(
        MARC::Field->new(
            $marc_field, $indicator_1,
            $indicator_2, $marc_subfield => $ris->{$ris_field}->[0]
        )
    ) if $ris->{$ris_field};
}

## This is the 'install' method. Any database tables or other setup that should
## be done when the plugin if first installed should be executed in this method.
## The installation method should always return true if the installation succeeded
## or false if it failed.
sub install() {
    my ( $self, $args ) = @_;
    return 1;
}

## This method will be run just before the plugin files are deleted
## when a plugin is uninstalled. It is good practice to clean up
## after ourselves!
sub uninstall() {
    my ( $self, $args ) = @_;
    return 1;
}

1;
