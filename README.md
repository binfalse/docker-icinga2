# Docker image for Icinga2 +IDO-MySQL

The Dockerfile included in this repository compiles into a Docker image that contains an Icinga2 installation ready for IDO-MySQL.

If you run this image the container will already have a default icinga2 configuration in `/etc/icinga2`.
You may use that as a template but should maintain a persistent configuration outside of the container!

There is a compiled Docker image available at [binfalse/icinga2](https://hub.docker.com/r/binfalse/icinga2).

## Basic Setup

The following assumes that you store the config in `/srv/icinga-conf`.

### Extract a default config

To extract the default config you just need to:

* Run a temporary container, overriding the entrypoint to just have it sleeping instead running icinga
* Copy the `/etc/icinga2/` to `/srv/icinga-conf`
* Stop the container

The following will do the trick:

    # run a temporary container overriding the entrypoint with sleep 100
    # so it will just wait and do nothing
    docker run -d --name icinga-temp --entrypoint sleep binfalse/icinga2 100 
    # copy the /etc/icinga2 of the container to /srv/icinga-conf
    # (this will actually create /srv/icinga-conf/icinga2)
    docker cp icinga-temp:/etc/icinga2 /srv/icinga-conf
    # kill the running container and clean up
    docker kill icinga-temp
    docker rm icinga-temp

You will then find the template config in `/srv/icinga-conf/icinga2`, so go and adjust it as you want :)


### Setup IDO-MySQL

The IDO-MySQL feature is enabled by default, but its configuration is just a skeleton.
You can find it in `/srv/icinga-conf/icinga2/features-enabled/ido-mysql.conf`:

    library "db_ido_mysql"
    
    object IdoMysqlConnection "ido-mysql" {
      //user = "icinga"
      //password = "icinga"
      //host = "localhost"
      //database = "icinga"
    }

Go ahead and update the file with the information for your database.

If you want to disable the IDO-MySQL feature just remove the `features-enabled/ido-mysql.conf` file:

    rm /srv/icinga-conf/icinga2/features-enabled/ido-mysql.conf

This file is actually just a link to `../features-available/ido-mysql.conf`.
Thus, if you ever need to re-enable it, you just need to create that link again.


### Setup the Icinga2 API

Setting up the API is a bit more complex.
You need to create a `/srv/icinga-conf/icinga2/features-enabled/api.conf` that contains the paths to node's certificates.
It may look like the following:

    object ApiListener "api" {
      cert_path = SysconfDir + "/icinga2/pki/NODE.crt"
      key_path = SysconfDir + "/icinga2/pki/NODE.key"
      ca_path = SysconfDir + "/icinga2/pki/ca.crt"
    
      #ticket_salt = TicketSalt
    }

(You will find a template in `/srv/icinga-conf/icinga2/features-available/api.conf` and may just set a link)

In addition you need to create users that have permissions to use the API.
So create a new file `/srv/icinga-conf/icinga2/conf.d/api-users.conf`, that for example contains a root user with all permissions:

    object ApiUser "root" {
      password = "root-password"
      permissions = [ "*" ]
    }

However, with the above configuration the Docker container also needs

* a CA in `/var/lib/icinga2/ca`
* the CA's public key copied to `/etc/icinga2/pki/ca.crt`
* the node's X.509 certificates in `/ect/icinga2/pki/NODE.crt` and `/etc/icinga2/pki/NODE.key`

You may want to create the CA in `/srv/icinga-conf/ca` and then mount that to `/var/lib/icinga2/ca` when running the container.
Creating a CAand the certificates can be done in various ways, but is probably out of scope here.
Just as a hint, the steps will look like the following:

    # create a key
    openssl genrsa -out /srv/icinga-conf/ca/ca.key 2048
    # generate a self-signed ca cert
    openssl req -x509 -new -nodes -key /srv/icinga-conf/ca/ca.key -sha256 -days 1024 -out /srv/icinga-conf/ca/ca.crt
    # copy the CA's cert to the icinga configuration:
    cp /srv/icinga-conf/ca/ca.crt /srv/icinga-conf/icinga2/pki/ca.crt
    # generate a client key for this icinga node
    openssl genrsa -out /srv/icinga-conf/icinga2/pki/NODE.key 2048
    # create a cert signing request (CSR) for the node's cert
    openssl req -new -key /srv/icinga-conf/icinga2/pki/NODE.key -out /srv/icinga-conf/icinga2/pki/NODE.csr
    # sign the CSR with the CA
    openssl x509 -req -in /srv/icinga-conf/icinga2/pki/NODE.csr -CA /srv/icinga-conf/ca/ca.crt -CAkey /srv/icinga-conf/ca/ca.key -CAcreateserial -out /srv/icinga-conf/icinga2/pki/NODE.crt -days 500 -sha256

DO NOT JUST EXECUTE THESE COMMANDS.
They are just meant to help you figuring out what to do, so open your search engine and learn what the commands mean, what the options are, and what you need to do.
You may also want to use certificates from a proper CA etc?

However, the API will then be listening on port `5665` of the container, which is already exposed by default.


### Setup Icinga2 to monitor your infrastructure

Just continue with your usual Icinga2 setup.
Read the [Icinga docs](https://docs.icinga.com/icinga2/latest/doc/module/icinga2/toc) to learn more about the setup.



## Run the Image

### Prerequisites

Before you can run the image, you need to have a MySQL database running.
You could for example go for a Docker MySQL container:

    docker run --name some-mysql \
           -e MYSQL_ROOT_PASSWORD=root-pw \
           -e MYSQL_DATABASE=icinga \
           -e MYSQL_USER: icinga-user \
           -e MYSQL_PASSWORD: icinga-pw \
           -d mysql

This will also setup the password that Icinga2 will be unsing.

### Run Icinga2 from a terminal

To then run the Icinga2 image you need to:

* mount your configuration from `/srv/icinga-conf/icinga2` to the container's `/etc/icinga2`
* optionally mount the CA from `/srv/icinga-conf/ca` to `/var/lib/icinga2/ca` if you want to use the API
* optionally bind the API's port 5665 to the host 
* optionally provide the MySQL credentials if you want to use the IDO-MySQL feature

A typical command line call would look like:

    docker run -it --rm --name icinga                      \
           -v /srv/icinga-conf/icinga2:/etc/icinga2:ro     \
           # for the IDO-MySQL:                            \
           -e DBHOST=db                                    \
           -e DBPASS=ninja-super-secure                    \
           -e DBUSER=db-ninja                              \
           -e DBNAME=icinga                                \
           --link some-mysql:db                            \
           # for the API:                                  \
           -p 5665:5665                                    \
           -v /srv/icinga-conf/ca:/var/lib/icinga2/ca:ro   \
           # the actual image to run:                      \
           binfalse/icinga2

* If you do not want to use the IDO-MySQL feature just discard the `DBxxxx` environments and the `--link` option.
* If you don't need the API you don't need to mount `/srv/icinga-conf/ca` and you don't need to expose the port `5665`.


### Run Icinga2 with Docker-Compose

A useful Docker-Compose configuration may look like:

	version: '2'
	services:
			db:
					restart: always
					image: mysql
					volumes:
							- /srv/db:/var/lib/mysql
					environment:
							MYSQL_ROOT_PASSWORD: root-pw
							MYSQL_DATABASE: icinga
							MYSQL_USER: icinga-user
							MYSQL_PASSWORD: icinga-pw
					logging:
							driver: syslog
							options:
									tag: docker/icinga-db
			icinga:
					restart: always
					image: binfalse/icinga2
					volumes:
							- /srv/icinga-conf/icinga2:/etc/icinga2:ro
							- /srv/icinga-conf/ca:/var/lib/icinga2/ca:ro
					environment:
							DBHOST: db
							DBPASS: icinga-pw
							DBUSER: icinga-user
							DBNAME: icinga
							DBROOT: root-pw
					ports:
							- "5665:5665"
					links:
							- db
					logging:
							driver: syslog
							options:
									tag: docker/icinga



## More Details

### The Wrapper Script

If you run the container, it wouldn't just start the Icinga2 daemon, but calls a `/run.sh` wrapper script.
The script can be found as [`run.sh` in this repository](run.sh).
Before actually running the Icinga2 daemon it checks

* if you provided the DBHOST variable, in that case it assumes that you want to go with the IDO-MySQL feature
* if the database is already available
* if the database is already setup, otherwise it will deploy the IDO-MySQL scheme

In addition, it will run the Icinga2 daemon in an infinite while loop.
That way, you can reload the Icinga2 configuration by either killing the icinga process or [sending the shutdown signal through the API](https://docs.icinga.com/icinga2/snapshot/doc/module/icinga2/chapter/icinga2-api#icinga2-api-actions-shutdown-process).
We unfortunately cannot use the restart functionality of Icinga2, as this would daemonize the process into the background and we would loose the log-to-std::out, which is necessary for Docker's looging mechanisms.



## LICENSE

	docker-icinga2 -- A Docker Image for Icinga2 with support for IDO-MySQL 
	Copyright (C) 2016: Martin Scharm <https://binfalse.de>

	This program is free software: you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation, either version 3 of the License, or
	(at your option) any later version.

	This program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License
	along with this program.  If not, see <http://www.gnu.org/licenses/>.

