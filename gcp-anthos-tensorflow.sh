#!/bin/bash
#
# Copyright 2019 Shiyghan Navti. Email shiyghan@gmail.com
#
#################################################################################
### Canary Releases of TensorFlow Model Deployments with Anthos Service Mesh  ###
#################################################################################

# User prompt function
function ask_yes_or_no() {
    read -p "$1 ([y]yes to preview, [n]o to create, [d]del to delete): "
    case $(echo $REPLY | tr '[A-Z]' '[a-z]') in
        n|no)  echo "no" ;;
        d|del) echo "del" ;;
        *)     echo "yes" ;;
    esac
}

function ask_yes_or_no_proj() {
    read -p "$1 ([y]es to change, or any key to skip): "
    case $(echo $REPLY | tr '[A-Z]' '[a-z]') in
        y|yes) echo "yes" ;;
        *)     echo "no" ;;
    esac
}

clear
MODE=1
export TRAINING_ORG_ID=$(gcloud organizations list --format 'value(ID)' --filter="displayName:techequity.training" 2>/dev/null)
export ORG_ID=$(gcloud projects get-ancestors $GCP_PROJECT --format 'value(ID)' 2>/dev/null | tail -1 )
export GCP_PROJECT=$(gcloud config list --format 'value(core.project)' 2>/dev/null)

echo
echo
echo -e "                        👋  Welcome to Cloud Sandbox! 💻"
echo 
echo -e "              *** PLEASE WAIT WHILE LAB UTILITIES ARE INSTALLED ***"
sudo apt-get -qq install pv > /dev/null 2>&1
echo 
export SCRIPTPATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

mkdir -p `pwd`/gcp-anthos-tensorflow > /dev/null 2>&1
export PROJDIR=`pwd`/gcp-anthos-tensorflow
export SCRIPTNAME=gcp-anthos-tensorflow.sh

if [ -f "$PROJDIR/.env" ]; then
    source $PROJDIR/.env
else
cat <<EOF > $PROJDIR/.env
export GCP_PROJECT=$GCP_PROJECT
export ASM_VERSION=1.16.2-asm.2
export ASM_INSTALL_SCRIPT_VERSION=1.16
export GCP_REGION=europe-west1
export GCP_ZONE=europe-west1-b
export GCP_CLUSTER=anthos-gke-cluster
EOF
source $PROJDIR/.env
fi

# Display menu options
while :
do
clear
cat<<EOF
=============================================================================
Explore TensorFlow Model Deployments with Anthos Service Mesh
-----------------------------------------------------------------------------
Please enter number to select your choice:
 (1) Install tools
 (2) Enable APIs
 (3) Create GKE cluster
 (4) Install Anthos Service Mesh
 (5) Deploying ResNet models using TensorFlow Serving
 (6) Configuring weighted load balancing and focused canary testing
 (G) Launch user guide
 (Q) Quit
-----------------------------------------------------------------------------
EOF
echo "Steps performed${STEP}"
echo
echo "What additional step do you want to perform, e.g. enter 0 to select the execution mode?"
read
clear
case "${REPLY^^}" in

"0")
start=`date +%s`
source $PROJDIR/.env
echo
echo "Do you want to run script in preview mode?"
export ANSWER=$(ask_yes_or_no "Are you sure?")
cd $HOME
if [[ ! -z "$TRAINING_ORG_ID" ]]  &&  [[ $ORG_ID == "$TRAINING_ORG_ID" ]]; then
    export STEP="${STEP},0"
    MODE=1
    if [[ "yes" == $ANSWER ]]; then
        export STEP="${STEP},0i"
        MODE=1
        echo
        echo "*** Command preview mode is active ***" | pv -qL 100
    else 
        if [[ -f $PROJDIR/.${GCP_PROJECT}.json ]]; then
            echo 
            echo "*** Authenticating using service account key $PROJDIR/.${GCP_PROJECT}.json ***" | pv -qL 100
            echo "*** To use a different GCP project, delete the service account key ***" | pv -qL 100
        else
            while [[ -z "$PROJECT_ID" ]] || [[ "$GCP_PROJECT" != "$PROJECT_ID" ]]; do
                echo 
                echo "$ gcloud auth login --brief --quiet # to authenticate as project owner or editor" | pv -qL 100
                gcloud auth login  --brief --quiet
                export ACCOUNT=$(gcloud config list account --format "value(core.account)")
                if [[ $ACCOUNT != "" ]]; then
                    echo
                    echo "Copy and paste a valid Google Cloud project ID below to confirm your choice:" | pv -qL 100
                    read GCP_PROJECT
                    gcloud config set project $GCP_PROJECT --quiet 2>/dev/null
                    sleep 3
                    export PROJECT_ID=$(gcloud projects list --filter $GCP_PROJECT --format 'value(PROJECT_ID)' 2>/dev/null)
                fi
            done
            gcloud iam service-accounts delete ${GCP_PROJECT}@${GCP_PROJECT}.iam.gserviceaccount.com --quiet 2>/dev/null
            sleep 2
            gcloud --project $GCP_PROJECT iam service-accounts create ${GCP_PROJECT} 2>/dev/null
            gcloud projects add-iam-policy-binding $GCP_PROJECT --member serviceAccount:$GCP_PROJECT@$GCP_PROJECT.iam.gserviceaccount.com --role=roles/owner > /dev/null 2>&1
            gcloud --project $GCP_PROJECT iam service-accounts keys create $PROJDIR/.${GCP_PROJECT}.json --iam-account=${GCP_PROJECT}@${GCP_PROJECT}.iam.gserviceaccount.com 2>/dev/null
            gcloud --project $GCP_PROJECT storage buckets create gs://$GCP_PROJECT > /dev/null 2>&1
        fi
        export GOOGLE_APPLICATION_CREDENTIALS=$PROJDIR/.${GCP_PROJECT}.json
        cat <<EOF > $PROJDIR/.env
export GCP_PROJECT=$GCP_PROJECT
export GCP_REGION=$GCP_REGION
export GCP_ZONE=$GCP_ZONE
export ASM_VERSION=$ASM_VERSION
export ASM_INSTALL_SCRIPT_VERSION=$ASM_INSTALL_SCRIPT_VERSION
export GCP_CLUSTER=$GCP_CLUSTER
EOF
        gsutil cp $PROJDIR/.env gs://${GCP_PROJECT}/${SCRIPTNAME}.env > /dev/null 2>&1
        echo
        echo "*** Google Cloud project is $GCP_PROJECT ***" | pv -qL 100
        echo "*** Google Cloud region is $GCP_REGION ***" | pv -qL 100
        echo "*** Google Cloud zone is $GCP_ZONE ***" | pv -qL 100
        echo "*** Anthos Service Mesh version is $ASM_VERSION ***" | pv -qL 100
        echo "*** Anthos Service Mesh install script version is $ASM_INSTALL_SCRIPT_VERSION ***" | pv -qL 100
        echo
        echo "*** Update environment variables by modifying values in the file: ***" | pv -qL 100
        echo "*** $PROJDIR/.env ***" | pv -qL 100
        if [[ "no" == $ANSWER ]]; then
            MODE=2
            echo
            echo "*** Create mode is active ***" | pv -qL 100
        elif [[ "del" == $ANSWER ]]; then
            export STEP="${STEP},0"
            MODE=3
            echo
            echo "*** Resource delete mode is active ***" | pv -qL 100
        fi
    fi
else 
    if [[ "no" == $ANSWER ]] || [[ "del" == $ANSWER ]] ; then
        export STEP="${STEP},0"
        if [[ -f $SCRIPTPATH/.${SCRIPTNAME}.secret ]]; then
            echo
            unset password
            unset pass_var
            echo -n "Enter access code: " | pv -qL 100
            while IFS= read -p "$pass_var" -r -s -n 1 letter
            do
                if [[ $letter == $'\0' ]]
                then
                    break
                fi
                password=$password"$letter"
                pass_var="*"
            done
            while [[ -z "${password// }" ]]; do
                unset password
                unset pass_var
                echo
                echo -n "You must enter an access code to proceed: " | pv -qL 100
                while IFS= read -p "$pass_var" -r -s -n 1 letter
                do
                    if [[ $letter == $'\0' ]]
                    then
                        break
                    fi
                    password=$password"$letter"
                    pass_var="*"
                done
            done
            export PASSCODE=$(cat $SCRIPTPATH/.${SCRIPTNAME}.secret | openssl enc -aes-256-cbc -md sha512 -a -d -pbkdf2 -iter 100000 -salt -pass pass:$password 2> /dev/null)
            if [[ $PASSCODE == 'AccessVerified' ]]; then
                MODE=2
                echo && echo
                echo "*** Access code is valid ***" | pv -qL 100
                if [[ -f $PROJDIR/.${GCP_PROJECT}.json ]]; then
                    echo 
                    echo "*** Authenticating using service account key $PROJDIR/.${GCP_PROJECT}.json ***" | pv -qL 100
                    echo "*** To use a different GCP project, delete the service account key ***" | pv -qL 100
                else
                    while [[ -z "$PROJECT_ID" ]] || [[ "$GCP_PROJECT" != "$PROJECT_ID" ]]; do
                        echo 
                        echo "$ gcloud auth login --brief --quiet # to authenticate as project owner or editor" | pv -qL 100
                        gcloud auth login  --brief --quiet
                        export ACCOUNT=$(gcloud config list account --format "value(core.account)")
                        if [[ $ACCOUNT != "" ]]; then
                            echo
                            echo "Copy and paste a valid Google Cloud project ID below to confirm your choice:" | pv -qL 100
                            read GCP_PROJECT
                            gcloud config set project $GCP_PROJECT --quiet 2>/dev/null
                            sleep 3
                            export PROJECT_ID=$(gcloud projects list --filter $GCP_PROJECT --format 'value(PROJECT_ID)' 2>/dev/null)
                        fi
                    done
                    gcloud iam service-accounts delete ${GCP_PROJECT}@${GCP_PROJECT}.iam.gserviceaccount.com --quiet 2>/dev/null
                    sleep 2
                    gcloud --project $GCP_PROJECT iam service-accounts create ${GCP_PROJECT} 2>/dev/null
                    gcloud projects add-iam-policy-binding $GCP_PROJECT --member serviceAccount:$GCP_PROJECT@$GCP_PROJECT.iam.gserviceaccount.com --role=roles/owner > /dev/null 2>&1
                    gcloud --project $GCP_PROJECT iam service-accounts keys create $PROJDIR/.${GCP_PROJECT}.json --iam-account=${GCP_PROJECT}@${GCP_PROJECT}.iam.gserviceaccount.com 2>/dev/null
                    gcloud --project $GCP_PROJECT storage buckets create gs://$GCP_PROJECT > /dev/null 2>&1
                fi
                export GOOGLE_APPLICATION_CREDENTIALS=$PROJDIR/.${GCP_PROJECT}.json
                cat <<EOF > $PROJDIR/.env
export GCP_PROJECT=$GCP_PROJECT
export GCP_REGION=$GCP_REGION
export GCP_ZONE=$GCP_ZONE
export ASM_VERSION=$ASM_VERSION
export ASM_INSTALL_SCRIPT_VERSION=$ASM_INSTALL_SCRIPT_VERSION
export GCP_CLUSTER=$GCP_CLUSTER
EOF
                gsutil cp $PROJDIR/.env gs://${GCP_PROJECT}/${SCRIPTNAME}.env > /dev/null 2>&1
                echo
                echo "*** Google Cloud project is $GCP_PROJECT ***" | pv -qL 100
                echo "*** Google Cloud region is $GCP_REGION ***" | pv -qL 100
                echo "*** Google Cloud zone is $GCP_ZONE ***" | pv -qL 100
                echo "*** Anthos Service Mesh version is $ASM_VERSION ***" | pv -qL 100
                echo "*** Anthos Service Mesh install script version is $ASM_INSTALL_SCRIPT_VERSION ***" | pv -qL 100
                echo
                echo "*** Update environment variables by modifying values in the file: ***" | pv -qL 100
                echo "*** $PROJDIR/.env ***" | pv -qL 100
                if [[ "no" == $ANSWER ]]; then
                    MODE=2
                    echo
                    echo "*** Create mode is active ***" | pv -qL 100
                elif [[ "del" == $ANSWER ]]; then
                    export STEP="${STEP},0"
                    MODE=3
                    echo
                    echo "*** Resource delete mode is active ***" | pv -qL 100
                fi
            else
                echo && echo
                echo "*** Access code is invalid ***" | pv -qL 100
                echo "*** You can use this script in our Google Cloud Sandbox without an access code ***" | pv -qL 100
                echo "*** Contact support@techequity.cloud for assistance ***" | pv -qL 100
                echo
                echo "*** Command preview mode is active ***" | pv -qL 100
            fi
        else
            echo
            echo "*** You can use this script in our Google Cloud Sandbox without an access code ***" | pv -qL 100
            echo "*** Contact support@techequity.cloud for assistance ***" | pv -qL 100
            echo
            echo "*** Command preview mode is active ***" | pv -qL 100
        fi
    else
        export STEP="${STEP},0i"
        MODE=1
        echo
        echo "*** Command preview mode is active ***" | pv -qL 100
    fi
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"1")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},1i"
    echo
    echo "$ kpt pkg get https://github.com/GoogleCloudPlatform/mlops-on-gcp/workshops/mlep-qwiklabs/tfserving-canary-gke \$PROJDIR/tfserving-canary # to retrieve lab files" | pv -qL 100
    echo
    echo "$ curl https://storage.googleapis.com/csm-artifacts/asm/asmcli_\${ASM_INSTALL_SCRIPT_VERSION} > \$PROJDIR/asmcli # to download script" | pv -qL 100
    echo
    echo "$ git clone https://github.com/GoogleCloudPlatform/anthos-service-mesh-packages.git /tmp/anthos-service-mesh-packages # to clone repo" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},1"
    echo
    echo "$ kpt pkg get https://github.com/GoogleCloudPlatform/mlops-on-gcp/workshops/mlep-qwiklabs/tfserving-canary-gke $PROJDIR/tfserving-canary # to retrieve lab files" | pv -qL 100
    kpt pkg get https://github.com/GoogleCloudPlatform/mlops-on-gcp/workshops/mlep-qwiklabs/tfserving-canary-gke $PROJDIR/tfserving-canary
    echo
    echo "$ curl https://storage.googleapis.com/csm-artifacts/asm/asmcli_${ASM_INSTALL_SCRIPT_VERSION} > $PROJDIR/asmcli # to download script" | pv -qL 100
    curl https://storage.googleapis.com/csm-artifacts/asm/asmcli_${ASM_INSTALL_SCRIPT_VERSION} > $PROJDIR/asmcli
    echo
    echo "$ chmod +x $PROJDIR/asmcli # to make the script executable" | pv -qL 100
    chmod +x $PROJDIR/asmcli
    echo
    rm -rf /tmp/anthos-service-mesh-packages
    echo "$ git clone https://github.com/GoogleCloudPlatform/anthos-service-mesh-packages.git /tmp/anthos-service-mesh-packages # to clone repo" | pv -qL 100
    git clone https://github.com/GoogleCloudPlatform/anthos-service-mesh-packages.git /tmp/anthos-service-mesh-packages
    echo
    echo "$ cp -rf /tmp/anthos-service-mesh-packages $PROJDIR # to copy files"
    cp -rf /tmp/anthos-service-mesh-packages $PROJDIR
    rm -rf /tmp/anthos-service-mesh-packages
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},1x"
    echo
    echo "$ rm -rf $PROJDIR # to delete files" | pv -qL 100
else
    export STEP="${STEP},1i"
    echo
    echo "1. Retrieve lab files" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"2")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},2i"
    echo
    echo "$ gcloud --project \$GCP_PROJECT services enable container.googleapis.com compute.googleapis.com monitoring.googleapis.com logging.googleapis.com cloudtrace.googleapis.com meshca.googleapis.com meshtelemetry.googleapis.com meshconfig.googleapis.com iamcredentials.googleapis.com anthos.googleapis.com anthosgke.googleapis.com gkeconnect.googleapis.com gkehub.googleapis.com cloudresourcemanager.googleapis.com # to enable APIs" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},2"
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1 
    echo
    echo "$ gcloud --project $GCP_PROJECT services enable container.googleapis.com compute.googleapis.com monitoring.googleapis.com logging.googleapis.com cloudtrace.googleapis.com meshca.googleapis.com meshtelemetry.googleapis.com meshconfig.googleapis.com iamcredentials.googleapis.com anthos.googleapis.com anthosgke.googleapis.com gkeconnect.googleapis.com gkehub.googleapis.com cloudresourcemanager.googleapis.com # to enable APIs" | pv -qL 100
    gcloud --project $GCP_PROJECT services enable container.googleapis.com compute.googleapis.com monitoring.googleapis.com logging.googleapis.com cloudtrace.googleapis.com meshca.googleapis.com meshtelemetry.googleapis.com meshconfig.googleapis.com iamcredentials.googleapis.com anthos.googleapis.com anthosgke.googleapis.com gkeconnect.googleapis.com gkehub.googleapis.com cloudresourcemanager.googleapis.com
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},2x"
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1 
    echo
    echo "*** Nothing to delete ***" | pv -qL 100
else
    export STEP="${STEP},2i"
    echo
    echo "1. Enable APIs" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"3")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},3i"
    echo
    echo "$ gcloud --project \$GCP_PROJECT beta container clusters create \$GCP_CLUSTER --machine-type=e2-standard-4 --num-nodes=4 --workload-pool=\${WORKLOAD_POOL} --labels=mesh_id=\${MESH_ID},location=\$GCP_REGION --spot # to create cluster" | pv -qL 100
    echo      
    echo "$ gcloud --project \$GCP_PROJECT container clusters get-credentials \$GCP_CLUSTER --zone \$GCP_ZONE # to retrieve credentials for cluster" | pv -qL 100
    echo
    echo "$ kubectl create clusterrolebinding cluster-admin-binding --clusterrole=cluster-admin --user=\"\$(gcloud config get-value core/account)\" # to enable user to set RBAC rules" | pv -qL 100
    echo
    echo "$ gcloud container fleet memberships register \$GCP_CLUSTER --gke-cluster=\$GCP_ZONE/\$GCP_CLUSTER --enable-workload-identity # to register cluster" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},3"   
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1 
    gcloud config set compute/zone $GCP_ZONE > /dev/null 2>&1 
    export PROJECT_NUMBER=$(gcloud projects describe $GCP_PROJECT --format="value(projectNumber)")
    export MESH_ID="proj-${PROJECT_NUMBER}" # sets the mesh_id label on the cluster
    export WORKLOAD_POOL=${GCP_PROJECT}.svc.id.goog
    echo
    echo "$ gcloud --project $GCP_PROJECT beta container clusters create $GCP_CLUSTER --zone $GCP_ZONE --machine-type=e2-standard-4 --num-nodes=4 --workload-pool=${WORKLOAD_POOL} --labels=mesh_id=${MESH_ID},location=$GCP_REGION --spot # to create cluster" | pv -qL 100
    gcloud --project $GCP_PROJECT beta container clusters create $GCP_CLUSTER --zone $GCP_ZONE --machine-type=e2-standard-4 --num-nodes=4 --workload-pool=${WORKLOAD_POOL} --labels=mesh_id=${MESH_ID},location=$GCP_REGION --spot
    echo      
    echo "$ gcloud --project $GCP_PROJECT container clusters get-credentials $GCP_CLUSTER --zone $GCP_ZONE # to retrieve credentials for cluster" | pv -qL 100
    gcloud --project $GCP_PROJECT container clusters get-credentials $GCP_CLUSTER --zone $GCP_ZONE
    echo
    echo "$ kubectl create clusterrolebinding cluster-admin-binding --clusterrole=cluster-admin --user=\"$(gcloud config get-value core/account)\" # to enable user to set RBAC rules" | pv -qL 100
    kubectl create clusterrolebinding cluster-admin-binding --clusterrole=cluster-admin --user="$(gcloud config get-value core/account)"
    echo
    echo "$ gcloud container fleet memberships register $GCP_CLUSTER --gke-cluster=$GCP_ZONE/$$GCP_CLUSTER --enable-workload-identity # to register cluster"
    gcloud container fleet memberships register $GCP_CLUSTER --gke-cluster=$GCP_ZONE/$GCP_CLUSTER --enable-workload-identity
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},3x"   
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1 
    gcloud config set compute/zone $GCP_ZONE > /dev/null 2>&1 
    echo
    echo "$ gcloud --project $GCP_PROJECT beta container clusters delete $GCP_CLUSTER --zone $GCP_ZONE # to delete cluster" | pv -qL 100
    gcloud --project $GCP_PROJECT beta container clusters delete $GCP_CLUSTER --zone $GCP_ZONE
else
    export STEP="${STEP},3i"
    echo
    echo "1. Create GKE cluster" | pv -qL 100
    echo "2. Retrieve credentials for cluster" | pv -qL 100
    echo "3. Grant cluster admin priviledges to user" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"4")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},4i"
    echo
    echo "$ cat > \$PROJDIR/tracing.yaml <<EOF
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  meshConfig:
    enableTracing: true
  values:
    global:
      proxy:
        tracer: stackdriver
EOF" | pv -qL 100
    echo
    echo "$ \$PROJDIR/asmcli install --project_id \$GCP_PROJECT --cluster_name \$GCP_CLUSTER --cluster_location \$CLUSTER_LOCATION --fleet_id \$GCP_PROJECT --output_dir \$PROJDIR --enable_all --ca mesh_ca --custom_overlay \$PROJDIR/tracing.yaml --option legacy-default-ingressgateway # to install ASM" | pv -qL 100
    echo
    echo "$ kubectl create namespace istio-gateway # to create namespace"
    echo
    echo "$ kubectl label namespace istio-gateway istio.io/rev=\$ASM_REVISION --overwrite # to label namespace" | pv -qL 100
    echo
    echo "$ kubectl -n istio-gateway apply -f \$PROJDIR/anthos-service-mesh-packages/samples/gateways/istio-ingressgateway # to install ingress gateway" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},4"   
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1 
    gcloud config set compute/zone $GCP_ZONE > /dev/null 2>&1 
    kubectl config use-context gke_${GCP_PROJECT}_${GCP_ZONE}_${GCP_CLUSTER} > /dev/null 2>&1 
    gcloud --project $GCP_PROJECT container clusters get-credentials $GCP_CLUSTER --zone $GCP_ZONE > /dev/null 2>&1 
    export CLUSTER_LOCATION=$GCP_ZONE
    echo
    echo "$ gcloud --project $GCP_PROJECT container clusters get-credentials $GCP_CLUSTER --zone $GCP_ZONE # to retrieve the credentials for cluster" | pv -qL 100
    gcloud --project $GCP_PROJECT container clusters get-credentials $GCP_CLUSTER --zone $GCP_ZONE
    echo
    echo "$ cat > $PROJDIR/tracing.yaml <<EOF
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  meshConfig:
    enableTracing: true
  values:
    global:
      proxy:
        tracer: stackdriver
EOF" | pv -qL 100
cat > $PROJDIR/tracing.yaml <<EOF
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  meshConfig:
    enableTracing: true
  values:
    global:
      proxy:
        tracer: stackdriver
EOF
    echo
    sudo apt-get install ncat -y > /dev/null 2>&1 
    echo "$ $PROJDIR/asmcli install --project_id $GCP_PROJECT --cluster_name $GCP_CLUSTER --cluster_location $CLUSTER_LOCATION --fleet_id $GCP_PROJECT --output_dir $PROJDIR --enable_all --ca mesh_ca --custom_overlay $PROJDIR/tracing.yaml --option legacy-default-ingressgateway # to install ASM" | pv -qL 100
    $PROJDIR/asmcli install --project_id $GCP_PROJECT --cluster_name $GCP_CLUSTER --cluster_location $CLUSTER_LOCATION --fleet_id $GCP_PROJECT --output_dir $PROJDIR --enable_all --ca mesh_ca --custom_overlay $PROJDIR/tracing.yaml --option legacy-default-ingressgateway
    echo
    echo "$ kubectl create namespace istio-gateway # to create namespace"
    kubectl create namespace istio-gateway 2>/dev/null
    export ASM_REVISION=$(kubectl get deploy -n istio-system -l app=istiod -o jsonpath={.items[*].metadata.labels.'istio\.io\/rev'}'{"\n"}')
    echo
    echo "$ kubectl label namespace istio-gateway istio.io/rev=$ASM_REVISION --overwrite # to label namespace" | pv -qL 100
    kubectl label namespace istio-gateway istio.io/rev=$ASM_REVISION --overwrite
    echo
    echo "$ kubectl -n istio-gateway apply -f $PROJDIR/anthos-service-mesh-packages/samples/gateways/istio-ingressgateway # to install ingress gateway" | pv -qL 100
    kubectl -n istio-gateway apply -f $PROJDIR/anthos-service-mesh-packages/samples/gateways/istio-ingressgateway
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},4x"   
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1 
    gcloud config set compute/zone $GCP_ZONE > /dev/null 2>&1 
    kubectl config use-context gke_${GCP_PROJECT}_${GCP_ZONE}_${GCP_CLUSTER} > /dev/null 2>&1 
    gcloud --project $GCP_PROJECT container clusters get-credentials $GCP_CLUSTER --zone $GCP_ZONE > /dev/null 2>&1 
    export CLUSTER_LOCATION=$GCP_ZONE
    echo
    echo "$ kubectl delete controlplanerevision -n istio-system # to remove ControlPlaneRevision resources" | pv -qL 100
    kubectl delete controlplanerevision -n istio-system
    echo
    echo "$ kubectl delete validatingwebhookconfiguration,mutatingwebhookconfiguration -l operator.istio.io/component=Pilot # to remove webhooks" | pv -qL 100
    kubectl delete validatingwebhookconfiguration,mutatingwebhookconfiguration -l operator.istio.io/component=Pilot
    echo
    echo "$ $PROJDIR/istio-$ASM_VERSION/bin/istioctl x uninstall --purge # to remove the in-cluster control plane" | pv -qL 100
    $PROJDIR/istio-$ASM_VERSION/bin/istioctl x uninstall --purge
    echo && echo
    echo "$  kubectl delete namespace istio-system asm-system istio-gateway --ignore-not-found=true # to remove namespace" | pv -qL 100
     kubectl delete namespace istio-system asm-system istio-gateway --ignore-not-found=true
else
    export STEP="${STEP},4i"
    echo
    echo "1. Retrieve the credentials for cluster" | pv -qL 100
    echo "2. Configure Istio Operator" | pv -qL 100
    echo "3. Install Anthos Service Mesh" | pv -qL 100
    echo "4. Create and label namespace" | pv -qL 100
    echo "5. Enable in-cluster control plane" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"5")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},5i"
    echo
    echo "$ kubectl label namespace default istio-injection- istio.io/rev=\$ASM_REVISION --overwrite # to label namespace for model" | pv -qL 100
    echo
    echo "$ kubectl apply -f \$PROJDIR/tfserving-canary/tf-serving/configmap-resnet50.yaml # to create ConfigMap" | pv -qL 100
    echo
    echo "$ kubectl apply -f \$PROJDIR/tfserving-canary/tf-serving/deployment-resnet50.yaml # to create ResNet50 TensorFlow Serving model" | pv -qL 100
    echo
    echo "$ kubectl apply -f \$PROJDIR/tfserving-canary/tf-serving/service.yaml # to create service" | pv -qL 100
    echo
    echo "$ kubectl apply -f \$PROJDIR/tfserving-canary/tf-serving/gateway.yaml # to install an ingress gateway" | pv -qL 100
    echo
    echo "$ kubectl apply -f \$PROJDIR/tfserving-canary/tf-serving/virtualservice.yaml # to create the virtual service" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},5"
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1 
    gcloud config set compute/zone $GCP_ZONE > /dev/null 2>&1 
    kubectl config use-context gke_${GCP_PROJECT}_${GCP_ZONE}_${GCP_CLUSTER} > /dev/null 2>&1 
    gcloud --project $GCP_PROJECT container clusters get-credentials $GCP_CLUSTER --zone $GCP_ZONE > /dev/null 2>&1 
    echo
    echo "$ gsutil mb gs://${GCP_PROJECT}-bucket # to create a storage bucket" | pv -qL 100
    gsutil mb gs://${GCP_PROJECT}-bucket
    echo
    echo "$ gsutil cp -r gs://spls/gsp778/resnet_101 gs://${GCP_PROJECT}-bucket # to copy the model files" | pv -qL 100
    gsutil cp -r gs://spls/gsp778/resnet_101 gs://${GCP_PROJECT}-bucket
    echo
    echo "$ gsutil cp -r gs://spls/gsp778/resnet_50 gs://${GCP_PROJECT}-bucket # to copy the model files" | pv -qL 100
    gsutil cp -r gs://spls/gsp778/resnet_50 gs://${GCP_PROJECT}-bucket
    echo
    echo "$ gsutil uniformbucketlevelaccess set on gs://${GCP_PROJECT}-bucket # to ensure that uniform bucket-level access" | pv -qL 100
    gsutil uniformbucketlevelaccess set on gs://${GCP_PROJECT}-bucket
    echo
    echo "$ gsutil iam ch allUsers:objectViewer gs://${GCP_PROJECT}-bucket # to ensure that uniform bucket-level access" | pv -qL 100
    gsutil iam ch allUsers:objectViewer gs://${GCP_PROJECT}-bucket
    echo
    echo "$ sed -i \"s@\[YOUR_BUCKET\]@${GCP_PROJECT}-bucket@g\" $PROJDIR/tfserving-canary/tf-serving/configmap-resnet50.yaml # to update MODEL_NAME  to reference bucket" | pv -qL 100
    sed -i "s@\[YOUR_BUCKET\]@${GCP_PROJECT}-bucket@g" $PROJDIR/tfserving-canary/tf-serving/configmap-resnet50.yaml
    echo
    echo "$ kubectl label namespace default istio-injection- istio.io/rev=$ASM_REVISION --overwrite # to label namespace for model" | pv -qL 100
    kubectl label namespace default istio-injection- istio.io/rev=$ASM_REVISION --overwrite
    echo
    echo "$ kubectl apply -f $PROJDIR/tfserving-canary/tf-serving/configmap-resnet50.yaml # to create ConfigMap" | pv -qL 100
    kubectl apply -f $PROJDIR/tfserving-canary/tf-serving/configmap-resnet50.yaml
    echo
    echo "$ kubectl apply -f $PROJDIR/tfserving-canary/tf-serving/deployment-resnet50.yaml # to create ResNet50 TensorFlow Serving model" | pv -qL 100
    kubectl apply -f $PROJDIR/tfserving-canary/tf-serving/deployment-resnet50.yaml
    echo
    echo "$ kubectl apply -f $PROJDIR/tfserving-canary/tf-serving/service.yaml # to create service" | pv -qL 100
    kubectl apply -f $PROJDIR/tfserving-canary/tf-serving/service.yaml
    echo
    echo "$ kubectl wait --for=condition=available --timeout=600s deployment --all  # to wait for the deployment to finish" | pv -qL 100
    kubectl wait --for=condition=available --timeout=600s deployment --all
    echo
    echo "$ kubectl apply -f $PROJDIR/tfserving-canary/tf-serving/gateway.yaml # to install an ingress gateway" | pv -qL 100
    kubectl apply -f $PROJDIR/tfserving-canary/tf-serving/gateway.yaml
    echo
    echo "$ kubectl apply -f $PROJDIR/tfserving-canary/tf-serving/virtualservice.yaml # to create the virtual service" | pv -qL 100
    kubectl apply -f $PROJDIR/tfserving-canary/tf-serving/virtualservice.yaml
    echo
    sleep 5
    export INGRESS_HOST=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    export INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].port}')
    export GATEWAY_URL=$INGRESS_HOST:$INGRESS_PORT
    echo "$ curl -d @$PROJDIR/tfserving-canary/payloads/request-body.json -X POST http://$GATEWAY_URL/v1/models/image_classifier:predict # to send request to the model and review military uniform label probability" | pv -qL 100
    curl -d @$PROJDIR/tfserving-canary/payloads/request-body.json -X POST http://$GATEWAY_URL/v1/models/image_classifier:predict
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},5x"
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1 
    gcloud config set compute/zone $GCP_ZONE > /dev/null 2>&1 
    kubectl config use-context gke_${GCP_PROJECT}_${GCP_ZONE}_${GCP_CLUSTER} > /dev/null 2>&1 
    gcloud --project $GCP_PROJECT container clusters get-credentials $GCP_CLUSTER --zone $GCP_ZONE > /dev/null 2>&1 
    echo
    echo "$ gcloud storage rm --recursive gs://${GCP_PROJECT}-bucket # to delete storage bucket" | pv -qL 100
    gcloud storage rm --recursive gs://${GCP_PROJECT}-bucket
    echo
    echo "$ kubectl delete -f $PROJDIR/tfserving-canary/tf-serving/configmap-resnet50.yaml # to delete ConfigMap" | pv -qL 100
    kubectl delete -f $PROJDIR/tfserving-canary/tf-serving/configmap-resnet50.yaml
    echo
    echo "$ kubectl delete -f $PROJDIR/tfserving-canary/tf-serving/deployment-resnet50.yaml # to delete ResNet50 TensorFlow Serving model" | pv -qL 100
    kubectl delete -f $PROJDIR/tfserving-canary/tf-serving/deployment-resnet50.yaml
    echo
    echo "$ kubectl delete -f $PROJDIR/tfserving-canary/tf-serving/service.yaml # to delete service" | pv -qL 100
    kubectl delete -f $PROJDIR/tfserving-canary/tf-serving/service.yaml
    echo
    echo "$ kubectl delete -f $PROJDIR/tfserving-canary/tf-serving/gateway.yaml # to delete ingress gateway" | pv -qL 100
    kubectl delete -f $PROJDIR/tfserving-canary/tf-serving/gateway.yaml
    echo
    echo "$ kubectl delete -f $PROJDIR/tfserving-canary/tf-serving/virtualservice.yaml # to delete virtual service" | pv -qL 100
    kubectl delete -f $PROJDIR/tfserving-canary/tf-serving/virtualservice.yaml
else
    export STEP="${STEP},5i"
    echo
    echo "1. Deploy ResNet models using TensorFlow Serving" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"6")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},6i"
    echo
    echo "$ kubectl apply -f \$PROJDIR/tfserving-canary/tf-serving/destinationrule.yaml # to configure subsets of image-classifier service" | pv -qL 100
    echo
    echo "$ kubectl apply -f \$PROJDIR/tfserving-canary/tf-serving/virtualservice-weight-100.yaml # to route all requests from the Ingress gateway to the resnet50 service subset" | pv -qL 100
    echo
    echo "$ kubectl apply -f \$PROJDIR/tfserving-canary/tf-serving/configmap-resnet101.yaml # to update configmap" | pv -qL 100
    echo
    echo "$ kubectl apply -f \$PROJDIR/tfserving-canary/tf-serving/deployment-resnet101.yaml # to update deployment" | pv -qL 100
    echo
    echo "$ kubectl apply -f \$PROJDIR/tfserving-canary/tf-serving/virtualservice-weight-70.yaml # to reconfigure the virtual service to split traffic between ResNet50 and ResNet101 models using weighted load balancing - 70% requests to ResNet50 (~45% probability for military uniform) and 30% to ResNet101 (~94% probability for military uniform)" | pv -qL 100
    echo
    echo "$ kubectl apply -f \$PROJDIR/tfserving-canary/tf-serving/virtualservice-weight-100.yaml # to reconfigure the virtual service to route 100% requests to ResNet50" | pv -qL 100
    echo
    echo "$ kubectl apply -f \$PROJDIR/tfserving-canary/tf-serving/virtualservice-focused-routing.yaml # to reconfigure the virtual service to route traffic to the canary deployment based on request headers" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},6"
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1 
    gcloud config set compute/zone $GCP_ZONE > /dev/null 2>&1 
    kubectl config use-context gke_${GCP_PROJECT}_${GCP_ZONE}_${GCP_CLUSTER} > /dev/null 2>&1 
    gcloud --project $GCP_PROJECT container clusters get-credentials $GCP_CLUSTER --zone $GCP_ZONE > /dev/null 2>&1 
    export INGRESS_HOST=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    export INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].port}')
    export GATEWAY_URL=$INGRESS_HOST:$INGRESS_PORT
    echo
    echo "$ kubectl apply -f $PROJDIR/tfserving-canary/tf-serving/destinationrule.yaml # to configure subsets of image-classifier service" | pv -qL 100
    kubectl apply -f $PROJDIR/tfserving-canary/tf-serving/destinationrule.yaml
    echo
    echo "$ kubectl apply -f $PROJDIR/tfserving-canary/tf-serving/virtualservice-weight-100.yaml # to route all requests from the Ingress gateway to the resnet50 service subset" | pv -qL 100
    kubectl apply -f $PROJDIR/tfserving-canary/tf-serving/virtualservice-weight-100.yaml
    echo
    echo "$ sed -i \"s@\[YOUR_BUCKET\]@${GCP_PROJECT}-bucket@g\" $PROJDIR/tfserving-canary/tf-serving/configmap-resnet101.yaml # to update MODEL_NAME  to reference bucket" | pv -qL 100
    sed -i "s@\[YOUR_BUCKET\]@${GCP_PROJECT}-bucket@g" $PROJDIR/tfserving-canary/tf-serving/configmap-resnet101.yaml
    echo
    echo "$ kubectl apply -f $PROJDIR/tfserving-canary/tf-serving/configmap-resnet101.yaml # to update configmap" | pv -qL 100
    kubectl apply -f $PROJDIR/tfserving-canary/tf-serving/configmap-resnet101.yaml
    echo
    echo "$ kubectl apply -f $PROJDIR/tfserving-canary/tf-serving/deployment-resnet101.yaml # to update deployment" | pv -qL 100
    kubectl apply -f $PROJDIR/tfserving-canary/tf-serving/deployment-resnet101.yaml
    echo
    echo "$ kubectl wait --for=condition=available --timeout=600s deployment --all  # to wait for the deployment to finish" | pv -qL 100
    kubectl wait --for=condition=available --timeout=600s deployment --all
    sleep 5
    echo
    echo "$ curl -d @$PROJDIR/tfserving-canary/payloads/request-body.json -X POST http://$GATEWAY_URL/v1/models/image_classifier:predict # to send request to the model and review military uniform label probability" | pv -qL 100
    curl -d @$PROJDIR/tfserving-canary/payloads/request-body.json -X POST http://$GATEWAY_URL/v1/models/image_classifier:predict
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***' | pv -qL 100
    echo && echo
    echo "$ kubectl apply -f $PROJDIR/tfserving-canary/tf-serving/virtualservice-weight-70.yaml # to reconfigure the virtual service to split traffic between ResNet50 and ResNet101 models using weighted load balancing - 70% requests to ResNet50 (~45% probability for military uniform) and 30% to ResNet101 (~94% probability for military uniform)" | pv -qL 100
    kubectl apply -f $PROJDIR/tfserving-canary/tf-serving/virtualservice-weight-70.yaml
    sleep 3
    echo
    echo "$ for i in \`seq 1 10\`; do curl -d @$PROJDIR/tfserving-canary/payloads/request-body.json -X POST http://$GATEWAY_URL/v1/models/image_classifier:predict; done # to send 15 requests to the model and review military uniform label probability" | pv -qL 100
    for i in `seq 1 15`; do curl -d @$PROJDIR/tfserving-canary/payloads/request-body.json -X POST http://$GATEWAY_URL/v1/models/image_classifier:predict; done
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***' | pv -qL 100
    echo && echo
    echo "$ kubectl apply -f $PROJDIR/tfserving-canary/tf-serving/virtualservice-weight-100.yaml # to reconfigure the virtual service to route 100% requests to ResNet50" | pv -qL 100
    kubectl apply -f $PROJDIR/tfserving-canary/tf-serving/virtualservice-weight-100.yaml
    sleep 3
    echo
    echo "$ for i in \`seq 1 10\`; do curl -d @$PROJDIR/tfserving-canary/payloads/request-body.json -X POST http://$GATEWAY_URL/v1/models/image_classifier:predict; done # to send 15 requests to the model and review military uniform label probability" | pv -qL 100
    for i in `seq 1 15`; do curl -d @$PROJDIR/tfserving-canary/payloads/request-body.json -X POST http://$GATEWAY_URL/v1/models/image_classifier:predict; done
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***' | pv -qL 100
    echo && echo
    echo "$ kubectl apply -f $PROJDIR/tfserving-canary/tf-serving/virtualservice-focused-routing.yaml # to reconfigure the virtual service to route traffic to the canary deployment based on request headers" | pv -qL 100
    kubectl apply -f $PROJDIR/tfserving-canary/tf-serving/virtualservice-focused-routing.yaml
    echo
    echo "$ kubectl wait --for=condition=available --timeout=600s deployment --all  # to wait for the deployment to finish" | pv -qL 100
    kubectl wait --for=condition=available --timeout=600s deployment --all
    echo
    echo "$ for i in \`seq 1 10\`; do curl -d @$PROJDIR/tfserving-canary/payloads/request-body.json -X POST http://$GATEWAY_URL/v1/models/image_classifier:predict; done # to send 15 requests to the model and review military uniform label probability (~45%)" | pv -qL 100
    for i in `seq 1 15`; do curl -d @$PROJDIR/tfserving-canary/payloads/request-body.json -X POST http://$GATEWAY_URL/v1/models/image_classifier:predict; done
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***' | pv -qL 100
    echo && echo
    echo "$ for i in \`seq 1 15\`; curl -d @$PROJDIR/tfserving-canary/payloads/request-body.json -H \"user-group: canary\" -X POST http://$GATEWAY_URL/v1/models/image_classifier:predict; done # to send 15 requests with the user-group header set to canary and review military uniform label probability (~94%)" | pv -qL 100
    for i in `seq 1 15`; do curl -d @$PROJDIR/tfserving-canary/payloads/request-body.json -H "user-group: canary" -X POST http://$GATEWAY_URL/v1/models/image_classifier:predict; done
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},6x"
    echo
    echo "$ kubectl delete -f $PROJDIR/tfserving-canary/tf-serving/destinationrule.yaml # to delete service" | pv -qL 100
    kubectl delete -f $PROJDIR/tfserving-canary/tf-serving/destinationrule.yaml
    echo
    echo "$ kubectl delete -f $PROJDIR/tfserving-canary/tf-serving/virtualservice-weight-100.yaml # to delete subset" | pv -qL 100
    kubectl delete -f $PROJDIR/tfserving-canary/tf-serving/virtualservice-weight-100.yaml
    echo
    echo "$ kubectl delete -f $PROJDIR/tfserving-canary/tf-serving/configmap-resnet101.yaml # to delete configmap" | pv -qL 100
    kubectl delete -f $PROJDIR/tfserving-canary/tf-serving/configmap-resnet101.yaml
    echo
    echo "$ kubectl delete -f $PROJDIR/tfserving-canary/tf-serving/deployment-resnet101.yaml # to delete deployment" | pv -qL 100
    kubectl delete -f $PROJDIR/tfserving-canary/tf-serving/deployment-resnet101.yaml
    echo
    echo "$ kubectl delete -f $PROJDIR/tfserving-canary/tf-serving/virtualservice-weight-70.yaml # to delete virtual service" | pv -qL 100
    kubectl delete -f $PROJDIR/tfserving-canary/tf-serving/virtualservice-weight-70.yaml
    echo
    echo "$ kubectl delete -f $PROJDIR/tfserving-canary/tf-serving/virtualservice-weight-100.yaml # to delete virtual service" | pv -qL 100
    kubectl delete -f $PROJDIR/tfserving-canary/tf-serving/virtualservice-weight-100.yaml
    echo
    echo "$ kubectl delete -f $PROJDIR/tfserving-canary/tf-serving/virtualservice-focused-routing.yaml # to delete virtual service" | pv -qL 100
    kubectl delete -f $PROJDIR/tfserving-canary/tf-serving/virtualservice-focused-routing.yaml
else
    export STEP="${STEP},6i"
    echo
    echo "1. Configure weighted load balancing and focused canary testing" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"R")
echo
echo "
  __                      __                              __                               
 /|            /         /              / /              /                 | /             
( |  ___  ___ (___      (___  ___        (___           (___  ___  ___  ___|(___  ___      
  | |___)|    |   )     |    |   )|   )| |    \   )         )|   )|   )|   )|   )|   )(_/_ 
  | |__  |__  |  /      |__  |__/||__/ | |__   \_/       __/ |__/||  / |__/ |__/ |__/  / / 
                                 |              /                                          
"
echo "
We are a group of information technology professionals committed to driving cloud 
adoption. We create cloud skills development assets during our client consulting 
engagements, and use these assets to build cloud skills independently or in partnership 
with training organizations.
 
You can access more resources from our iOS and Android mobile applications.

iOS App: https://apps.apple.com/us/app/tech-equity/id1627029775
Android App: https://play.google.com/store/apps/details?id=com.techequity.app

Email:support@techequity.cloud 
Web: https://techequity.cloud

Ⓒ Tech Equity 2022" | pv -qL 100
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"G")
cloudshell launch-tutorial $SCRIPTPATH/.tutorial.md
;;

"Q")
echo
exit
;;
"q")
echo
exit
;;
* )
echo
echo "Option not available"
;;
esac
sleep 1
done
