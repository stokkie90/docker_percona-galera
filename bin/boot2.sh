#!/bin/bash
#
# This script is designed to be run inside the container
#

# fail hard and fast even on pipelines
set -eo pipefail

# set debug based on envvar
[[ $DEBUG ]] && set -x

DIR=$(dirname $0)

# functions
. $DIR/functions

DB_OPTIONS=""
MYSQL_USER=${MYSQL_USER:-admin}
MYSQL_PASS=${MYSQL_PASS:-admin}
REP_USER=${REP_USER:-replicator}
REP_PASS=${REP_PASS:-replicator}
PORT=${PORT_3306:-3306}
PUBLISH=${PORT:-3306}
PORT_4567=${PORT_4567:-4567}
PORT_4444=${PORT_4444:-4444}
PORT_3306=${PORT_3306:-3306}
PROTO=${PROTO:-tcp}
ETCD_HOST=${ETCD_HOST:-$HOST}
DATA_DIR=${DATA_DIR:-/var/lib/mysql}
HOSTNAME=${HOST:-$(hostname)}

if [[ -z $HOST ]]; then
  echo '==> $HOST not set.  booting mysql without clustering.'
  init_database
  echo "==> database running..."
  touch /var/log/mysql/error.log
  tail -f /var/log/mysql/error.log &
  mysqld_safe $DB_OPTIONS
  exit $?
fi

configure_etcd

etcd_set_default engine percona
etcd_set_default credentials/adminUser ${MYSQL_USER}
etcd_set_default credentials/adminPass ${MYSQL_PASS}
etcd_set_default credentials/repUser ${REP_USER}
etcd_set_default credentials/repPass ${REP_PASS}
etcd_set_default host $HOST
etcd_set_default port $PORT
etcd_set_default sst/$HOST/address $HOST:$PORT_4444

if [[ ! -z $CLUSTER ]]; then
  etcd_set_default cluster/name ${CLUSTER}
  etcd_make_directory cluster/mysqlNodes
  etcd_make_directory cluster/galeraEndpoints
fi

## Creaing / Updating mysql config ( doesnt use confd because it needs a etcd cluster)
update_mysql_config


# initialize data volume
init_database

WSREP_OPTIONS="--wsrep_node_address=$HOST $DB_OPTIONS"
cluster_members

echo Starting MySQL for reals

if [[ -z $CLUSTER_MEMBERS ]]; then
  # Perform Election
  echo "==> Performing Election..."
  etcdctl $ETCD_OPTIONS ls $ETCD_PATH/election >/dev/null 2>&1 || etcdctl $ETCD_OPTIONS mkdir $ETCD_PATH/election >/dev/null 2>&1
  if etcdctl $ETCD_OPTIONS mk $ETCD_PATH/election/bootstrap $HOSTNAME >/dev/null 2>&1; then
    echo "-----> Hurruh I win!"
    BOOTSTRAP=1
    etcdctl $ETCD_OPTIONS set $ETCD_PATH/election/bootstrap $HOSTNAME --ttl 300 >/dev/null 2>&1
    mysqld --wsrep-new-cluster $WSREP_OPTIONS &
  else
    echo -n "-----> I lost election.  Waiting for leader."
    until [[ ! -z $CLUSTER_MEMBERS ]]; do
      cluster_members
      echo -n "."
      sleep 10
    done
    echo "-----> leader ready.  Starting."
    sleep 5
    echo "-----> joining cluster with known members: $CLUSTER_MEMBERS"
    setup_wsrep
    mysqld --wsrep_cluster_address=gcomm://$CLUSTER_MEMBERS $WSREP_OPTIONS &
	#service mysql start
  fi
else
  cluster_members
  echo "-----> joining cluster with known members: $CLUSTER_MEMBERS"
 setup_wsrep
mysqld --wsrep_cluster_address=gcomm://$CLUSTER_MEMBERS $WSREP_OPTIONS &
#service mysql start
fi


SERVICE_PID=$!

echo $SERVICE_PID > /app/database.pid

# smart shutdown on SIGINT and SIGTERM
trap on_exit INT TERM

# spawn confd in the background to update services based on etcd changes
#confd -node $ETCD -config-file /app/confd.toml &
#CONFD_PID=$!
#
# wait for the service to become available
echo "==> sleeping for 20 seconds, then testing if DB is up."
sleep 20
while [[ -z $(netstat -lnt | awk "\$6 == \"LISTEN\" && \$4 ~ \".$PUBLISH\" && \$1 ~ \"$PROTO.?\"") ]] ; do sleep 1; done

echo "==> database running..."

tail -f /var/log/mysql/error.log &

# publish the service to etcd using the injected HOST and PORT
if [[ ! -z $PUBLISH ]]; then

  set +e

  # wait for the service to become available on PUBLISH port
  sleep 1 && while [[ -z $(netstat -lnt | awk "\$6 == \"LISTEN\" && \$4 ~ \".$PUBLISH\" && \$1 ~ \"$PROTO.?\"") ]] ; do sleep 1; done

  # while the port is listening, publish to etcd
  while [[ ! -z $(netstat -lnt | awk "\$6 == \"LISTEN\" && \$4 ~ \".$PUBLISH\" && \$1 ~ \"$PROTO.?\"") ]] ; do
    publish_to_etcd
    sleep $(($ETCD_TTL/2)) # sleep for half the TTL
  done

  # if the loop quits, something went wrong
  exit 1

fi

wait
