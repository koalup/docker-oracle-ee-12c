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

By default, the instance memory footprint (memory_target) is configured to be 1024m. You can override that by specyfying the `totalMemory` build-arg. For example:
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

Have fun and please post any issues in the issues section. 
