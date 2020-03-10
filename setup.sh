#! /bin/bash

sed_set_ip()
{
	sed -i.bak 's/http:\/\/IP/http:\/\/'"$1"'/g' $2
	sleep 1
}

mount_container()
{
	echo "\033[1;32m->\033[0;32m Building $1 image ... \n"
	docker build -t services/$1 srcs/containers/$1/ &> /dev/null
	sleep 1
}

up_service()
{
	echo "\033[1;32m->\033[0;32m Up $1 service ... \n"
	kubectl apply -f srcs/yaml/$1.yaml &> /dev/null
	sleep 1
}

# Ensure minikube is launched
if ! minikube status >/dev/null 2>&1
then
    echo "\033[1;31m->\033[0;31m Minikube is not launched. Starting now... \n"
    if ! minikube start --vm-driver=virtualbox \
		--cpus 3 --disk-size=30000mb --memory=3000mb --extra-config=apiserver.service-node-port-range=1-35000
    then
        echo "\033[1;31m->\033[0;31m Minikube can't be started! \n"
        exit 1
    fi
    minikube addons enable metrics-server
    minikube addons enable ingress
fi

server_ip=`minikube ip`
sed_list="srcs/containers/mysql/wp.sql srcs/containers/wordpress/wp-config.php srcs/yaml/telegraf.yaml"

for path in $sed_list
do
	sed_set_ip $server_ip $path
done
sed -i.bak 's/MINIKUBE_IP/'"$server_ip"'/g' srcs/containers/ftps/setup.sh
sed -i.bak 's/IP/'"$server_ip"'/g' srcs/containers/nginx/index.html
sed -i.bak 's/IP/'"$server_ip"'/g' srcs/containers/nginx/index.html
sed -i.bak 's/IP/'"$server_ip"'/g' srcs/containers/nginx/index.html

echo "UPDATE data_source SET url = 'http://$server_ip:8086'" | sqlite3 srcs/containers/grafana/grafana.db

eval $(minikube docker-env)

names="nginx influxdb grafana mysql phpmyadmin wordpress telegraf ftps"

for name in $names
do
	mount_container $name
	up_service $name
done

echo "\033[1;34m->\033[0;34m IP : $server_ip \n"

sleep 1
sed -i.bak 's/http:\/\/'"$server_ip"'/http:\/\/IP/g' srcs/containers/mysql/wp.sql
sleep 1
sed -i.bak 's/http:\/\/'"$server_ip"'/http:\/\/IP/g' srcs/containers/wordpress/wp-config.php
sleep 1
sed -i.bak 's/http:\/\/'"$server_ip"'/http:\/\/IP/g' srcs/yaml/telegraf.yaml
sleep 1
sed -i.bak 's/'"$server_ip"'/MINIKUBE_IP/g' srcs/containers/ftps/setup.sh
sleep 1
sed -i.bak 's/'"$server_ip"'/IP/g' srcs/containers/nginx/index.html
sleep 1


echo "\033[1;32m+>\033[0;32m Open website...\n"
open http://$server_ip
