#!/bin/bash
# the following env variables should be set:
#
# DBHOST -- the host name of the MySQL database
# DBPORT -- the port of the MySQL database,
#           defaults to 3306 if unset
# DBROOT -- the root passwort of the databse,
#           is required if we need to setup the databse
# DBNAME -- the name of the database
# DBUSER -- the username of the database user
# DBPASS -- the password of the database user
#


# setup env for icinga
mkdir -p /run/icinga2/
chmod 777 /run/icinga2/


# check if database is up and running, credits go to:
# https://github.com/dominionenterprises/tol-api-php/blob/master/tests/provisioning/set-env.sh
if [ -n "${DBHOST}" ]
then
    [ -z "${DBPORT}" ] && export DBPORT=3306
    
    while ! exec 6<>/dev/tcp/"${DBHOST}"/"${DBPORT}"
    do
        echo "$(date) - still waiting for mysql at ${DBHOST}:${DBPORT} to come up"
        sleep 1
    done
    
    exec 6>&-
    exec 6<&-
    
    # ok, databse is up.
    
    
    # is the database already good to go or do we need to set it up?
    # if there is no table `icinga` we need to create it
    rows=$(mysqlshow -u "$DBUSER" "-p$DBPASS" -h "$DBHOST" -P "${DBPORT}" "$DBNAME" 2>/dev/null | wc -l)
    
    if [ "$?" != 0 ] || [ "$rows" -lt 10 ]
    then
        # ok, this is the first run, so let's setup the database
        echo "installing database for icinga2-ido-mysql"
        echo "CREATE DATABASE IF NOT EXISTS $DBNAME;" | mysql -u "$DBUSER" "-p$DBPASS" -h "$DBHOST" -P "${DBPORT}"
        echo "SET @@global.sql_mode='MYSQL40';" | mysql -u root "-p$DBROOT" -h "$DBHOST" -P "${DBPORT}"
        mysql -u "$DBUSER" "-p$DBPASS" -h "$DBHOST" -P "${DBPORT}" "$DBNAME" < /usr/share/icinga2-ido-mysql/schema/mysql.sql
        echo "mysql scheme for icinga2-ido-mysql imported"
    fi
fi

# and we're going for an infinte while loop
# while dumping icinga's log to std::out
#
# this way we can restart icinga by just shutting it down
# (when restarting icinga it will go background daemon
# and thus it won't print to std::out anymore...)
while true
do
    echo "starting icinga2 daemon"
    icinga2 daemon

    # sleeping for a bit gives us a chance to quit
    # the run.sh with a double ctrl+c
    sleep 2
done


