#!/usr/bin/env perl

use warnings;
use strict;
use File::HomeDir;
use Config::General;
use WWW::Phanfare::Class;
#use Data::Printer;
use autodie;
use YAML::XS qw'DumpFile LoadFile';
use Data::Compare;
use File::Slurp;

our $dest;

# Connect to account
#
sub account {
  my $rcfile = File::HomeDir->my_home . "/.phanfarerc";
  my $conf   = Config::General->new( $rcfile );
  my %config = $conf->getall;
  my $class  = WWW::Phanfare::Class->new( %config);
  return $class->account;
}

# Create folder for object
#
sub mkfolder {
  my $obj = shift;
  my $node = $obj;
  my @parts;
  while ( $node->parent and $node->name ) {
    unless ( $node->attribute('filename') ) {
      my $name = $node->name;
      utf8::encode($name);
      $name =~ s,/,~,g; # / not allowed in dir names
      unshift @parts, $name;
    }
    $node = $node->parent;
  }

  my $folder = $dest;
  while ( my $part = shift @parts ) {
    $folder .= "/$part";
    #print "mkdir $folder\n";
    mkdir $folder unless -d $folder;
  }
  return $folder;
}

# Save yaml file if data has changed
#
sub yamlsave {
  my($file, $data) = @_;

  if ( -f $file && Compare( LoadFile($file), $data ) ) {
    #print "Kept $file\n";
  } else {
    DumpFile $file, $data;
    #print "Saved $file\n";
  }
}

# Save attributes as yaml file
#
sub metasave {
  my $obj = shift;

  my $base = mkfolder($obj);
  my $class = $obj->class;
  die p $obj unless $class;
  my $file = $base . "/$class.yaml";
  yamlsave($file, $obj->{_attr});
}

# Save image attributes and image
#
sub imgsave {
  my $img = shift;
  my $base = mkfolder($img->section);
  my $file = $img->_basename( $img->attribute('filename') );
  my $imgpath = "$base/$file";
  my $metpath = $imgpath; $metpath =~ s/\.[^\.]+$/.yaml/;
  yamlsave($metpath, $img->{_attr});
  # Download and save file if necessary
  if ( -f $imgpath and -s $imgpath == $img->attribute('filesize') ) {
    #print "Keep: $imgpath\n";
  } else {
    #print "Save: $imgpath\n";
    my $raw = $img->value;
    write_file( $imgpath, {binmode => ':raw'}, \$raw );
  }
  # Set timestamp of file
  my $sec = $img->_unixtime( $img->{_attr}{created_date} );
  if ( $sec != (stat($imgpath))[9] ) {
    #print "Save: set time to $sec\n";
    utime time, $sec, $imgpath;
  }
}

# Traverse tree of site, albums, sections, and images
#
sub traverse {
  my $account = account;
  for my $sitename ( $account->names ) {
    print "site: $sitename\n";
    my $site = $account->get($sitename);
    for my $yearname ( $site->names ) {
      print " year: $yearname\n";
      my $year = $site->get( $yearname );
      for my $albumname ( $year->names ) {
        print "  album: $albumname\n";
        my $album = $year->get( $albumname );
        #p $album->{_attr};
        metasave( $album );
        for my $sectionname ( $album->names ) {
          print "   section: $sectionname\n";
          my $section = $album->get( $sectionname );
          #p $section->{_attr};
          metasave( $section );
          my $original = $section->get('Full');
          for my $imagename ( $original->names ) {
            print "    image: $imagename\n";
            my $image = $original->get($imagename);
            imgsave( $image );
            #p $image->{_attr};
          }
        }
      }
    }
  }
}

# Create destination folder
#
sub mktopdest {
  mkdir $dest unless -d $dest;
}

### MAIN ###############################################################

$dest = shift @ARGV;
die "error: missing destination folder" unless $dest;
mktopdest;
traverse;
