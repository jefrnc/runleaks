#!/bin/bash

####################################################################

# Register a secret provider
git secrets --register-azure --global
#git secrets --register-aws --global

####################################################################

# Add a prohibited pattern
git secrets --add --global '[A-Z0-9]{20}'

####################################################################

# Add a string that is scanned for literally (+ is escaped):
git secrets --add --global --literal 'foo+bar'

####################################################################
