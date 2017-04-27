#!/bin/sh

if [ ! $1 ] ; then
  echo "Usage: $1 <destdir> [<subdir>]"
  exit 1
fi

bin=$(dirname $0)
perl -I$bin/../lib -I../lib -I$bin/../../p5-www-phanfare-api/lib -I../../p5-www-phanfare-api/lib mirror.pl "$1" "$2"
