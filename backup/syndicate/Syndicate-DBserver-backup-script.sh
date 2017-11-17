ERVER DAILY BACKUP

#Mongo Data Backups
MONGOSRCDIR="/opt/aeus-db/mongodb/data/"
MONGODESTDIR="/home/altifinfi/backup/mongodata/"
MONGOFILENAME="mongo-$(date +%-Y%-m%-d).tgz"
tar czvf "$MONGODESTDIR$MONGOFILENAME" "$MONGOSRCDIR"
cd /home/altifinfi/backup/mongodata
find /home/altifinfi/backup/mongodata/mongo* -mtime +15 -exec rm {} \;
sleep 30s

#Neo4j Backup
NEO4JSRCDIR="/opt/aeus-db/neo4j-community-3.2.1/data/"
NEO4JDESTDIR="/home/altifinfi/backup/Neo4jdata/"
NEO4JFILENAME="neo4j-$(date +%-Y%-m%-d).tgz"
tar czvf "$NEO4JDESTDIR$NEO4JFILENAME" "$NEO4JSRCDIR"
cd /home/altifinfi/backup/Neo4jdata
find /home/altifinfi/backup/Neo4jdata/neo4j* -mtime +15 -exec rm {} \;
sleep 30s

#Mysql database Backup
cd /home/altifinfi/backup/Mysqldatabases
mysqldump -uroot -pAlti@123# --events --routines --triggers --all-databases | gzip > mysql_alldb_$(date -d "today" +"%Y-%m-%d").sql.gz
find /home/altifinfi/backup/Mysqldatabases/all-databases* -mtime +15 -exec rm {} \;
sleep 30s
