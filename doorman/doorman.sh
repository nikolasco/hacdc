#!/bin/sh

LOG_FILE='doorman.log'
TMP_LOG_FILE="$LOG_FILE.new"

if [ -z "$DOORMAN_DIR" ]; then DOORMAN_DIR=`dirname $0`; fi

cd $DOORMAN_DIR
ruby doorman.rb 2>&1 | cat >> $LOG_FILE
tail -n 1000 $LOG_FILE > $TMP_LOG_FILE
mv $TMP_LOG_FILE $LOG_FILE
