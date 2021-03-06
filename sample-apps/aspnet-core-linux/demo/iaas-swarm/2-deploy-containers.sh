RESET="\e[0m"
INPUT="\e[7m"
BOLD="\e[4m"
YELLOW="\033[38;5;11m"
RED="\033[0;31m"

echo "Remove the aspnet_web application if it already exists on the SWARM cluster."
#az account set --subscription "Microsoft Azure Internal Consumption"
sudo docker service rm aspnet_web
echo -e "${BOLD}Deploy containers...${RESET}"
echo "Deploy the application on the SWARM cluster."
echo "login to Docker registry and then pass the credentials to the swarm nodes"
sudo docker login VALUEOF-REGISTRY-SERVER-NAME -u VALUEOF-REGISTRY-USER-NAME -p VALUEOF-REGISTRY-PASSWORD
sudo docker stack deploy --compose-file docker-stack.yml --with-registry-auth aspnet

echo "Current status of the cluster:"
echo ".running sudo docker service list"
sudo docker service list
echo ".running sudo docker service ps aspnet_web"
sudo docker service ps aspnet_web

echo -e ".you can now browse the application at http://svr1-VALUEOF-UNIQUE-SERVER-PREFIX.eastus.cloudapp.azure.com:81 for individual servers."
echo -e ".you can now monitor the application at http://jumpbox-VALUEOF-UNIQUE-SERVER-PREFIX.eastus.cloudapp.azure.com:8081 for individual servers."
echo -e ". or at http://VALUEOF-UNIQUE-SERVER-PREFIX-iaas-demo.eastus.cloudapp.azure.com:81 for a loadbalanced IP."
echo -e ".scale command: sudo docker service scale aspnet_web=5"