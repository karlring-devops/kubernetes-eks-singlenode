#!/bin/bash


kdelobjs(){  #--- <object_type:pods,svc,nodes,rc,rs,pv,pvc,sts> <namespace> <REXGEX> 
	K8S_OBJECT_NAMES=$(kubectl get ${1} -n ${2} | grep ${3} | head -1 | awk '{print $1}' ; )
  for k in ${K8S_OBJECT_NAMES}
  do
  	kubectl delete -n ${2} ${1} ${k} --grace-period 0 --force
  done
}

setup_helm(){
	# /-- helm setup ---/
	kubectl cluster-info
	mkdir ~/.helm
	cd ~/.helm

	curl https://raw.githubusercontent.com/kubernetes/Helm/master/scripts/get > get_Helm.sh
	chmod 700 get_Helm.sh
	./get_Helm.sh

	helm init
	sleep 15
}

setup_tiller(){
	# /-- tiller setup ---/
	kubectl apply -f tiller-rbac.yaml
	kubectl --namespace kube-system create serviceaccount tiller
	kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
	helm init --upgrade
	sleep 15
	kubectl --namespace kube-system patch deploy tiller-deploy -p '{"spec":{"template":{"spec":{"serviceAccount":"tiller"}}}}'
}

setup_storage(){
	# /-- storage setup ---/
	kubectl delete sc standard
	kubectl create -f k8s-default-storage-class.yaml
	kubectl patch storageclass standard -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
	kubectl delete pv pv-standard
	kubectl create -f k8s-default-storage-class-volume.yaml
}

setup_elastic(){
	# /-- elastic setup ---/
	#curl -O https://raw.githubusercontent.com/elastic/Helm-charts/master/elasticsearch/examples/minikube/values.yaml
	helm repo add elastic https://Helm.elastic.co
	helm install --name elasticsearch elastic/elasticsearch --values ./values.yaml --set replicas=1 
	sleep 15
	kubectl port-forward svc/elasticsearch-master 9200 &
	sleep 10
	kubectl logs -n default elasticsearch-master-0
}

setup_kibana(){
	# /-- kibana setup ---/
	helm install --name kibana elastic/kibana 
	sleep 60
	kubectl port-forward deployment/kibana-kibana 5601 &
	sleep 10
	kubectl logs -n default $(kubectl get pods -n default | grep 'kibana-kibana')
}

setup_metricbeat(){
	# /--- metricbeat setup ---/
	sleep 60
	helm install --name metricbeat elastic/metricbeat
}


# /****************************/
# / REMOVE
# /----------------------------/

rmTiller(){

	kdelobjs pod kube-system tiller
	kdelobjs replicaset kube-system tiller
	kdelobjs secret kube-system tiller
	kubectl delete sa tiller
	kubectl delete clusterrolebinding tiller-clusterrolebinding
	kubectl delete clusterrolebinding tiller-cluster-rule
	kubectl delete -n kube-system serviceaccount tiller
	kubectl delete -n kube-system deployment tiller-deploy
	kubectl delete -n kube-system service tiller-deploy
	kubectl delete pv pv-standard
}

rmElasticSearch(){	
	kdelobjs pod default elasticsearch
	kdelobjs sts default elasticsearch
	kdelobjs cm  kube-system elasticsearch
	kdelobjs pvc default elasticsearch
	kdelobjs svc default elasticsearch
	kubectl delete poddisruptionbudgets elasticsearch-master-pdb
	sleep 15
	kdelobjs svc default elasticsearch
}

rmKibana(){
	kdelobjs deployment default kibana
	kdelobjs pod default kibana
	kdelobjs replicaset default kibana
	kdelobjs svc default kibana
	kdelobjs cm  default kibana
}


rmMetricBeat(){
  	kdelobjs daemonset  default metricbeat
	kdelobjs deployment default metricbeat
	kdelobjs pods default metricbeat
	kdelobjs rs   default metricbeat
	kdelobjs svc  default metricbeat
	kdelobjs cm   default metricbeat
	kdelobjs cm   kube-system metricbeat
	#/--- delete secrets -----/
	kdelobjs secret default metricbeat
	kubectl delete clusterrolebinding metricbeat-metricbeat-cluster-role-binding
	kubectl delete clusterrolebinding metricbeat-kube-state-metrics
	kubectl delete clusterrole metricbeat-kube-state-metrics
	kubectl delete clusterrole metricbeat-metricbeat-cluster-role
	kubectl delete -n default serviceaccount metricbeat-kube-state-metrics
	kubectl delete -n default serviceaccount metricbeat-metricbeat
}
