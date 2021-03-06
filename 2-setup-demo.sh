#!/bin/bash
RESET="\e[0m"
BOLD="\e[4m"
INPUT="\e[7m"
YELLOW="\033[38;5;11m"
RED="\033[0;31m"
echo -e "${BOLD}Welcome to the OSS Demo for Simple app dev Containers.  This demo will configure:${RESET}"
echo "    - Resource group - ossdemo-appdev-iaas"
echo "    - Resource group - ossdemo-appdev-acs"
echo "    - Resource group - ossdemo-appdev-paas"
echo "    - Create a private Azure Container Registry - used across all demos"
echo "    - Create an application insights instance - used across all demos"
echo "    - Optionally create an OMS instance - used across all demos"
echo ""
echo "It will also modify scripts for the demo and create:"
echo "     - 2 Servers in ossdemo-appdev-iaas - DEMO #1"
echo "     - 1 Kubernetes cluster in ossdemo-appdev-acs - DEMO #2"
echo "     - 1 Azure app service in ossdemo-appdev-paas - DEMO #3"
echo ""
echo "Installation & Configuration will require SU rights but pleae run this script as GBBOSSDemo."
echo ""
source /source/appdev-demo-EnvironmentTemplateValues
echo ""
echo -e "${BOLD}Current Template Values:${RESET}"
echo "      DEMO_UNIQUE_SERVER_PREFIX="$DEMO_UNIQUE_SERVER_PREFIX
echo "      DEMO_STORAGE_ACCOUNT="$DEMO_STORAGE_ACCOUNT
echo "      DEMO_ADMIN_USER="$DEMO_ADMIN_USER
echo "      DEMO_REGISTRY_SERVER-NAME="$DEMO_REGISTRY_SERVER_NAME
echo "      DEMO_REGISTRY_USER_NAME="$DEMO_REGISTRY_USER_NAME
echo "      DEMO_REGISTRY_PASSWORD="$DEMO_REGISTRY_PASSWORD
echo "      DEMO_OMS_WORKSPACE="$DEMO_OMS_WORKSPACE
echo "      DEMO_OMS_PRIMARYKEY="$DEMO_OMS_PRIMARYKEY
echo "      DEMO_APPLICATION_INSIGHTS_ASPNETLINUX_KEY="$DEMO_APPLICATION_INSIGHTS_ASPNETLINUX_KEY
echo "      DEMO_APPLICATION_INSIGHTS_ESHOPONCONTAINERS_KEY="$DEMO_APPLICATION_INSIGHTS_ESHOPONCONTAINERS_KEY
echo "      DEMO_APPLICATION_INSIGHTS_NODEJSTODO_KEY="$DEMO_APPLICATION_INSIGHTS_NODEJSTODO_KEY
echo ""
#ensure we are in the root of the demo directory
cd /source/AppDev-ContainerDemo
if [[ -z $DEMO_UNIQUE_SERVER_PREFIX  ]]; then
   echo "   Server PREFIX is null.  Please correct and re-run this script.."
   exit
fi
echo "The remainder of this script requires the template values be filled in the /source/appdev-demo-EnvironmentTemplateValues file."
read -p "Press any key to continue or CTRL-C to exit... " startscript

echo "Logging in to Azure"
#Checking to see if we are logged into Azure
echo "    Checking if we are logged in to Azure."
#We need to redirect the output streams to stdout
azstatus=`~/bin/az group list 2>&1` 
if [[ $azstatus =~ "Please run 'az login' to setup account." ]]; then
   echo "   We need to login to azure.."
   az login
else
   echo "    Logged in."
fi
echo -e "${BOLD}Confirm Azure Subscription${RESET}"
read -p "Change default subscription? [y/N]:" changesubscription
if [[ ${changesubscription,,} =~ "y" ]];then
    read -p "      New Subscription Name:" newsubscription
    ~/bin/az account set --subscription "$newsubscription"
else
    echo "    Using default existing subscription."
fi

cd /source

#Set Scripts as executable & ensure everything is writeable
echo ".setting scripts as executables"
find /source/AppDev-ContainerDemo  -type f -name "*.sh" -exec sudo chmod +x {} \;
sudo chmod 777 -R /source

#RESET DEMO VALUES
echo -e "${BOLD}Configuring demo scripts with defaults.${RESET}"
cd /source/AppDev-ContainerDemo
/source/AppDev-ContainerDemo/environment/reset-demo-template-values.sh

#DOWNLOAD SOURCE FILES
/source/AppDev-ContainerDemo/environment/download-source-projects.sh

echo "---------------------------------------------"
echo -e "${INPUT}Resource Group Creation${RESET}"
read -p "Apply JSON Templates for and network rules and create IaaS, K8S and PaaS resources? [Y/n]:"  continuescript
if [[ $continuescript != "n" ]];then
    #BUILD RESOURCE GROUPS
    
    #APPLY JSON TEMPLATES
    echo ".create ossdemo-appdev-iaas in case it doesnt exist."
    ~/bin/az group create --name ossdemo-appdev-iaas --location eastus
    echo -e ".apply ./environment/ossdemo-appdev-iaas.json template."
    ~/bin/az group deployment create --resource-group ossdemo-appdev-iaas --name InitialDeployment \
        --template-file /source/AppDev-ContainerDemo/environment/ossdemo-appdev-iaas.json
    ~/bin/az group create --name ossdemo-appdev-acs --location eastus
    ~/bin/az group create --name ossdemo-appdev-paas --location eastus
    
    echo ".create ossdemo-appdev-paas in case it doesnt exist."
    ~/bin/az group create --name ossdemo-appdev-paas --location eastus
    echo -e ".Apply ./environment/ossdemo-appdev-paas.json template."
    ~/bin/az group deployment create --resource-group ossdemo-appdev-paas --name InitialDeployment \
        --template-file /source/AppDev-ContainerDemo/environment/ossdemo-appdev-paas.json

    echo -e ".Apply ./environment/ossdemo-utility-update-subnetNSG.json template."
    ~/bin/az group deployment create --resource-group ossdemo-utility --name UpdateVNETwithNewSubnetandNSG \
        --template-file /source/AppDev-ContainerDemo/environment/ossdemo-utility-update-subnetNSG.json

    echo ".create ossdemo-appdev-acs in case it doesnt exist."
    ~/bin/az group create --name ossdemo-appdev-acs --location eastus
    
  echo ".calling server creation script for iaas VMs"
  /source/AppDev-ContainerDemo/environment/iaas/create-iaas-worker-vm.sh
  echo "----------------------------------------------"
  echo -e "${INPUT}Sleeping for 30 seconds while the last server gets ready...${RESET}"
  sudo pip install termdown
  termdown 30
  echo ".configuring iaas docker hosts with the new docker engine adn OMS agent"
  echo "----------------------------------------------"
  # we need to make sure we run the ansible playbook from this directory to pick up the cfg file
  cd /source/AppDev-ContainerDemo/environment/iaas/ 
  /source/AppDev-ContainerDemo/environment/iaas/deploy-docker-engine.sh
  
  echo ".calling acs creation script"
  /source/AppDev-ContainerDemo/environment/acs/create-k8s-cluster.sh
  /source/AppDev-ContainerDemo/environment/acs/deploy-k8s-OMSDaemonset.sh

  echo ".calling paas server creation"
  /source/AppDev-ContainerDemo/environment/paas/create-webplan-linux-service.sh

fi

echo -e "${BOLD}JUMPBOX Environment Setup${RESET}"
echo ".Copy desktop icons"
#Copy the desktop icons
sudo cp /source/AppDev-ContainerDemo/vm-assets/*.desktop ~/Desktop/
sudo chmod +x ~/Desktop/code.desktop
sudo chmod +x ~/Desktop/firefox.desktop
sudo chmod +x ~/Desktop/gnome-terminal.desktop

#do we have the latest verion of .net?
echo ".Installing libunwind libicu"
sudo yum install -qq libunwind libicu -y
echo ".Set the dotnet path variables"
echo "export PATH=$PATH:/usr/local/bin" >> ~/.bashrc

#ensure .net is setup correctly
echo ".installing gcc libffi-devel python-devel openssl-devel"
sudo yum install -y -q gcc libffi-devel python-devel openssl-devel
echo ".installing npm"
sudo yum install -q -y npm
echo ".installing bower"
sudo npm install bower -g -silent
echo ".installing gulp"
sudo npm install gulp -g -silent
echo ".installing python 35 and pip"
sudo yum install -y -q python35u python35u-pip 

#Install Rimraf for Node Apps
echo ".Installing rimfraf, webpack, node-saas"
sudo npm install rimraf -g -silent
sudo npm install webpack -g -silent
sudo npm install node-sass -g -silent

#reset file permissions
echo "CHMOD for Users on /source"
sudo chmod 777 -R /source

#install HELM for Kubernetes package management
mkdir -p $HOME/Downloads/HELM && cd $HOME/Downloads/HELM
curl https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get > get_helm.sh
chmod 700 get_helm.sh
./get_helm.sh
helm init

echo "installing OMS Agent across environment"
/source/AppDev-ContainerDemo/environment/iaas/deploy-OMS-agent.sh

echo "${BOLD}Demo environment setup complete.  Please review demos found under /source/AppDev-ContainerDemo for IaaS, ACS and PaaS.${RESET}"