#! /bin/bash

# Sed_set_ip :
#	[$1] : server_ip
#	[$2] : path 
sed_set_ip()
{
	sed -i.bak 's/http:\/\/IP/http:\/\/'"$1"'/g' $2
	sleep 1
}

# Mount_container :
#	[$1] : container name
mount_container()
{
	echo -ne "\033[1;32m+>\033[0;33m Build $1 image ... \n"
	docker build -t services/$1 srcs/containers/$1/ &> /dev/null
	sleep 1
}

# Up_service :
#	[$1] : service name
up_service()
{
	echo -ne "\033[1;32m+>\033[0;33m Up $1 service ... \n"
	kubectl apply -f srcs/yaml/$1.yaml &> /dev/null
	sleep 1
}

# Ensure minikube is launched
if ! minikube status >/dev/null 2>&1
then
    echo Minikube is not launched! Starting now...
    if ! minikube start --vm-driver=virtualbox \
		--cpus 3 --disk-size=30000mb --memory=3000mb --extra-config=apiserver.service-node-port-range=1-35000
    then
        echo Cannot start minikube!
        exit 1
    fi
    minikube addons enable metrics-server
    minikube addons enable ingress
fi

server_ip=`minikube ip`
sed_list="srcs/containers/mysql/wp.sql srcs/containers/wordpress/wp-config.php srcs/yaml/telegraf.yaml"

echo -ne "\033[1;32m+>\033[0;33m Set IP on configs ... \n"
for path in $sed_list
do
	sed_set_ip $server_ip $path
done
sed -i.bak 's/MINIKUBE_IP/'"$server_ip"'/g' srcs/containers/ftps/setup.sh

echo -ne "\033[1;32m+>\033[0;33m Update grafana db ... \n"
echo "UPDATE data_source SET url = 'http://$server_ip:8086'" | sqlite3 srcs/containers/grafana/grafana.db

echo -ne "\033[1;32m+>\033[0;33m Link docker local image to minikube ... \n"
eval $(minikube docker-env)

names="nginx influxdb grafana mysql phpmyadmin wordpress telegraf ftps"

for name in $names
do
	mount_container $name
	up_service $name
done
minikube addons enable ingress
echo -ne "\033[1;33m+>\033[0;33m IP : $server_ip \n"

sleep 1
sed -i.bak 's/http:\/\/'"$server_ip"'/http:\/\/IP/g' srcs/containers/mysql/wp.sql
sleep 1
sed -i.bak 's/http:\/\/'"$server_ip"'/http:\/\/IP/g' srcs/containers/wordpress/wp-config.php
sleep 1
sed -i.bak 's/http:\/\/'"$server_ip"'/http:\/\/IP/g' srcs/yaml/telegraf.yaml
sleep 1
sed -i.bak 's/'"$server_ip"'/MINIKUBE_IP/g' srcs/containers/ftps/setup.sh
sleep 1

echo -ne "\033[1;32m+>\033[0;33m Waiting for the site to be up "
until $(curl --output /dev/null --silent --head --fail http://$server_ip/); do
	echo -n "."
	sleep 2
done;

echo -ne " Open website ... \n"
open http://$server_ip

### Dashboard
# minikube dashboard

###
# ssh admin@$(minikube ip) -p 1234

### Crash Container
# kubectl exec -it $(kubectl get pods | grep mysql | cut -d" " -f1) -- /bin/sh -c "ps"  
# kubectl exec -it $(kubectl get pods | grep mysql | cut -d" " -f1) -- /bin/sh -c "kill number" 
