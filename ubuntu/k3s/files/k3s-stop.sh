#!/bin/bash

HOSTNAME=`hostname`

# signal the leader to drain services from our node
wget -nv -q -O - --retry-connrefused --tries=10 --waitretry 5 http://leader:1337/drain/$HOSTNAME