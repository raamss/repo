#!/bin/bash

if [ $# -lt 1 ]; then
  echo "Usage: $0 <repo_name_to_create>"
  exit 0
fi

if [ "${GITHUB_USER}" == "" ]; then
  export GITHUB_USER="ciuserr"
fi

if [ "${GITHUB_PASSWD}" == "" ]; then
  echo "Please ensure Github password is set for $GITHUB_USER that is configured. Will exit now"
  exit 1
fi

CHECK_REPO="curl -s -X GET -u $GITHUB_USER:$GITHUB_PASSWD https://api.github.com/repos/davinta/$1"
CREATE_REPO="curl -s -u $GITHUB_USER:$GITHUB_PASSWD -d '{ \"name\": \"$1\", \"auto_init\": true, \"private\": true }' https://api.github.com/orgs/davinta/repos"

if [ "$(eval $CHECK_REPO | grep message)" != "" ]; then
  eval $CREATE_REPO
else
  echo "Repo $1 exists or verification failed"
fi

git clone https://github.com/davinta/$1.git
cd $1
for i in develop feature; do echo $i; git branch $i; git checkout $i; git push origin $i; done
