#!/bin/bash

shPath=$(cd `dirname $0`; pwd)

echo $shPath

cd $shPath
hexo g
hexo d
