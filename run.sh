#!/bin/bash

# setup env for icinga
mkdir -p /run/icinga2/
chmod 777 /run/icinga2/


# is the database already good to go or do we need to set it up?
# if there is no table `icinga` we need to create it
rows=$(mysqlshow -u "$DBUSER" "-p$DBPASS" -h "$DBHOST" "$DBNAME" 2>/dev/null | wc -l)

if [ "$?" != 0 ] && [ "$rows" -gt 5 ]
then
    # ok, this is the first run, so let's setup the database
    echo "CREATE DATABASE $DBNAME;" | mysql -u "$DBUSER" "-p$DBPASS" -h "$DBHOST"
    echo "SET @@global.sql_mode='MYSQL40';" | mysql -u "$DBUSER" "-p$DBPASS" -h "$DBHOST"
    mysql -u "$DBUSER" "-p$DBPASS" -h "$DBHOST" "$DBNAME" < /usr/share/icinga2-ido-mysql/schema/mysql.sql
fi


# and we're going for an infinte while loop
# while dumping icinga's log to std::out
#
# this way we can restart icinga by just shutting it down
# (when restarting icinga it will go deamon
# and thus it won't print to std::out anymore...)
while true
do
    icinga2 daemon

    # sleeping for a bit gives us a chance to quit
    # the run.sh with a double ctrl+c
    sleep 2
done


