#!/bin/bash

for file in passwd shadow group gshadow ; do
  cp /etc/${file}.CORRECT /etc/$file
done
