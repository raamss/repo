#!/bin/bash

#APP SERVER DAILY BACKUP

#Mongo Data Backups
MONGOSRCDIR="/var/lib/mongo/"
MONGODESTDIR="/altifinapps/backup/mongodata/"
MONGOFILENAME="mongo-$(date +%-Y%-m%-d).tgz"
tar czvf "$MONGODESTDIR$MONGOFILENAME" "$MONGOSRCDIR"
cd /altifinapps/backup/mongodata
find /altifinapps/backup/mongodata/mongo* -mtime +15 -exec rm {} \;
sleep 30s

#Platform Backups
PLATSRCDIR="/platform/"
PLATDESTDIR="/altifinapps/backup/platform/"
PLATFILENAME="platform-$(date +%-Y%-m%-d).tgz"
tar czvf "$PLATDESTDIR$PLATFILENAME" "$PLATSRCDIR"
cd /altifinapps/backup/platform
find /altifinapps/backup/platform/platform* -mtime +15 -exec rm {} \;
sleep 30s

#OnePlatform Backups
PLOGSSRCDIR="/appdata/logs/"
PLOGSDESTDIR="/altifinapps/backup/appdatalogs/"
PLOGSFILENAME="plogs-$(date +%-Y%-m%-d).tgz"
tar czvf "$PLOGSDESTDIR$PLOGSFILENAME" "$PLOGSSRCDIR"
cd /altifinapps/backup/appdatalogs
find /altifinapps/backup/appdatalogs/plogs* -mtime +15 -exec rm {} \;
sleep 30s
