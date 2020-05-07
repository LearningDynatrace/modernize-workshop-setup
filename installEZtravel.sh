#!/bin/bash
## Commands for Ubuntu Server 18.04 LTS (HVM), SSD Volume Type - ami-06d51e91cea0dac8d
## These script will install the following components:
# - OneAgent
# - Docker
# - BankJobs shinojosa/bankjob:v0.2 from DockerHub
# - Chromium for the Load generation of the EasyTravel Angular Shop 
# - EasyTravel, Legacy 8080,8079 / Angular 9080 and 80 / WebLauncher 8094 / EasyTravel REST 8091 1697

if [ "$#" -ne 1 ]; then
  echo "Missing UNIX_USER_HOME_PATH argument. Example: ./installEZtravel.sh /home/workshop" >&2
  exit 1
fi
UNIX_USER_HOME_PATH=$1

## Set TENANT and API TOKEN
DT_BASEURL=$(cat creds.json | jq -r '.DT_BASEURL')
DT_PAAS_TOKEN=$(cat creds.json | jq -r '.DT_PAAS_TOKEN')
LOGFILE='/tmp/installEZtravel.txt'

##Create installer Logfile
printf "\n\n***** Init Installation ***\n" >> $LOGFILE 2>&1 
{ date ; apt update; whoami ; echo Setting up ec2 for tenant: $DT_BASEURL with Api-Token: $DT_PAAS_TOKEN ; } >> $LOGFILE ; chmod 777 $LOGFILE


printf "\n\n***** add DTU training user ***\n" >> $LOGFILE 2>&1 
# Create user Dynatrace, we specify bash login, home directory, password and add him to the sudoers
useradd -s /bin/bash -d $UNIX_USER_HOME_PATH/ -m -G sudo -p $(openssl passwd -1 @perform2020) dtu.training

## Update and install docker
printf "\n\n***** Update and install docker***\n" >> $LOGFILE 2>&1 
{ apt install docker.io -y ;\
 service docker start ;\
 usermod -a -G docker dtu.training ;} >> $LOGFILE 2>&1

# Add ProTip alias
printf "\n\n***** ProTip Alias***\n" >> $LOGFILE 2>&1 
echo "
# Alias for ease of use of the CLI
alias hg='history | grep' 
alias h='history' 
alias vaml='vi -c \"set syntax:yaml\" -' 
alias vson='vi -c \"set syntax:json\" -' 
alias pg='ps -aux | grep' " > /root/.bash_aliases

# Copy Aliases
cp /root/.bash_aliases $UNIX_USER_HOME_PATH/.bash_aliases

## Installation of Chromium on the system
printf "\n\n***** Installation of Chromium on the system ***\n" >> $LOGFILE 2>&1 
apt install chromium-browser -y >>  $LOGFILE 2>&1

## Installation of OneAgent
printf "\n\n***** Installation of the OneAgent***\n" >> $LOGFILE 2>&1 
{ wget -nv -O oneagent.sh "$DT_BASEURL/api/v1/deployment/installer/agent/unix/default/latest?Api-Token=$DT_PAAS_TOKEN&arch=x86&flavor=default" ;\
 sh oneagent.sh APP_LOG_CONTENT_ACCESS=1 INFRA_ONLY=0 ;}  >> $LOGFILE 2>&1 

## Get Bankjobs and run them
#printf "\n\n***** Pulling Bankjobs and running them***\n" >> $LOGFILE 2>&1 
#docker run -d --name bankjob shinojosa/bankjob:perform2020 >> $LOGFILE 2>&1

# NGINX ReverseProxy for AngularShop mapping 9080 to 80 avoid problems for other ports.
printf "\n\n***** Configuring reverse proxy***\n" >> $LOGFILE 2>&1 
export PUBLIC_IP=`hostname -i | awk '{ print $1'}`
mkdir $UNIX_USER_HOME_PATH/nginx
echo "upstream angular {
  server	$PUBLIC_IP:9080;
} 
server {
  listen		0.0.0.0:80;
  server_name	localhost;
  location / {
    proxy_pass	http://angular;
    }
}" > $UNIX_USER_HOME_PATH/nginx/angular.conf
docker run -p 80:80 -v $UNIX_USER_HOME_PATH/nginx:/etc/nginx/conf.d/:ro -d --name reverseproxy nginx:1.15

# Install  default-jre
printf "\n\n***** JavaRuntime  install ***\n" >> $LOGFILE 2>&1 
apt install -y openjdk-8-jre-headless >> $LOGFILE 2>&1

# EasyTravel Angular
printf "\n\n***** Download, install and configure EasyTravel***\n" >> $LOGFILE 2>&1 
# Install Easytravel with Angular shop
{ cd $UNIX_USER_HOME_PATH ;\
 wget -nv -O dynatrace-easytravel-linux-x86_64.jar http://dexya6d9gs5s.cloudfront.net/latest/dynatrace-easytravel-linux-x86_64.jar ;\
 java -jar dynatrace-easytravel-linux-x86_64.jar -y ;\
 chmod 755 -R  easytravel-2.0.0-x64 ;\
 chown dtu.training:dtu.training -R easytravel-2.0.0-x64 ; }  >> $LOGFILE 2>&1 

# Configuring EasyTravel Memory Settings, Angular Shop and Weblauncher. 
sed -i 's/apmServerDefault=Classic/apmServerDefault=APM/g' $UNIX_USER_HOME_PATH/easytravel-2.0.0-x64/resources/easyTravelConfig.properties
sed -i 's/config.frontendJavaopts=-Xmx160m/config.frontendJavaopts=-Xmx320m/g' $UNIX_USER_HOME_PATH/easytravel-2.0.0-x64/resources/easyTravelConfig.properties
sed -i 's/config.backendJavaopts=-Xmx64m/config.backendJavaopts=-Xmx320m/g' $UNIX_USER_HOME_PATH/easytravel-2.0.0-x64/resources/easyTravelConfig.properties
sed -i 's/config.autostart=/config.autostart=Standard with REST Service and Angular2 frontend/g' $UNIX_USER_HOME_PATH/easytravel-2.0.0-x64/resources/easyTravelConfig.properties
sed -i 's/config.autostartGroup=/config.autostartGroup=UEM/g' $UNIX_USER_HOME_PATH/easytravel-2.0.0-x64/resources/easyTravelConfig.properties
sed -i 's/config.baseLoadB2BRatio=0.1/config.baseLoadB2BRatio=0/g' $UNIX_USER_HOME_PATH/easytravel-2.0.0-x64/resources/easyTravelConfig.properties
sed -i 's/config.baseLoadCustomerRatio=0.25/config.baseLoadCustomerRatio=0.1/g' $UNIX_USER_HOME_PATH/easytravel-2.0.0-x64/resources/easyTravelConfig.properties
sed -i 's/config.baseLoadMobileNativeRatio=0.1/config.baseLoadMobileNativeRatio=0/g' $UNIX_USER_HOME_PATH/easytravel-2.0.0-x64/resources/easyTravelConfig.properties
sed -i 's/config.baseLoadMobileBrowserRatio=0.25/config.baseLoadMobileBrowserRatio=0/g' $UNIX_USER_HOME_PATH/easytravel-2.0.0-x64/resources/easyTravelConfig.properties
sed -i 's/config.baseLoadHotDealServiceRatio=0.25/config.baseLoadHotDealServiceRatio=1/g' $UNIX_USER_HOME_PATH/easytravel-2.0.0-x64/resources/easyTravelConfig.properties
sed -i 's/config.baseLoadIotDevicesRatio=0.1/config.baseLoadIotDevicesRatio=0/g' $UNIX_USER_HOME_PATH/easytravel-2.0.0-x64/resources/easyTravelConfig.properties
sed -i 's/config.baseLoadHeadlessAngularRatio=0.0/config.baseLoadHeadlessAngularRatio=0.25/g' $UNIX_USER_HOME_PATH/easytravel-2.0.0-x64/resources/easyTravelConfig.properties
sed -i 's/config.baseLoadHeadlessMobileAngularRatio=0.0/config.baseLoadHeadlessMobileAngularRatio=0.1/g' $UNIX_USER_HOME_PATH/easytravel-2.0.0-x64/resources/easyTravelConfig.properties
sed -i 's/config.maximumChromeDrivers=10/config.maximumChromeDrivers=3/g' $UNIX_USER_HOME_PATH/easytravel-2.0.0-x64/resources/easyTravelConfig.properties
sed -i 's/config.maximumChromeDriversMobile=10/config.maximumChromeDriversMobile=3/g' $UNIX_USER_HOME_PATH/easytravel-2.0.0-x64/resources/easyTravelConfig.properties
sed -i 's/config.reUseChromeDriverFrequency=4/config.reUseChromeDriverFrequency=3/g' $UNIX_USER_HOME_PATH/easytravel-2.0.0-x64/resources/easyTravelConfig.properties
#sed -i 's/config.angularFrontendPortRangeStart=9080/config.angularFrontendPortRangeStart=80/g' /easytravel-2.0.0-x64/resources/easyTravelConfig.properties

# Fix finding the Java package
sed -i "s/JAVA_BIN=..\\/jre\\/bin\\/java/JAVA_BIN=\\/usr\\/bin\\/java/g" $UNIX_USER_HOME_PATH/easytravel-2.0.0-x64/weblauncher/weblauncher.sh

su -c "sh $UNIX_USER_HOME_PATH/easytravel-2.0.0-x64/weblauncher/weblauncher.sh > /tmp/weblauncher.log 2>&1 &" dtu.training 

# su -c 'nohup $UNIX_USER_HOME_PATH/easytravel-2.0.0-x64/runEasyTravelNoGUI.sh --startgroup UEM --startscenario "Standard with REST Service and Angular2 frontend" &' - ubuntu
# su -c 'nohup /home/ubuntu/easyTravel/easytravel-2.0.0-x64/runEasyTravelNoGUI.sh --startgroup UEM --startscenario "Standard with REST Service and Angular2 frontend" &' - ubuntu

{ [[ -f  /tmp/weblauncher.log ]] && echo "***EasyTravel launched**" || echo "***Problem launching EasyTravel **" ; } >> $LOGFILE 2>&1
{ date ; echo "installation done" ;} >> $LOGFILE 2>&1 

# Allow unencrypted password via SSH for login
sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config

# Restart ssh service
service sshd restart