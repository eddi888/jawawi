#!/usr/bin/env bash

#
# execute inside cloned nuclos from bitbucket
# git clone https://bitbucket.org/nuclos/nuclos.git
# cd nuclos
# {jawawi}/scripts/nuclos-integration-test.sh

export NUCLOS_PORT=8080
export WEBCLIENT_PORT=9090
export TOMCAT_AJP_PORT=8005
export CARGO_RMI_PORT=8999

echo "maven.home.dir=$MAVEN_HOME" > build.properties
echo "launch4j.home.dir=/opt/launch4j/" >> build.properties
echo "3rdparty.dir=/var/3rdparty/" >> build.properties
echo 'maven.settings=${user.home}/.m2/settings.xml' >> build.properties

CONF_DIR=`pwd`/conf
if ! [ -d "$CONF_DIR" ]; then mkdir "$CONF_DIR"; fi

DATA_DIR=`pwd`/data
if ! [ -d "$DATA_DIR" ]; then mkdir "$DATA_DIR"; fi

LOG_DIR=`pwd`/logs
if ! [ -d "$LOG_DIR" ]; then mkdir "$LOG_DIR"; fi

WEBAPP_DIR=`pwd`/webapp
if ! [ -d "$WEBAPP_DIR" ]; then mkdir "$WEBAPP_DIR"; fi

# server.properties
cat > "$CONF_DIR/server.properties" <<- EOF
	client.getdown=false
	client.singleinstance=false
	client.webclient=true
	cluster.mode=false
	database.adapter=h2
	database.autosetup=true
	database.home=$DATA_DIR/db
	database.schema=nuclos
	database.tablespace=
	database.tablespace.index=
	environment.development=true
	environment.production=false
	jasper.reports.compile.keep.java.file=false
	jasper.reports.compile.temp=$DATA_DIR/compiled-reports
	nuclos.codegenerator.output.path=$DATA_DIR/codegenerator
	nuclos.data.database-structure-changes.path=$LOG_DIR/database-structure-changes
	nuclos.data.documents.path=$DATA_DIR/documents
	nuclos.data.expimp.path=$DATA_DIR/expimp
	nuclos.data.resource.path=$DATA_DIR/resource
	nuclos.index.path=$DATA_DIR/index
	nuclos.wsdl.generator.lib.path=$WEBAPP_DIR/WEB-INF/axislibs
	nuclos.wsdl.generator.output.path=$DATA_DIR/codegenerator/wsdl
	package-properties.conf.path=$CONF_DIR/package-properties
EOF

# client.properties
cat > "$CONF_DIR/client.properties" <<- EOF
	java.util.prefs.PreferencesFactory=org.nuclos.common.preferences.NuclosPreferencesFactory
	jnlp.concurrentDownloads=2
	jnlp.packEnabled=true
	nuclos.client.singleinstance=false
EOF

# jdbc.properties
cat > "$CONF_DIR/jdbc.properties" <<- EOF
	driverClassName=org.h2.Driver
	jdbcUrl=jdbc\:h2\:file
	password=nuclos
	username=nuclos
EOF

# log4j2.xml
cat > "$CONF_DIR/log4j2.xml" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<Configuration>
  <Appenders>
    <Console name="Console" target="SYSTEM_OUT">
      <PatternLayout pattern="%d %p [%c] - %m%n"/>
    </Console>
    <RollingFile name="Logfile" fileName="$LOG_DIR/server.log"
    		filePattern="$LOG_DIR/server-%i.log" 
    		append="true">
      <PatternLayout pattern="%d %p [%c] - %m%n"/>
      <Policies>
    	<SizeBasedTriggeringPolicy size="5 MB"/>
  		</Policies>
  	  <DefaultRolloverStrategy max="20"/>
    </RollingFile>
  </Appenders>
  <Loggers>
    <Logger name="org.apache.log4j.xml" level="info"/>
	<Logger name="SQLLogger" level="debug"/>
    <Root level="info">
      <AppenderRef ref="Console"/>
      <AppenderRef ref="Logfile"/>
    </Root>
  </Loggers>
</Configuration>
EOF

# quartz.properties
cat > "$CONF_DIR/quartz.properties" <<- EOF
	org.quartz.jobStore.class=org.quartz.simpl.RAMJobStore
	org.quartz.scheduler.instanceName=NuclosQuartzScheduler
	org.quartz.scheduler.rmi.export=false
	org.quartz.scheduler.rmi.proxy=false
	org.quartz.scheduler.xaTransacted=false
	org.quartz.threadPool.class=org.quartz.simpl.SimpleThreadPool
	org.quartz.threadPool.threadCount=10
	org.quartz.threadPool.threadPriority=5
EOF


METAINF_DIR=`pwd`/nuclos-war/src/main/webapp/META-INF

# context.xml
cat > "$METAINF_DIR/context.xml" <<- EOF
<?xml version="1.0" encoding="UTF-8"?>
<Context antiJARLocking="true" path="/nuclos-war" reloadable="false">
	<Loader loaderClass="org.springframework.instrument.classloading.tomcat.TomcatInstrumentableClassLoader" />

	<Environment name="nuclos-conf-log4j" type="java.lang.String"
		value="file://$CONF_DIR/log4j2.xml" />
	<Environment name="nuclos-conf-jdbc" type="java.lang.String"
		value="file://$CONF_DIR/jdbc.properties" />
	<Environment name="nuclos-conf-quartz" type="java.lang.String"
		value="file://$CONF_DIR/quartz.properties" />
	<Environment name="nuclos-conf-server" type="java.lang.String"
		value="file://$CONF_DIR/server.properties" />
</Context>
EOF

 

# delete old DB
rm -rf $DATA_DIR/db/*

# delete old INDEX
rm -rf $DATA_DIR/index

# delete old failure screenshot
find ./*/target/* -iname '*failure.png' -exec rm {} \; | true


#
# execute typescript compilation
#
pushd nuclos-webclient
npm install
grunt ts --force
popd


#
# execute Maven
#
set -x
  
mvn -Ptest                                              \
clean                                                   \
verify                                                  \
-Dselenium.server=http://127.0.0.1:4444/wd/hub          \
-Dbrowser=firefox                                       \
-Dlocale=de_DE                                          \
-Dnuclos.server.protocol=http                           \
-Dnuclos.server.host=127.0.0.1                          \
-Dnuclos.server.port=${NUCLOS_PORT}                     \
-Dnuclos.webclient.protocol=http                        \
-Dnuclos.webclient.host=127.0.0.1                       \
-Dnuclos.webclient.port=${WEBCLIENT_PORT}               \
-Dcargo.container.tomcat.ajp.port=${TOMCAT_AJP_PORT}    \
-Dcargo.container.rmi.port=${CARGO_RMI_PORT}





