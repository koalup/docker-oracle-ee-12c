FROM oraclelinux
MAINTAINER Steven Kolev <steven.kolev@gmail.com>

EXPOSE 1521
EXPOSE 5500
EXPOSE 5501

ARG totalMemory=1024
ARG characterSet=AL32UTF8
ARG db_recovery_file_dest_size=8589934592
ARG log_mode=noarchivelog
ARG flashback_on=no
ARG force_logging=no

# Package oracle-rdbms-server-12cR1-preinstall creates /etc/security/limits.d/oracle. 
# Have to comment out oracle hard memlock because it prevents su'ing to oracle.

RUN 	yum -y update && \
	yum -y install oracle-rdbms-server-12cR1-preinstall unzip && \
	sed -i 's/^oracle.*hard.*memlock/# oracle   hard   memlock/' /etc/security/limits.d/oracle*

COPY 	*.zip /tmp/

RUN 	cd /tmp && \
	for f in *.zip; do unzip $f; done && \
	mkdir /u01 && \
	chown oracle:oinstall /u01 && \
	su - oracle -c ' \
		/tmp/database/runInstaller \
			-silent \
			-ignoreSysPrereqs \
			-ignorePrereq \
			-waitforcompletion \
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
			oracle.installer.autoupdates.option=SKIP_UPDATES \
		; \
	' && \
	/u01/app/oraInventory/orainstRoot.sh && \
	/u01/app/oracle/product/12.1.0.2/dbhome_1/root.sh && \
	rm /tmp/*.zip && \
	rm -rf /tmp/database

# set -e is required because without it dbca leaves defunct processes behind every time it restarts the instace, which causes dbca to fail.
# see https://blog.phusion.nl/2015/01/20/docker-and-the-pid-1-zombie-reaping-problem/ for details

RUN /bin/bash -c " \
	set -e && \
	su - oracle -c ' \
		/u01/app/oracle/product/12.1.0.2/dbhome_1/bin/dbca \
			-silent \
			-createDatabase \
			-templateName General_Purpose.dbc \
			-gdbName ORCL \
			-sid ORCL \
			-createAsContainerDatabase true \
			-numberOfPdbs 1 \
			-pdbName PDB1 \
			-pdbadminUsername docker \
			-pdbadminPassword docker \
			-SysPassword docker \
			-SystemPassword docker \
			-emConfiguration DBEXPRESS \
			-recoveryAreaDestination /u01/app/oracle/fast_recovery_area \
			-storageType FS \
			-characterSet ${characterSet} \
			-automaticMemoryManagement true \
			-totalMemory ${totalMemory} \
			-initParams db_create_file_dest=/u01/app/oracle/oradata \
			-initParams db_create_online_log_dest_1=/u01/app/oracle/oradata \
			-initParams db_create_online_log_dest_2=/u01/app/oracle/fast_recovery_area \
			-initParams db_recovery_file_dest_size=${db_recovery_file_dest_size} \
		&& \
		export ORAENV_ASK=NO && \
		export ORACLE_SID=ORCL && \
		. /usr/local/bin/oraenv && \
		/bin/echo -e \"alter session set container=PDB1; \n grant dba to docker container = current;\" | \$ORACLE_HOME/bin/sqlplus -s / as sysdba && \
		/bin/echo -e \"alter session set container=PDB1; \n exec dbms_xdb_config.sethttpsport(5501);\" | \$ORACLE_HOME/bin/sqlplus -s / as sysdba && \
		if [[ ${log_mode} = \"archivelog\" ]] || [[ ${flashback_on} = \"yes\" ]]; then \
			/bin/echo -e \"shutdown immediate\" | \$ORACLE_HOME/bin/sqlplus -s / as sysdba && \
			/bin/echo -e \"startup mount\" | \$ORACLE_HOME/bin/sqlplus -s / as sysdba && \
			/bin/echo -e \"setting log_mode to ${log_mode}\" && \
			/bin/echo -e \"whenever sqlerror exit 1 \n whenever oserror exit 1 \n alter database archivelog;\" | \$ORACLE_HOME/bin/sqlplus -s / as sysdba && \
			if [[ ${flashback_on} = \"yes\" ]]; then \
				/bin/echo -e \"setting flashback_on to ${flashback_on}\" && \
				/bin/echo -e \"whenever sqlerror exit 1 \n whenever oserror exit 1 \n alter database flashback on;\" | \$ORACLE_HOME/bin/sqlplus -s / as sysdba; \
			fi && \
			/bin/echo -e \"whenever sqlerror exit 1 \n whenever oserror exit 1 \n alter database open;\" | \$ORACLE_HOME/bin/sqlplus -s / as sysdba; \
		fi && \
		if [[ ${force_logging} = "yes" ]]; then \
			/bin/echo -e \"setting force_logging to ${force_logging}\" && \
			/bin/echo -e \"whenever sqlerror exit 1 \n whenever oserror exit 1 \n alter database force logging;\" | \$ORACLE_HOME/bin/sqlplus -s / as sysdba; \
		fi && \
		/bin/echo -e \"shutdown immediate\" | \$ORACLE_HOME/bin/sqlplus -s / as sysdba && \
		/bin/echo -e \"Finished Creating Database\"; \
	' \
" 

CMD /bin/bash -c " \
	set -e && \
	su - oracle -c ' \
		export ORAENV_ASK=NO && \
		export ORACLE_SID=ORCL && \
		. /usr/local/bin/oraenv && \
		\$ORACLE_HOME/bin/lsnrctl start && \
		mv /u01/app/oracle/diag/rdbms/orcl/ORCL/trace/alert_ORCL.log /u01/app/oracle/diag/rdbms/orcl/ORCL/trace/alert_ORCL.log.$(date +%Y%m%d%H%M%S) && \
		/bin/echo -e \"startup\" | \$ORACLE_HOME/bin/sqlplus -s / as sysdba && \
		/bin/echo -e \"alter pluggable database all open;\" | \$ORACLE_HOME/bin/sqlplus -s / as sysdba && \
		/bin/tail -10000f /u01/app/oracle/diag/rdbms/orcl/ORCL/trace/alert_ORCL.log && \
		/bin/echo -e \"Finished Docker Session\"; \
	' \
" 
