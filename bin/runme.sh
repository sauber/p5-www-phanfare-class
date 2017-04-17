#!/bin/sh

if [ ! $1 ] ; then
  echo "Usage: $1 <destdir>"
  exit 1
fi

bin=$(dirname $0)
perl -I$bin/../lib mirror.pl $1
