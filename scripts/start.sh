#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -x

gosu root chmod a+wrx /tmp
WORK_DIR=$HOME
cd $HOME
gosu seqware bash -c "$*"
#allow cwltool to pick up the results created by seqware
gosu root chmod -R a+wrx $WORK_DIR

