#!/bin/bash

source="/source/path/"
destination="/destination/path/"

# rsyncs the source to the destination
sudo rsync -avzP $source $destination
