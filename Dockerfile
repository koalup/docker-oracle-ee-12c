FROM oraclelinux
MAINTAINER Steven Kolev <steven.kolev@gmail.com>

RUN yum -y update && yum -y install oracle-rdbms-server-12cR1-preinstall unzip

RUN sed -i 's/^oracle.*hard.*memlock/# oracle   hard   memlock/' /etc/security/limits.d/oracle*

COPY *.zip /tmp/

RUN cd /tmp && for f in *.zip; do unzip $f; done

RUN mkdir /u01 && chown oracle:oinstall /u01

RUN su - oracle -c '/tmp/database/runInstaller -silent -ignoreSysPrereqs -ignorePrereq -waitforcompletion \
INVENTORY_LOCATION=/u01/app/oraInventory \
ORACLE_BASE=/u01/app/oracle \
ORACLE_HOME=/u01/app/oracle/product/12.1.0.2/dbhome_1 \
SELECTED_LANGUAGES=en \
oracle.install.option=INSTALL_DB_SWONLY \
UNIX_GROUP_NAME=oinstall \
oracle.install.db.InstallEdition=EE \
oracle.install.db.EEOptionsSelection=false \
oracle.install.db.DBA_GROUP=dba \
oracle.install.db.OPER_GROUP=dba \
oracle.install.db.BACKUPDBA_GROUP=dba \
oracle.install.db.DGDBA_GROUP=dba \
oracle.install.db.KMDBA_GROUP=dba \
oracle.install.db.isRACOneInstall=false \
SECURITY_UPDATES_VIA_MYORACLESUPPORT=false \
DECLINE_SECURITY_UPDATES=true \
oracle.installer.autoupdates.option=SKIP_UPDATES' && /u01/app/oraInventory/orainstRoot.sh && /u01/app/oracle/product/12.1.0.2/dbhome_1/root.sh

RUN rm /tmp/*.zip && rm -rf /tmp/database

# set -e is required because without it dbca leaves defunct processes behind every time it restarts the instace, which causes dbca to fail.
# see https://blog.phusion.nl/2015/01/20/docker-and-the-pid-1-zombie-reaping-problem/ for details

RUN ["/bin/bash","-c","set -e && su - oracle -c '/u01/app/oracle/product/12.1.0.2/dbhome_1/bin/dbca -silent -createDatabase -templateName General_Purpose.dbc -gdbName ORCL -sid ORCL -createAsContainerDatabase true -numberOfPdbs 1 -pdbName DOCKER -pdbadminUsername docker -pdbadminPassword docker -SysPassword docker -SystemPassword docker -emConfiguration NONE -recoveryAreaDestination /u01/app/oracle/fast_recovery_area -storageType FS -characterSet AL32UTF8 -automaticMemoryManagement true -totalMemory 1024 -initParams db_create_file_dest=/u01/app/oracle/oradata,db_create_online_log_dest_1=/u01/app/oracle/oradata,db_create_online_log_dest_2=/u01/app/oracle/fast_recovery_area,db_recovery_file_dest_size=8589934592'"]

EXPOSE 1521

CMD ["/bin/bash","-c","set -e && su - oracle -c 'export ORAENV_ASK=NO; export ORACLE_SID=ORCL; . /usr/local/bin/oraenv; $ORACLE_HOME/bin/lsnrctl start; mv /u01/app/oracle/diag/rdbms/orcl/ORCL/trace/alert_ORCL.log /u01/app/oracle/diag/rdbms/orcl/ORCL/trace/alert_ORCL.log.$(date +%Y%m%d%H%M%S); echo startup | $ORACLE_HOME/bin/sqlplus -s / as sysdba; echo alter pluggable database all open\\; | $ORACLE_HOME/bin/sqlplus -s / as sysdba; /bin/tail -10000f /u01/app/oracle/diag/rdbms/orcl/ORCL/trace/alert_ORCL.log;'"]

