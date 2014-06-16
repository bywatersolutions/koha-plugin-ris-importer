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

        # Author
        $record->append_fields(
            MARC::Field->new(
                '100', '1', '#', map { +'a' => $_ } @{ $ris->{AU} }
            )
        ) if $ris->{AU};

        # Author, secondary
        $record->append_fields(
            MARC::Field->new(
                '700', '1', '#', map { +'a' => $_ } @{ $ris->{A2} }
            )
        ) if $ris->{A2};

        # Title
        $record->append_fields(
            MARC::Field->new( '245', '#', '#', 'a' => $ris->{TI}->[0] ) )
          if $ris->{TI};

        # Title, secondary
        map {
            $record->append_fields(
                MARC::Field->new( '773', '1', '#', 't' => $_ ) )
        } @{ $ris->{T2} };

        # Volume
        map {
            $record->append_fields(
                MARC::Field->new( '773', '1', '#', 't' => $_ ),
                MARC::Field->new( '502', '#', '#', 'n' => $_ ),
              )
        } @{ $ris->{VL} };

        # Publisher and year
        if ( $ris->{PY} || $ris->{CY} ) {
            my @subfield_a = map { +'a' => $_ } @{ $ris->{CY} };
            my @subfield_c = map { +'c' => $_ } @{ $ris->{PY} };
            my $field =
              MARC::Field->new( '264', '1', '1', @subfield_a, @subfield_c );
            $record->append_fields($field);
        }

        # Keywords
        foreach my $kws ( @{ $ris->{KW} } ) {
            foreach my $kw ( split( /\n/, $kws ) ) {
                next unless $kw;
                $record->append_fields(
                    MARC::Field->new( '650', '#', '0', a => $kw ) );
            }
        }

        print $record->as_formatted() . "\n\n";

        $batch .= $record->as_usmarc() . "\x1D";
    }

    return $batch;
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
