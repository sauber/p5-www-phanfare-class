#!perl -T

# Test all class methods

use Test::More;
use File::Slurp;
use_ok( 'WWW::Phanfare::Class' );
use lib 't';
use_ok( 'FakeAgent' );

my $class;
if ( $ENV{SITE} ) {
  # Create test object on live site
  my %config;
  eval '
    use Config::General;
    use File::HomeDir;
    use WWW::Phanfare::API;
    my $rcfile = File::HomeDir->my_home . "/.phanfarerc";
    %config = Config::General->new( $rcfile )->getall;
    die unless $config{api_key}
           and $config{private_key}
           and $config{email_address}
           and $config{password};
  ';
  plan skip_all => "Local config not found: $@" if $@;
  $class = new_ok( 'WWW::Phanfare::Class' => [ %config ] );

} else { 
  # Create an fake test object
  $class = new_ok( 'WWW::Phanfare::Class' => [ 
    api_key       => 'secret',
    private_key   => 'secret',
    email_address => 's@c.et',
    password      => 'secret',
  ] );
  $class->api( FakeAgent->new() );
}

isa_ok( $class, 'WWW::Phanfare::Class' );

# Verify there is account
ok( my $account = $class->account(), "Class has account" );
isa_ok( $account, 'WWW::Phanfare::Class::Account' );

# Verify there is a site
ok( my($sitename) = $account->names, "Class has sites" );
ok( my $site = $account->$sitename, "Class has site object" );
isa_ok( $site, 'WWW::Phanfare::Class::Site' );

# Verify there are years
#ok( my($yearname) = $site->names, "Class has years" );
my $yearname = '2011';
ok( my $year = $site->$yearname, "Class has year object" );
isa_ok( $year, 'WWW::Phanfare::Class::Year' );
diag "Year name: $yearname\n";

# Verify there are albums
ok( my($albumname) = grep /Sample/, $year->names, "Class has an album" );
diag "Album name: $albumname\n";
ok( my $album = $year->$albumname, "Class has album object" );
isa_ok( $album, 'WWW::Phanfare::Class::Album' );

# Verify there are sections
ok( my($sectionname) = $album->names, "Class has sections" );
ok( my $section = $album->$sectionname, "Class has section object" );
isa_ok( $section, 'WWW::Phanfare::Class::Section' );

# Verify there are renditions
ok( my($renditionname) = $section->names, "Class has renditions" );
ok( my $rendition = $section->$renditionname, "Class has section object" );
isa_ok( $rendition, 'WWW::Phanfare::Class::Rendition' );

# Verify there are images
ok( my @imagenames = $rendition->names, "Class has images" );
my $imagename = shift @imagenames;
ok( my $image = $rendition->$imagename, 'Class has image object' );
isa_ok( $image, 'WWW::Phanfare::Class::Image' );
diag "Image name: $imagename\n";

# Image attributes
ok( ! $image->attribute('key'), "Image attribute key does not exist" );
ok( ! $image->attribute('key', 'value'), "Image attribute key cannot be set" );
($attrkey) = grep !/(hidden|caption)/, $image->attributes;
$attrval = $image->attribute( $attrkey );
ok( defined $attrval, "Previous image attribute defined" );
ok( ! $image->attribute( $attrkey, 42 ), "Cannot set any attributes" );
ok( defined $image->attribute( 'hidden', $image->attribute('hidden') ), "Set image attribute hidden");

# Create, read and delete hide flag
my $prevhide = $image->_hidden;
ok( defined $prevhide, "Previous hide flag exists" );
ok( $image->_hidden( 1 ), "Set image hide flag 1" );
ok( $image->_hidden == 1, "Get image hide flag 1" );
ok( 0 == $image->_hidden( 0 ), "Set image hide flag 0" );
ok( $image->_hidden == 0, "Get image hide flag 0" );
ok( defined $image->_hidden( $prevhide ), "Restore image hide" );
ok( $prevhide == $image->_hidden, "Hide flag restored" );

# Hide and Caption are really just attributes
ok( $image->attribute('hidden') == $image->_hidden, "Image hide attribute" );

done_testing(); exit;
