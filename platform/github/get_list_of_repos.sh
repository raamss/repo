#!/bin/bash
if [ -z $GITHUB_PASSWD ]; then
 echo "Export the GITHUB Password for ciuserr and retry"
 exit 1
fi
for i in 1 2 3 
do 
  curl -X GET -u ciuserr:$GITHUB_PASSWD "https://api.github.com/orgs/davinta/repos?per_page=100&page=$i" | grep \"name\": | awk '{ print $2}' | sed -e 's/^"//g; s/",$//g' >> repo.list
done
