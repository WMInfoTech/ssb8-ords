#!/bin/bash

# Fail fast
set -e

PROPFILE="$ORDS_HOME/params/ords_params.properties"
touch $PROPFILE
if [ ! -f "$PROPFILE" ]; then
  echo "Unable to find properties file $PROPFILE"
  exit 1
fi

setProperty() {
  prop=$1
  val=$2

  if [ $(grep -c "$prop" "$PROPFILE") -eq 0 ]; then
    echo "${prop}=$val" >> "$PROPFILE"
  else
    val=$(echo "$val" |sed 's#/#\\/#g')
    sed -i "s/$prop=.*/$prop=$val/" "$PROPFILE"
  fi
}

setPropsFromFile() {
  file=$1
  for l in $(grep '=' "$file" | grep -v '^ *#'); do
    prop=$(echo "$l" |cut -d= -f1)
    val=$(echo "$l" |cut -d= -f2)
    setProperty "$prop" "$val"
  done
}

setPropFromEnvPointingToFile() {
  prop=$1
  val=$2
  [ -z "$val" ] && return
  # If the value is a file, use the contents of that file as the new value
  if [ -f "$val" ]; then
    val=$(cat "$val")
    setProperty "$prop" "$val"
  else
    # If it's not a file, use the value of the variable as the password
    setProperty "$prop" "$val"
  fi
}

if [ -f "$CONFIG_FILE" ]; then
    setPropsFromFile "$CONFIG_FILE"
fi

setPropFromEnv() {
  prop=$1
  val=$2
  # If no value was given, abort
  [ -z "$val" ] && return
  if [ $(grep -c "$prop" $PROPFILE) -eq 0 ]; then
    setProperty "$prop" "$val"
  fi
}

if [ -z "$CONFIG_FILE" ]; then
  setPropFromEnv db.username "$DB_USERNAME"
  setPropFromEnvPointingToFile db.password "$DB_PASSWORD"
  setPropFromEnv db.hostname "$DB_HOSTNAME"
  setPropFromEnv db.port "$DB_PORT"
  setPropFromEnv db.servicename "$DB_SID"
  setProperty plsql.gateway.add "true"
  setProperty rest.services.apex.add "false"
  setProperty rest.services.ords.add "false"
  setProperty standalone.mode "false"
fi

if [ -n "$JMX_PORT" ]; then
  export CATALINA_OPTS="$CATALINA_OPTS -Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.port=$JMX_PORT -Dcom.sun.management.jmxremote.ssl=false -Dcom.sun.management.jmxremote.authenticate=false"
fi

if [ ! -f $ORDS_HOME/config/ords/standalone/standalone.properties ]; then
  cd $ORDS_HOME
  java -jar ords.war configdir $ORDS_HOME/config
  java -jar ords.war

  cp -arv $ORDS_HOME/config/ords $ORDS_HOME/config/$URI_PATH
fi;

cp $ORDS_HOME/ords.war /usr/local/tomcat/webapps/$URI_PATH.war

java -jar ords.war set-property jdbc.MaxLimit $DB_MAXTOTAL
java -jar ords.war set-property jdbc.MinLimit $DB_INITIALSIZE
java -jar ords.war set-property jdbc.InitialLimit $DB_INITIALSIZE

java -jar ords.war set-property db.sid $DB_SID
java -jar ords.war set-property db.port $DB_PORT
java -jar ords.war set-property db.hostname $DB_HOSTNAME

java -jar ords.war set-property misc.defaultPage $DEFAULT_PAGE

if [ ! -v $ORDS_DEBUG ]; then
  java -jar ords.war set-property debug.debugger true
  java -jar ords.war set-property debug.printDebugToScreen true
fi

cp $ORDS_HOME/config/ords/defaults.xml $ORDS_HOME/config/$URI_PATH/defaults.xml
cd /usr/local/tomcat/webapps

for war in /usr/local/tomcat/webapps/*.war; do
  mkdir $(basename "$war" .war)
  unzip -d $(basename "$war" .war) "$war"
  rm "$war"
done

cp -r /opt/static/js /usr/local/tomcat/webapps/js
cp -r /opt/static/css /usr/local/tomcat/webapps/css
cp -r /opt/static /usr/local/tomcat/webapps/${URI_PATH}_static

exec catalina.sh run
