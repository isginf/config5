#!/bin/sh

rm -rf tmp
mkdir tmp
(cd .. ; git archive master ) | tar -x -C tmp
VERSION=`cat tmp/VERSION`
mv tmp config5-$VERSION

(
  cd config5-$VERSION/extensions
  for dir in *
  do
    cd $dir
    name=`echo $dir | tr '[:upper:]' '[:lower:]'`
    tar --exclude=.svn --exclude=.git -cf - . | gzip -9 > ../../$name.tgz 
    cd ..
  done

  cd ..
  rm -rf extensions
  mkdir extensions
  mv *.tgz extensions
)

rm -rf config5-$VERSION/devel config5-$VERSION/contrib config5-$VERSION/docs/src
tar zcf config5-$VERSION.tgz config5-$VERSION
mv config5-$VERSION config5-latest
tar zcf config5-latest.tgz config5-latest
rm -rf config5-latest
