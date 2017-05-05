#!/usr/bin/env perl

use warnings;
use strict;
use File::HomeDir;
use Config::General;
use WWW::Phanfare::Class;
use Data::Printer;
use autodie;
use YAML qw'Dump LoadFile';
use Data::Compare;
use File::Slurp;
use List::Util qw(shuffle);
use Try::Tiny;
use utf8;
use Data::Dumper;
use File::Basename;

our $dest;
our @startfolder;

# Connect to account
#
sub account {
  my $rcfile = File::HomeDir->my_home . "/.phanfarerc";
  my $conf   = Config::General->new( $rcfile );
  my %config = $conf->getall;
  my $class  = WWW::Phanfare::Class->new( %config);
  return $class->account;
}

sub hdump {
  my $offset = 0;
  my(@array,$format);
  foreach my $data (unpack("a16"x(length($_[0])/16)."a*",$_[0])) {
    my($len)=length($data);
    if ($len == 16) {
      @array = unpack('N4', $data);
      $format="0x%08x (%05d)   %08x %08x %08x %08x   %s\n";
    } else {
      @array = unpack('C*', $data);
      $_ = sprintf "%2.2x", $_ for @array;
      push(@array, '  ') while $len++ < 16;
      $format="0x%08x (%05d)" .
         "   %s%s%s%s %s%s%s%s %s%s%s%s %s%s%s%s   %s\n";
    } 
    $data =~ tr/\0-\37\177-\377/./;
    printf $format,$offset,$offset,@array,$data;
    $offset += 16;
  }
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
      $name =~ s,[:/],~,g; # / and : not allowed in dir names
      unshift @parts, $name;
    }
    $node = $node->parent;
  }

  my $folder = $dest;
  while ( my $part = shift @parts ) {
    $folder .= "/$part";
    #utf8::upgrade($folder);
    #print "mkdir $folder\n";
    #print "folder $folder is utf8: " . utf8::is_utf8($folder) . "\n";
    mkdir $folder unless -d $folder;
  }
  return $folder;
}

# Save yaml file if data has changed
#
sub yamlsave {
  my($file, $data) = @_;

  utf8::downgrade($file);

  # Load data
  if ( -f $file ) {
    my $olddata;
    try {
      $olddata = LoadFile($file);
    };
    return if Compare( $olddata, $data );
    #print "Kept $file\n";
  }

  # Save data
  try {
    my $yaml = Dump $data;
    write_file( $file, { binmode => ':utf8' }, $yaml );
  } catch {
    print "YAML save failed. Saving to $file.dump\n";
    my $dirname = dirname("$file.dump");
    print "yamlsave dirname $dirname\n";
    print "dirname is utf8: " . utf8::is_utf8($dirname) . "\n";
    write_file( "$file.dump", { binmode => ':utf8' }, Dumper($data) );
  };
}

# Save attributes as yaml file
#
sub metasave {
  my $obj = shift;

  my $base = mkfolder($obj);
  my $class = $obj->class;
  die p $obj unless $class;
  $class =~ s,[:/],~,g; # / and : not allowed in file names
  my $file = $base . "/$class.yaml";
  yamlsave($file, $obj->{_attr});
}

# Save image attributes and image
#
sub imgsave {
  my($img, $imagename) = @_;;
  my $base = mkfolder($img->section);
  #my $file = #$img->_basename( $img->attribute('filename') );
  my $file = $imagename;
  $file =~ s,[:/],~,g; # / and : not allowed in file names
  my $imgpath = "$base/$file";
  my $metpath = $imgpath; $metpath =~ s/\.[^\.]+$/.yaml/;
  yamlsave($metpath, $img->{_attr});
  utf8::downgrade($imgpath);
  if ( -f $imgpath and -s $imgpath == $img->attribute('filesize') ) {
    #print "Keep: $imgpath\n";
  } else {
    printf "Save %s: %s\n", $img->name, $imgpath;
    if ( $img->save( $imgpath ) ) {
      # Set timestamp of file
      my $sec = $img->_unixtime( $img->{_attr}{created_date} );
      if ( $sec != (stat($imgpath))[9] ) {
        #print "Save: set time to $sec\n";
        utime time, $sec, $imgpath;
      }
    }
  }
}

# Traverse tree of site, albums, sections, and images
#
sub traverse {
  my $account = account;
  my @sitelist =   $startfolder[0]
               ? ( $startfolder[0] )
               : ( shuffle $account->names );
  for my $sitename ( @sitelist ) {
    print "site: $sitename\n";
    my $site = $account->get($sitename);
    my @yearlist =   $startfolder[1]
                 ? ( $startfolder[1] )
                 : ( shuffle $site->names );
    for my $yearname ( @yearlist ) {
      print " year: $yearname\n";
      my $year = $site->get( $yearname );
      my @albumlist =   $startfolder[2]
                    ? ( $startfolder[2] )
                    : ( shuffle $year->names );
      for my $albumname ( @albumlist ) {
        my $utf8_albumname = $albumname;
        utf8::encode($utf8_albumname);
        print "  album: $utf8_albumname\n";
        my $album = $year->get( $albumname );
        metasave( $album );
        my @sectionlist =   $startfolder[3]
                        ? ( $startfolder[3] )
                        : ( shuffle $album->names );
        for my $sectionname ( @sectionlist ) {
          print "   section: $sectionname\n";
          my $section = $album->get( $sectionname );
          metasave( $section );
          my $original = $section->get('Full');
          my @imagelist =   $startfolder[4]
                        ? ( $startfolder[4] )
                        : ( shuffle $original->names );
          for my $imagename ( @imagelist ) {
            print "    image: $imagename\n";
            my $image = $original->get($imagename) or die;
            imgsave( $image, $imagename );
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

#p @ARGV;
$dest = shift @ARGV;
die "error: missing destination folder" unless $dest;
@startfolder = split /\//, shift @ARGV;
mktopdest;
traverse;
