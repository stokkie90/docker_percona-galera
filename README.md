Percona/Galera Docker Image
===========================

This docker image contains Percona with the galera extentions and XtraBackup installed.

If etcd is available it will automatically cluster itself with Galera and the XtraBackup SST.


TODO
========

	Backup cronjob with Chronos??
	



Fetching
========

    $ git clone https://github.com/paulczar/docker-percona_galera.git
    cd docker-percona_galera

Building
========

    $ docker build -t paulczar/percona-galera .

Running
=======

Just a database
---------------

MySQL root user is available from localhost without a password.  a default user/pass pair of admin/admin is pulled in from environment variables which has root like perms.  set it to something sensible.

	 $ docker run -d -e MYSQL_USER=admin -e MYSQL_PASS=lolznopass paulczar/percona-galera
	  ==> $HOST not set.  booting mysql without clustering.
	  ==> An empty or uninitialized database is detected in /var/lib/mysql
    ==> Creating database...
    ==> Done!
    ==> starting mysql in order to set up passwords
    ==> sleeping for 20 seconds, then testing if DB is up
    140920 16:22:26 mysqld_safe Logging to '/var/log/mysql/error.log'.
    140920 16:22:26 mysqld_safe Starting mysqld daemon with databases from /var/lib/mysql
    140920 16:22:26 mysqld_safe Skipping wsrep-recover for empty datadir: /var/lib/mysql
    140920 16:22:26 mysqld_safe Assigning 00000000-0000-0000-0000-000000000000:-1 to wsrep_start_position
    ==> stopping mysql after setting up passwords
    140920 16:22:47 mysqld_safe mysqld from pid file /var/run/mysqld/mysqld.pid ended
    140920 16:22:48 mysqld_safe Logging to '/var/log/mysql/error.log'.
    140920 16:22:48 mysqld_safe Starting mysqld daemon with databases from /var/lib/mysql
    140920 16:22:48 mysqld_safe Skipping wsrep-recover for empty datadir: /var/lib/mysql
    140920 16:22:48 mysqld_safe Assigning 00000000-0000-0000-0000-000000000000:-1 to wsrep_start_position

Galera Cluster
--------------

When etcd is available the container will check to see if there's an existing cluster, if so it will join it.  If not it will perform an election that will last for 5 minutes.  During that time the first server that can grab a lock becomes the leader and any other nodes will wait until that server is ready before starting.   If the leader fails to start the election is busted and all nodes will need to be destroyed until the 5 minutes passes.

Requirements:

- 1 ETCD_server
- 1 Container per Host (due to port conflicts)

Optional: Mesos_cluster (+ Marathon)

- Make sure HOST PORTS (3306, 4444, 4567, 4568) are allowed (mesos-slave resources)
 


Mesos + Marathon:
-----------------

Specify in the env variables the following:

Required:

- CLUSTER
- ETCD_HOST
- HOST (mesos already passes this one)

OPTIONAL:

- DATA_DIR
- MYSQL_USER
- MYSQL_PASS
- REP_USER
- REP_PASS
- HOST


SWARM EXAMPLE:

RUN ETCD: 

	docker run -d \
	--name=etcd \
	-e SERVICE_NAME=etcd \
	-p 4001:4001 \
	-p 7001:7001 \
	quay.io/philipsoutham/etcd:latest \
	-addr=0.0.0.0:4001 \
	-peer-addr=0.0.0.0:7001 \
	-name=etcd_master
	

RUN DBS (3 times) (change HOST, NAME, CONSTRAIN)

	docker run -d -e SERVICE_NAME=dbs \
	-p 3306:3306 \
	-p 4444:4444 \
	-p 4567:4567 \
	-p 4568:4568 \
	-e CLUSTER=<CLUSTER_NAME> \
	-e ETCD_HOST=<IP OF NODE WHERE ETCD IS RUNNING> \
	-e DEBUG=true \
	--name=<container-name> \
	-e HOST=<IP of Host where it runs> \
	-e constraint:node==<name of node> \
	rickstok/docker_percona-galera

