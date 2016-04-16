docker-oracle-ee-12c
============================
## Oracle 12c Enterprise Edition - Dockerfile
This repository contains a Dockerfile to build a Docker image of an Oracle container database with one pluggable database running Oracle Database 12c Enterprise Edition. I have chosen not to make a prebuilt image available on Docker Hub due to licensing issues. I have also chosen not to automatically download the software or include it in this repository for the same reasons and because downloading the software requires OTN credentials, which I did not want to include in the Dockerfile.  

### How-To: Build
Download the Oracle Database 12c Release 1 for Linux x86-64 software from http://www.oracle.com/technetwork/database/enterprise-edition/downloads/index.html and place the downloaded files in the same directory as the Dockerfile. Specifically you will need to download [File 1](http://download.oracle.com/otn/linux/oracle12c/121020/linuxamd64_12102_database_1of2.zip) and [File 2](http://download.oracle.com/otn/linux/oracle12c/121020/linuxamd64_12102_database_2of2.zip). 

Once the software has been downloaded run the following command to build the image:
```
docker build -t koalup/oracle-ee-12c --shm-size 1g .
```
The build process can take a while to complete since it has to install Oracle and create a container database with one pluggable database, however, once the build is complete, you will be able to spawn many containers relatively quickly. The image will contain an Oracle instance and CDB named ORCL with one PDB named PDB1. Oracle DBEXPRESS will also be enabled for both the CDB and PDB. 

By default, the instance memory footprint (memory_target) is configured to be 1024m. You can override that by specifying the `totalMemory` build-arg. For example:
```
docker build -t koalup/oracle-ee-12c --shm-size 2g --build-arg totalMemory=2048 .
```
Make sure you adjust `--shm-size` accordingly otherwise the instance won't start. Other build-args are:
* `characterSet` - Sets the database character set. Default is AL32UTF8
* `db_recovery_file_dest_size` - Specifies the recovery area size in bytes. Default is 8589934592 (8 GB)

### How-To: Run
Once the image has been built, you can run it in a container by executing the following:
```
docker run -d -P --name my_oracle_db --shm-size 1g koalup/oracle-ee-12c
```
This will create a container called my_oracle_db from the image and run it in the background, exposing the SQL*Net and DBEXPRESS ports to the outside. The database alert log can be tailed by running the following:
```
docker logs -f my_oracle_db
```
The exposed ports are:
* `1521` - The default SQL*Net port
* `5500` - The CDB DBEXPRESS port
* `5501` - The PDB DBEXPRESS port

You will need to determine what external port each of the above ports are mapped to in order to access their services from outside of the container. The port mapping can be seen by running 
```
docker port my_oracle_db
```
You can use any SQL\*Net client, such as [Oracle SQL Developer](http://www.oracle.com/technetwork/developer-tools/sql-developer/overview/index-097090.html), to access the SQL\*Net port. You'll need to use the hostname or IP addess of the machine running the Docker daemon. 

SERVICE_NAME|USERNAME|PASSWORD|DESCRIPTION
---|---|---|---
ORCL|SYS|DOCKER|ORCL container database as SYS
ORCL|SYSTEM|DOCKER|ORCL container database as SYSTEM
DPB1|DOCKER|DOCKER|PDB1 pluggable database as DOCKER

I've found that DBEXPRESS only works with Internet Explorer. Chrome shows the login screen but it returns the error `Security token does not match. You must login again...` after authentication. Haven't tried Forefox so it might be worth a shot. The URL is:

```
https://<docker_host>:<exposed_port>/em
```

You can also gain terminal access to the container by:
```
docker exec -it my_oracle_db /bin/bash
``` 
### How-To: Volumes
Docker allows you to overlay volumes on top of a container, which replaces the contents of the container with the contents of the volumes. One benefit of this with respect to this image is data separation, ie, you can have your database files separate from the container, which allows you to remove and create a new container without losing your data. Another benefit is that the database files appear as normal files on the Docker host, which is helpful for backups. This solution is only partially complete since I haven't figured out a good way to handle files in ORACLE_HOME/dbs, yet.  

Start with creating a volume container named my_oracle_db_data which will house our the database files. The following command creates a non-running container and copies the contents of /u01/app/oracle/oradata and /u01/app/oracle/fast_recovery_area to a couple of volumes. 
```
docker create -v /u01/app/oracle/oradata -v /u01/app/oracle/fast_recovery_area --name my_oracle_db_data koalup/oracle-ee-12c /bin/true
```
Next, run a new container named my_oracle_db and overlay the volumes from our my_oracle_db_data volume container on top of it. 
```
docker run -d -P --volumes-from my_oracle_db_data --name my_oracle_db --shm-size 1g koalup/oracle-ee-12c
```
Since the my_oracle_db_data is not running, you have to run the following to see both the my_oracle_db and my_oracle_db_data containers
```
docker ps -a
```
Lets say that you want to make a change to the the my_oracle_db container, say increase the shm-size. Docker doesn't yet allow you to modify an existing container (unless you edit some obscure json file and restart the Docker daemon) so you'll have to remove and recreate it. To remove:
```
docker stop my_oracle_db
docker rm my_oracle_db
```
To recreate
```
docker run -d -P --volumes-from my_oracle_db_data --name my_oracle_db --shm-size 2g koalup/oracle-ee-12c
```
Removing the my_oracle_db container does not remove the contents of the my_oracle_db_data container. When the my_oracle_db container is recreated, the volumes from the my_oracle_db_data container are overlayed on top of it again. 

**BIG FAT WARNING:** Do not run more than one container that uses the same volume container as it will most certainly cause data corruption because they will all try to write to the same database files as the same time, which is not good (unless you're running RAC). 

Have fun and please post any issues in the issues section. 
