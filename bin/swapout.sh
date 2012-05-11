#!/bin/bash

for file in passwd shadow group gshadow ; do
  cp /etc/${file}.SPECIAL /etc/$file
done
