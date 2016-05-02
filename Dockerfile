FROM oraclelinux
MAINTAINER Steven Kolev <steven.kolev@gmail.com>

EXPOSE 1521 5500

ARG gdbName=orcl
ARG sid=orcl
ARG characterSet=AL32UTF8

ENV gdbName=${gdbName} sid=${sid} http_proxy=${http_proxy:-""} https_proxy=${https_proxy:-""} no_proxy=${no_proxy:-""}

# Package oracle-rdbms-server-12cR1-preinstall creates /etc/security/limits.d/oracle. 
# Have to comment out oracle hard memlock because it prevents su'ing to oracle.

RUN 	yum -y update && \
	yum -y install oracle-rdbms-server-12cR1-preinstall unzip && \
	yum clean all && \
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
	su oracle -c ' \
		gdb=$(echo ${gdbName} | awk -F. '{str=sub($1,toupper($1),$0); print $0}') && \
		udb=$(echo ${gdbName} | awk -F. '{print tolower($1)}') && \
		sid=${sid} && \
		/bin/echo -e gdb=\${gdb} && \
		/bin/echo -e udb=\${udb} && \
		/bin/echo -e sid=\${sid} && \
		/u01/app/oracle/product/12.1.0.2/dbhome_1/bin/dbca \
			-silent \
			-createDatabase \
			-templateName General_Purpose.dbc \
			-gdbName \${gdb} \
			-sid \${sid} \
			-createAsContainerDatabase true \
			-SysPassword sys \
			-SystemPassword system \
			-emConfiguration DBEXPRESS \
			-recoveryAreaDestination /u01/app/oracle/fast_recovery_area \
			-storageType FS \
			-characterSet ${characterSet} \
			-automaticMemoryManagement true \
			-totalMemory 1024 \
			-initParams db_create_file_dest=/u01/app/oracle/oradata \
			-initParams db_create_online_log_dest_1=/u01/app/oracle/oradata \
			-initParams db_create_online_log_dest_2=/u01/app/oracle/fast_recovery_area \
			-initParams db_recovery_file_dest_size=4096 \
			-initParams control_files='' \
		&& \
		export ORAENV_ASK=NO && \
		export ORACLE_SID=\${sid} && \
		. /usr/local/bin/oraenv && \
		/bin/echo -e \"shutdown immediate\" | \$ORACLE_HOME/bin/sqlplus -s / as sysdba && \
		/bin/echo -e \"finished creating database\"; \
	' \
" 

CMD /bin/bash -c " \
	set -e && \
	su - oracle -c ' \
		gdb=$(echo ${gdbName} | awk -F. '{str=sub($1,toupper($1),$0); print $0}') && \
		udb=$(echo ${gdbName} | awk -F. '{print tolower($1)}') && \
		sid=${sid} && \
		export ORAENV_ASK=NO && \
		export ORACLE_SID=\${sid} && \
		. /usr/local/bin/oraenv && \
		\$ORACLE_HOME/bin/lsnrctl start && \
		mv /u01/app/oracle/diag/rdbms/\${udb}/\${sid}/trace/alert_\${sid}.log /u01/app/oracle/diag/rdbms/\${udb}/\${sid}/trace/alert_\${sid}.log.$(date +%Y%m%d%H%M%S) && \
		/bin/echo -e \"startup\" | \$ORACLE_HOME/bin/sqlplus -s / as sysdba && \
		/bin/echo -e \"alter pluggable database all open;\" | \$ORACLE_HOME/bin/sqlplus -s / as sysdba && \
		/bin/tail -10000f /u01/app/oracle/diag/rdbms/\${udb}/\${sid}/trace/alert_\${sid}.log && \
		/bin/echo -e \"Finished Docker Session\"; \
	' \
" 
