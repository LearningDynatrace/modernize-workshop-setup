#!/bin/bash
## Commands for Ubuntu Server 18.04 LTS
## These script will install the following components:
# - Chromium for the Load generation of the EasyTravel Angular Shop 
# - Java default-jre
# - EasyTravel, Legacy 8080,8079 / Angular 9080 and 80 / WebLauncher 8094 / EasyTravel REST 8091 1697
# - nginx proxy Docker image that is setup & run to redirect to expose and map port 80 to 9080 

if ! [ $(id -u) = 0 ]; then
   echo "ERROR: script must be run as root or with sudo"
   exit 1
fi

echo "*** Starting EZ Travel Install ***"

LOGFILE='/tmp/installEZtravel.log' 
UNIX_USER_HOME_PATH=/home/workshop
mkdir -p $UNIX_USER_HOME_PATH

echo "*** Create EZ Travel Install Logfile: $LOGFILE ***"
printf "\n\n***** Init Installation ***\n" >> $LOGFILE 2>&1 
{ date ; apt update; whoami ; } >> $LOGFILE ; chmod 777 $LOGFILE

echo "*** Add ProTip alias ***"
printf "\n\n***** ProTip Alias***\n" >> $LOGFILE 2>&1 
echo "
# Alias for ease of use of the CLI
alias hg='history | grep' 
alias h='history' 
alias vaml='vi -c \"set syntax:yaml\" -' 
alias vson='vi -c \"set syntax:json\" -' 
alias pg='ps -aux | grep' " > /root/.bash_aliases

echo "*** Copy Aliases ***"
cp /root/.bash_aliases $UNIX_USER_HOME_PATH/.bash_aliases

echo "*** Installation of Chromium on the system ***"
printf "\n\n***** Installation of Chromium on the system ***\n" >> $LOGFILE 2>&1 
apt install chromium-browser -y >>  $LOGFILE 2>&1

echo "*** Add NGINX ReverseProxy for AngularShop ***"
# mapping 9080 to 80 avoid problems on student browsers that 
# can hit non-standard ports
printf "\n\n***** Configuring reverse proxy***\n" >> $LOGFILE 2>&1 
export PUBLIC_IP=`hostname -i | awk '{ print $1'}`
mkdir -p $UNIX_USER_HOME_PATH/nginx/classic
mkdir -p $UNIX_USER_HOME_PATH/nginx/angular

echo "upstream classic {
  server        $PUBLIC_IP:8079;
}
server {
  listen                0.0.0.0:80;
  server_name   localhost;
  location / {
    proxy_pass  http://classic;
    }
}" > $UNIX_USER_HOME_PATH/nginx/classic/classic.conf
echo "upstream angular {
  server        $PUBLIC_IP:9079;
}
server {
  listen                0.0.0.0:80;
  server_name   localhost;
  location / {
    proxy_pass  http://angular;
    }
}" > $UNIX_USER_HOME_PATH/nginx/angular/angular.conf

echo "*** Install default-jre ***"
printf "\n\n***** JavaRuntime  install ***\n" >> $LOGFILE 2>&1 
apt install -y openjdk-11-jdk >> $LOGFILE 2>&1

echo "*** Download EasyTravel ***"
printf "\n\n***** Download, install and configure EasyTravel ***\n" >> $LOGFILE 2>&1 
{ cd $UNIX_USER_HOME_PATH ;\
 wget -O dynatrace-easytravel-linux-x86_64.jar https://etinstallers.demoability.dynatracelabs.com/latest/dynatrace-easytravel-linux-x86_64.jar ;\
 java -jar dynatrace-easytravel-linux-x86_64.jar -y ;\
 chmod 755 -R easytravel-2.0.0-x64 ; }  >> $LOGFILE 2>&1  

echo "*** Adjust permissions for workshop user ***"
printf "\n\n***** Adjust permissions for workshop user ***\n" >> $LOGFILE 2>&1 
usermod -a -G docker workshop >> $LOGFILE 2>&1
usermod -a -G sudo workshop >> $LOGFILE 2>&1
chown workshop:workshop -R easytravel-2.0.0-x64 >> $LOGFILE 2>&1 

echo "*** Configuring EasyTravel Settings ***"
sed -i 's/apmServerDefault=Classic/apmServerDefault=APM/g' $UNIX_USER_HOME_PATH/easytravel-2.0.0-x64/resources/easyTravelConfig.properties
sed -i 's/config.frontendJavaopts=-Xmx160m/config.frontendJavaopts=-Xmx320m/g' $UNIX_USER_HOME_PATH/easytravel-2.0.0-x64/resources/easyTravelConfig.properties
sed -i 's/config.backendJavaopts=-Xmx64m/config.backendJavaopts=-Xmx320m/g' $UNIX_USER_HOME_PATH/easytravel-2.0.0-x64/resources/easyTravelConfig.properties
sed -i 's/config.autostart=/config.autostart=Standard with REST Service and Angular2 frontend/g' $UNIX_USER_HOME_PATH/easytravel-2.0.0-x64/resources/easyTravelConfig.properties
sed -i 's/config.autostartGroup=/config.autostartGroup=UEM/g' $UNIX_USER_HOME_PATH/easytravel-2.0.0-x64/resources/easyTravelConfig.properties

sed -i 's/config.baseLoadDefault=20/config.baseLoadDefault=30/g' $UNIX_USER_HOME_PATH/easytravel-2.0.0-x64/resources/easyTravelConfig.properties
sed -i 's/config.baseLoadB2BRatio=0.1/config.baseLoadB2BRatio=0/g' $UNIX_USER_HOME_PATH/easytravel-2.0.0-x64/resources/easyTravelConfig.properties
#sed -i 's/config.baseLoadCustomerRatio=0.25/config.baseLoadCustomerRatio=0.15/g' $UNIX_USER_HOME_PATH/easytravel-2.0.0-x64/resources/easyTravelConfig.properties
#sed -i 's/config.baseLoadMobileNativeRatio=0.1/config.baseLoadMobileNativeRatio=0/g' $UNIX_USER_HOME_PATH/easytravel-2.0.0-x64/resources/easyTravelConfig.properties
#sed -i 's/config.baseLoadMobileBrowserRatio=0.25/config.baseLoadMobileBrowserRatio=0.15/g' $UNIX_USER_HOME_PATH/easytravel-2.0.0-x64/resources/easyTravelConfig.properties
sed -i 's/config.baseLoadHotDealServiceRatio=0.25/config.baseLoadHotDealServiceRatio=0/g' $UNIX_USER_HOME_PATH/easytravel-2.0.0-x64/resources/easyTravelConfig.properties
sed -i 's/config.baseLoadIotDevicesRatio=0.1/config.baseLoadIotDevicesRatio=0/g' $UNIX_USER_HOME_PATH/easytravel-2.0.0-x64/resources/easyTravelConfig.properties
sed -i 's/config.baseLoadHeadlessAngularRatio=0.0/config.baseLoadHeadlessAngularRatio=0.15/g' $UNIX_USER_HOME_PATH/easytravel-2.0.0-x64/resources/easyTravelConfig.properties
sed -i 's/config.baseLoadHeadlessMobileAngularRatio=0.0/config.baseLoadHeadlessMobileAngularRatio=0.15/g' $UNIX_USER_HOME_PATH/easytravel-2.0.0-x64/resources/easyTravelConfig.properties

sed -i 's/config.maximumChromeDrivers=10/config.maximumChromeDrivers=3/g' $UNIX_USER_HOME_PATH/easytravel-2.0.0-x64/resources/easyTravelConfig.properties
sed -i 's/config.maximumChromeDriversMobile=10/config.maximumChromeDriversMobile=3/g' $UNIX_USER_HOME_PATH/easytravel-2.0.0-x64/resources/easyTravelConfig.properties
sed -i 's/config.reUseChromeDriverFrequency=4/config.reUseChromeDriverFrequency=3/g' $UNIX_USER_HOME_PATH/easytravel-2.0.0-x64/resources/easyTravelConfig.properties
#sed -i 's/config.angularFrontendPortRangeStart=9080/config.angularFrontendPortRangeStart=80/g' /easytravel-2.0.0-x64/resources/easyTravelConfig.properties

MY_PUBLIC_IP=$(curl -s  http://checkip.amazonaws.com) && echo "MY PUBLIC IP = $MY_PUBLIC_IP"
sudo sed -i 's/config.thirdpartyUrl=http:\/\/${config.thirdpartyHost}:${config.thirdpartyPort}\//config.thirdpartyUrl=http:\/\/'"$MY_PUBLIC_IP"':${config.thirdpartyPort}\//g' $UNIX_USER_HOME_PATH/easytravel-2.0.0-x64/resources/easyTravelConfig.properties

echo "*** Fix finding the Java package path ***"
sed -i "s/JAVA_BIN=..\\/jre\\/bin\\/java/JAVA_BIN=\\/usr\\/bin\\/java/g" $UNIX_USER_HOME_PATH/easytravel-2.0.0-x64/weblauncher/weblauncher.sh

{ date ; echo "installation done" ;} >> $LOGFILE 2>&1

echo "*** EZ Travel Install Done."
echo "View log with: tail -f $LOGFILE"

sudo $UNIX_USER_HOME_PATH/modernize-workshop-setup/startEZtravelMonolith.sh
