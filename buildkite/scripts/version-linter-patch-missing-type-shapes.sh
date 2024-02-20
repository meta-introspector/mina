#!/bin/bash

set -eo pipefail

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <release-branch>"
    exit 1
fi

# Don't prompt for answers during apt-get install
export DEBIAN_FRONTEND=noninteractive

git config --global --add safe.directory /workdir

source buildkite/scripts/handle-fork.sh
source buildkite/scripts/export-git-env-vars.sh

base_branch=${REMOTE}/${BUILDKITE_PULL_REQUEST_BASE_BRANCH}
release_branch=${REMOTE}/$1

BASE_BRANCH_COMMIT=$(git log -n 1 --format="%h" --abbrev=7 --no-merges $base_branch)
RELEASE_BRANCH_COMMIT=$(git log -n 1 --format="%h" --abbrev=7 --no-merges $release_branch)


BASE_BRANCH_TYPE=$(gsutil ls gs://mina-type-shapes/$BASE_BRANCH_COMMIT || 0)
RELEASE_BRANCH_TYPE=$(gsutil ls gs://mina-type-shapes/$RELEASE_BRANCH_COMMIT || 0)

if [ "$BASE_BRANCH_TYPE" == 0 ]; then
    git checkout $BASE_BRANCH_COMMIT
    eval $(opam config env)
    export PATH=/home/opam/.cargo/bin:/usr/lib/go/bin:$PATH
    export GO=/usr/lib/go/bin/go
    make -C src/app/libp2p_helper

    dune exec src/app/cli/src/mina.exe internal dump-mina-shapes 2> ${BASE_BRANCH_COMMIT}_type-shapes.txt
    gsutil cp ${BASE_BRANCH_COMMIT}_type-shapes.txt gs://mina-type-shapes
fi


if [ "$RELEASE_BRANCH_TYPE" == 0 ]; then
    git checkout $RELEASE_BRANCH_COMMIT
    eval $(opam config env)
    export PATH=/home/opam/.cargo/bin:/usr/lib/go/bin:$PATH
    export GO=/usr/lib/go/bin/go
    make -C src/app/libp2p_helper

    dune exec src/app/cli/src/mina.exe internal dump-mina-shapes 2> ${RELEASE_BRANCH_COMMIT}_type-shapes.txt
    gsutil cp ${RELEASE_BRANCH_COMMIT}_type-shapes.txt gs://mina-type-shapes
fi