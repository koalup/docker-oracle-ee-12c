docker-oracle-ee-12c
============================
## Oracle 12c Release 1 (12cR1) Enterprise Edition - Dockerfile
This repository contains a Dockerfile which builds a Docker image that has one Oracle 12c Release 1 Enterprise Edition container database (CDB) running on Oracle Enterprise Linux 7. 

I have intentionally chosen not to make a prebuilt image available on Docker Hub due to licensing conserns. I have also chosen not to automatically download the software or include it in this repository for the same reason.   

### How-To: Build
Download [Oracle Database 12c Release 1 Enterprise Edition for Linux x86-64](http://www.oracle.com/technetwork/database/enterprise-edition/downloads/index.html) and place the downloaded files in the same directory as the Dockerfile. Specifically you will need to download [File 1](http://download.oracle.com/otn/linux/oracle12c/121020/linuxamd64_12102_database_1of2.zip) and [File 2](http://download.oracle.com/otn/linux/oracle12c/121020/linuxamd64_12102_database_2of2.zip). 

Once the software has been downloaded run the following command to build the image:
```
docker build -t koalup/oracle-ee-12c --shm-size 1g .
```
The build process can take a while to complete since it has to install Oracle and create a container database, however, once the build is complete, you will be able to spawn containers relatively quickly. The image will contain an Oracle instance and CDB named ORCL with DBEXPRESS. The instance memory footprint (memory_target) is configured to be 1024m. 

The available build arguments are:

Arg|Values|Default|Description
---|---|---|---
gdbName|\<string\>|orcl|Global database name, ie db_name.db_domain.
sid|\<string\>|orcl|Oracle SID
characterSet|\<string\>|AL32UTF8|Database character set
http_proxy|\<string\>| |Proxy setting for yum
https_proxy|\<string\>| |Proxy setting for yum
no_proxy|\<string\>| |Proxy setting for yum

### How-To: Run
Once the image has been built, you can run it in a container by executing the following:
```
docker run -d -P --name orcl --shm-size 1g koalup/oracle-ee-12c
```
This will create a container called orcl from the image and run it in the background, exposing the SQL*Net and DBEXPRESS ports to the outside. The database alert log can be tailed by running the following:
```
docker logs -f orcl
```
The exposed ports are:
* `1521` - The default SQL*Net port
* `5500` - The CDB DBEXPRESS port

You will need to determine what external port each of the above ports are mapped to in order to access their services from outside of the container. The port mapping can be seen by running 
```
docker port orcl
```
You can use any SQL\*Net client, such as [Oracle SQL Developer](http://www.oracle.com/technetwork/developer-tools/sql-developer/overview/index-097090.html), to access the SQL\*Net port. You'll need to use the hostname or IP addess of the machine running the Docker daemon. 

SERVICE_NAME|USERNAME|PASSWORD|DESCRIPTION
---|---|---|---
ORCL|SYS|SYS|Container database SYS account. Must use sysdba option to login as this user.
ORCL|SYSTEM|SYSTEM|Container database as SYSTEM account

I've found that DBEXPRESS only works with Internet Explorer. Chrome shows the login screen but it returns the error `Security token does not match. You must login again...` after authentication. Haven't tried Forefox so it might be worth a shot. The URL is:

```
https://<docker_host>:<exposed_port>/em
```

You can also gain terminal access to the container by:
```
docker exec -it orcl /bin/bash
``` 
### How-To: Volumes
Docker allows you to overlay volumes on top of a container, which replaces the contents of the container with the contents of the volumes. One benefit of this is data separation, ie, you can have your database files separate from the container, which allows you to remove and create containers without losing your data. Another benefit is that the volume files appear as normal files on the Docker host, which is helpful for backups.   

Start with creating an inactive volume container named orcl_data which will house the database files. The following command creates an inactive container and copies the contents of /u01/app/oracle/oradata, /u01/app/oracle/fast_recovery_area, and /u01/app/oracle/product/12.1.0.2/dbhome_1/db to Docker volumes. 
```
docker create --name orcl_data \
	-v /u01/app/oracle/oradata \
	-v /u01/app/oracle/fast_recovery_area \
	-v /u01/app/oracle/product/12.1.0.2/dbhome_1/dbs \
koalup/oracle-ee-12c /bin/true
```
Next, create a new active container named orcl and overlay the volumes from the inactive orcl_data container. 
```
docker run --name orcl -d -P --volumes-from orcl_data --shm-size 1g koalup/oracle-ee-12c
```
Since the orcl_data is inactive, you have to run the following to see both the orcl and orcl_data containers
```
docker ps -a
```
Suppose for example that you want to make a change to the orcl container, like increasing the shm-size from 1g to 2g. Docker doesn't yet allow you to modify an existing container (unless you edit some obscure json file and restart the Docker daemon) so you'll have to remove and recreate it. To remove:
```
docker rm -f orcl
```
To recreate
```
docker run -d -P --volumes-from orcl_data --name orcl --shm-size 2g koalup/oracle-ee-12c
```
Removing the my_oracle_db container does not remove the contents of the orcl_data container. When the orcl container is recreated, the volumes from the orcl_data container are overlayed on top of it again. 

**BIG FAT WARNING:** Do not run more than one active container that uses the same volumes as it will most certainly cause data corruption because they will all try to write to the same database files at the same time, which is not good (unless you're running RAC). 

Have fun and please post any issues in the issues section. 
