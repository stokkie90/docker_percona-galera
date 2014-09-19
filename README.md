Percona/Galera Replication Example
======================

Example of a Percona ( mysql ) replication cluster using coreos and friends.

Usage
====

Local Demo
-----------------

```console
$ vagrant up
$ ssh coreos-01
$ database
root@e9682b05cf5e:/# mysql -e "show status like 'wsrep_cluster%'"

```


Author(s)
======

Paul Czarkowski (paul@paulcz.net)

License
=====

Copyright 2014 Paul Czarkowski

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.