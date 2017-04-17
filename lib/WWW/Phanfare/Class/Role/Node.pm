package WWW::Phanfare::Class::Role::Node;
use Moose::Role;
use MooseX::Method::Signatures;
use Time::Local;

# All nodes in the tree must have a parent
#
has parent => (
  is => 'ro',
  required => 1,
  isa => 'WWW::Phanfare::Class::Role::Node',
);

# Name/id of node
#
has name => ( isa => 'Str', is => 'ro', required => 1 );
has id   => ( isa => 'Int', is => 'ro' );

# Get uid and agent from parent
#
method uid   { $self->parent->uid   }
method api { $self->parent->api }

# Name of object class
#
method class {
  my $string = "$self";
  $string =~ /::(\w+?)=HASH/ and return $1;
}

# Search through a data tree parsed from xml to find substructures or attributes
#
method _treesearch ( Ref $tree, ArrayRef $path ) {
  my @part = @$path;
  my $node = $tree;
  for my $part ( @$path ) {
    if ( ref $part eq 'HASH' ) {
      # Pick element from list
      my($key,$value) = each %$part;
      $node = [ $node ] unless ref $node eq 'ARRAY';
      my $notfound = {};
      for my $subnode ( @$node ) {
        my $treevalue = $subnode->{$key};
        # Take path off filenames
        $treevalue = $self->_basename($treevalue) if $key eq 'filename';
        # Just compare first part of the string for cases with .id appended
        $treevalue = substr $treevalue, 0, length $value;
        if ( $value eq $treevalue ) {
          $node = $subnode;
          undef $notfound;
          last;
        }
      }
      $node = $notfound if $notfound;
    } else {
      # Pick attribute
      $node = $node->{$part};
    }
  }
  return $node;
}

# Translate a full path filename to basename
#   Example: C:\Dir1\IMG_1234.JPG => IMG_1234.JPG
#
method _basename ( Str $filename ) {
  my $basename = ( split /[\/\\]/, $filename)[-1]; # Remove dir path
  if ( $self->name eq 'Caption' ) {
    # Caption uses .txt extension
    $basename =~ s/(.*)\..+?$/$1\.txt/ or $basename .= '.txt';
  }
  return $basename;
}

# Convert unix time to phanfare time
#   Example: 2011-08-23T05:59:28
#
method _phanfaretime ( Int $sec ) {
  my @t = gmtime $sec;
  return sprintf "%04i-02%i-%02iT%02i:%02i:%02i",
    $t[5]+1900, $t[4]+1, $t[3],
    $t[2], $t[1], $t[0];
}

# Convert phanfare time to unix time
#
method _unixtime ( Str $time ) {
  $time =~ /(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})/;
  return timegm($6, $5, $4, $3, $2-1, $1-1900);
}


=head1 NAME

WWW::Phanfare::Class::Role::Node - Base Node Class

=head1 DESCRIPTION

General accessors and converter methods.

=head1 SEE ALSO

L<WWW::Phanfare::Class>

=head1 LICENSE AND COPYRIGHT

Copyright 2011 Soren Dossing.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut

1;
