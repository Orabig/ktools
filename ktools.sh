#!/bin/bash

alias k="kubectl"
alias kc="kubectl config"
alias ka="kubectl apply"
alias kg="kubectl get"
alias kgp="kubectl get pods --watch"
alias kd="kubectl delete"
alias kdf="kubectl delete --grace-period=0 --force"

function kdp {
  PODS=$(kubectl get pods | grep Terminating | awk '{print $1}')
  for p in $PODS; do kubectl delete pod $p --grace-period=0 --force;done
}

function kns {
# Fuzzy matches namespace names in the current context for fast namespace switching
# E.g. if "my-hackdays-app-3949-production" is the only app with "hackdays" in the current context,
# `chns hackdays` will switch to it
# Author: Katrina Verey (github.com/KnVerey)

if [ $1 ]; then
  NAMESPACE=$1
else
  name=`basename "$BASH_SOURCE"`
  echo "Usage: $name NAMESPACE"
  kubectl get namespaces
  return;
fi

if ! [ "$(kubectl get namespace ${NAMESPACE} 2>/dev/null)" ]; then
  ALL_NAMESPACES=$(kubectl get namespaces -o=custom-columns=NAME:.metadata.name --no-headers)
  GUESSES=$(echo "$ALL_NAMESPACES" | grep $NAMESPACE) || true
  NUM_GUESSES=$(echo "$GUESSES" | wc -w)

  if [ $NUM_GUESSES -eq 1 ]; then
    NAMESPACE=$GUESSES
  elif [ $NUM_GUESSES -gt 1 ]; then
    echo -e "\033[0;35mName '$NAMESPACE' is ambiguous. Matching namespaces:\033[0m"
    echo "$GUESSES"
    return;
  else
    echo -e "\033[0;31mString '$NAMESPACE' does not match any available namespace.\033[0m"
    return;
  fi
fi

CONTEXT=$(kubectl config current-context)
kubectl config set-context $CONTEXT --namespace=$NAMESPACE >/dev/null
echo "Namespace $NAMESPACE set"
}

function kctx {
# Fuzzy matches available kubernetes context names for fast context switching
# E.g. if "my-context2" is the only context with "2" in its name, `chctx 2` will switch to it
# Optional second argument to switch namespace at the same time using chns
# Author: Katrina Verey (github.com/KnVerey)

# Suggestion: Add the following to your zshrc and install the completions
# To get fast namespace listing and switching via context names
# Warning: Think through your context names first. E.g. if you're using minikube, you'll need to exclude or unalias it
# or else you'll have a conflict with the executable
#
# local contexts; contexts=($(kubectl config get-contexts -o name))
# for context in $contexts; do
#   alias $context="chctx $context"
# done
#

if [ $1 ]; then
  CONTEXT=$1
else
  name=`basename "$BASH_SOURCE"`
  echo "Usage: $name CONTEXT [NAMESPACE]"
  # Petit script perl rigolo qui trie les contextes par nom de CLUSTER, puis LOGIN, puis NAMESPACE
  kubectl config get-contexts | perl -e 'sub K{@_[0]=~/\W+\w\S+\s+/;$'"'"'}sub oncol{K($a) cmp K($b)}print"".<>;print sort oncol($_),<>'
  return;
fi

if ! [ "$(kubectl config get-contexts ${CONTEXT} -o name 2>/dev/null)" ]; then
  ALL_CONTEXTS=$(kubectl config get-contexts -o name)
  GUESSES=$(echo "$ALL_CONTEXTS" | grep $CONTEXT) || true
  NUM_GUESSES=$(echo "$GUESSES" | wc -w)

  if [ $NUM_GUESSES -eq 1 ]; then
    CONTEXT=$GUESSES
  elif [ $NUM_GUESSES -gt 1 ]; then
    echo -e "\033[0;35mName '$CONTEXT' is ambiguous. Matching contexts:\033[0m"
    echo "$GUESSES"
    return;
  else
    echo -e "\033[0;31mString '$CONTEXT' does not match any available context.\033[0m"
    return;
  fi
fi

kubectl config use-context $CONTEXT

if [ $2 ]; then
  kns $2
fi
}


function knfs {
if [ $1 ]; then
  NFS_SERVER=netapp01-data.vitry.exploit.anticorp
  CURRENT_NS=$(kubectl config get-contexts --no-headers | grep '*' | awk '{print $5}')
  kubectl delete -n test pod nfs
  cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: nfs
  namespace: test
spec:
  restartPolicy: Never
  containers:
  - name: main
    image: debian
    command: [ "/bin/bash", "-c", "--" ]
    args: [ "while true; do sleep 30; done;" ]
    securityContext:
      runAsUser: 0
    resources:
      requests:
        cpu: 2
        memory: 4Gi
      limits:
        cpu: 2
        memory: 10Gi
    volumeMounts:
      - name: nfs-mount
        mountPath: "/nfs"
  volumes:
  - name: nfs-mount
    nfs:
      server: $NFS_SERVER
      path: /vol/$1
EOF
  echo test/nfs pod is ready. 
  echo run '>' kubectl exec -it -n test nfs bash

else
  kubectl get pv -o yaml | perl -ne '$\=$/;print $1 if m,path: /vol/(.*)/,' | sort
fi

}

function klogs {
# Logs a pod of the given type in the current context / namespace.
TYPE=$1;
CONTAINER=$2

if ! [ "$TYPE" ]; then
  name=`basename "$BASH_SOURCE"`
  echo "Usage: $name POD_TYPE [CONTAINER]";
  return;
fi

POD=$(kubectl get pods -o=custom-columns=NAME:.metadata.name | grep -i --max-count=1 "^${TYPE}");

if ! [ "$POD" ]; then
  echo "No pods of type ${TYPE} found";
  return;
fi

if [ "$CONTAINER" ]; then
  echo "Logs for $CONTAINER container of pod $POD"
  kubectl logs "$POD" -c=$CONTAINER 
  echo '---- You can follow with :   kubectl logs -f ' $POD ' -c='$CONTAINER 
else
  echo "Logs for pod $POD"
  kubectl logs "$POD" 
  echo '---- You can follow with :   kubectl logs -f ' $POD
fi
}

function kbash {
# Enters a pod of the given type in the current context / namespace.
# Useful for when you want to exec onto (for example) a pod belonging to the "web" deployment
# and you don't care which one.
# Author: Katrina Verey (github.com/KnVerey)

TYPE=$1;
CONTAINER=$2

if ! [ "$TYPE" ]; then
  name=`basename "$BASH_SOURCE"`
  echo "Usage: $name POD_TYPE [CONTAINER]";
  return;
fi

POD=$(kubectl get pods -o=custom-columns=NAME:.metadata.name | grep -i --max-count=1 "^${TYPE}");

if ! [ "$POD" ]; then
  echo "No pods of type ${TYPE} found";
  return;
fi

if [ "$CONTAINER" ]; then
  echo "Entering $CONTAINER container of pod $POD"
  kubectl exec -ti "$POD" -c=$CONTAINER -- bash
else
  echo "Entering pod $POD"
  kubectl exec -ti "$POD" -- bash
fi
}

prompt_kubecontext() {
        echo "%{$fg_bold[cyan]%}⎈ `kubectl config get-contexts --no-headers | grep '*' | awk '{print $3}'`::`kubectl config current-context`/`kubectl config get-contexts --no-headers | grep '*' | awk '{print $5}'`%{$reset_color%}"
}

RPROMPT='$(prompt_kubecontext)'
