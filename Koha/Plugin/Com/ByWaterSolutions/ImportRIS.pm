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

our $ris_to_marc = {
    BOOK => {
        TY => { field => '942', subfield => 'c' },
        AU => { field => '100', subfield => 'a', indicator_1 => '1' },
        PY => { field => '264', subfield => 'c', indicator_2 => '1' },
        TI => { field => '245', subfield => 'a' },
        A2 => { field => '245', subfield => 'c' },
        T2 => { field => '773', subfield => 't', indicator_1 => '1' },
        CY => { field => '264', subfield => 'a', indicator_2 => '1' },
        PB => { field => '264', subfield => 'a', indicator_2 => '1' },
        VL => { field => '490', subfield => 'v' },
        NV => { field => '300', subfield => 'a' },
        M1 => { field => '773', subfield => 'g', indicator_1 => '1' },
        SP => { field => '300', subfield => 'a' },
        SE => { field => '245', subfield => 'n', indicator_1 => '3' },
        A3 => { field => '700', subfield => 'a', indicator_1 => '1' },
        ET => { field => '250', subfield => 'a' },
        DA => { field => '264', subfield => 'c', indicator_1 => '1' },
        A4 => { field => '700', subfield => 'a', indicator_1 => '1' },
        ST => { field => '246', subfield => 'a', indicator_1 => '2' },
        SN => { field => '020', subfield => 'a' },
        KW => { field => '650', subfield => 'a', indicator_2 => '0', split => "\n" },
        AB => { field => '520', subfield => 'a', indicator_1 => '3' },
        N1 => { field => '500', subfield => 'a' },
        UR => { field => '856', subfield => 'u', indicator_1 => '4', indicator_2 => '#' },
        AD => { field => '100', subfield => 'u', indicator_1 => '1' },
        DO => { field => '024', subfield => 'a', indicator_1 => '7' },
        C1 => { field => '590', subfield => 'a' },
    },
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

        my $tags_to_fields = $ris_to_marc->{$TY};

        unless ( $tags_to_fields ) {
            warn "No mapping for $TY!";
            next;
        }

        foreach my $key ( keys %$tags_to_fields ) {
            my $data = $tags_to_fields->{$key};

            my $field = $data->{field};
            my $subfield = $data->{subfield};
            my $indicator_1 = $data->{indicator_1} || q{ };
            my $indicator_2 = $data->{indicator_2} || q{ };
            my $split = $data->{split};

            if ( $ris->{$key} ) {
                foreach my $value ( @{ $ris->{$key} } ) {
                    my @values = $split ? split( /$split/, $value ) : ($value);

                    foreach my $v (@values) {
                        my $ret = $record->insert_fields_ordered(
                            MARC::Field->new(
                                $field, $indicator_1,
                                $indicator_2, $subfield => $v,
                            )
                        );
                    }
                }
            }
        }

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
