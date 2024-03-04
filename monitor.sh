#!/bin/bash
#
#
#


function analize {
    totcpu=0
    totmem=0
    count=0
    maxcpu=0
    maxmem=0
    for pod in $1; do
        CPU=$(echo $pod | awk -F'::' '{print $2}')
        CPU=${CPU%m}
        MEM=$(echo $pod | awk -F'::' '{print $3}')
        MEM=${MEM%Mi}
        ((totcpu+=CPU))
        ((totmem+=MEM))
        ((count+=1))
        if [ $maxcpu -le $CPU ]; then
            maxcpu=$CPU
        fi
        if [ $maxmem -le $MEM ]; then
            maxmem=$MEM
        fi
    done
    if [ $count -ne 0 ]; then
        avgcpu=$(echo "$totcpu/$count" | bc -l)
        avgmem=$(echo "$totmem/$count" | bc -l)
        echo "$avgcpu::$avgmem::$maxcpu::$maxmem::$count"
    else
        echo "0::0::0::0::0"
    fi
}

function filter {
    DEPLOYMENT=$1
    TOP=$2
    LIST=""
    for pod in $(echo $TOP); do
        if [ -n "$(echo $pod | grep $DEPLOYMENT)" ]; then
            LIST=$(echo $LIST " " $pod)
        fi
    done
    echo $LIST
}

function index_list {
    DEP=$1
    NAME_DEP=$2
    i=0
    #echo "index_list", $DEP, ${NAME_DEP[@]}
    while [ $DEP != ${NAME_DEP[$i]} ]; do
        #echo ${NAME_DEP[$i]}
        ((i++))
    done
    return $i
}

function calculate {
    L1=$1
    L2=$2
    weight=$(($3 - 1))
    avgcpu1=$(echo $L1 | awk -F'::' '{print $1}')
    avgcpu2=$(echo $L2 | awk -F'::' '{print $1}')
    avgmem1=$(echo $L1 | awk -F'::' '{print $2}')
    avgmem2=$(echo $L2 | awk -F'::' '{print $2}')
    maxcpu1=$(echo $L1 | awk -F'::' '{print $3}')
    maxcpu2=$(echo $L2 | awk -F'::' '{print $3}')
    maxmem1=$(echo $L1 | awk -F'::' '{print $4}')
    maxmem2=$(echo $L2 | awk -F'::' '{print $4}')
    cant1=$(echo $L1 | awk -F'::' '{print $5}')
    cant2=$(echo $L2 | awk -F'::' '{print $5}')
    cant=$(echo "$cant1+$cant2*$weight" | bc -l)
    avgcpu=$(echo "($avgcpu1*$cant1+$avgcpu2*$cant2*$weight)/$cant" | bc -l)
    avgmem=$(echo "($avgmem1*$cant1+$avgmem2*$cant2*$weight)/$cant" | bc -l)
    cant=$(echo "$cant/($weight+1)" | bc -l)
    # condition && do is true || do is false
    [ $maxcpu1 -le $maxcpu2 ] && maxcpu=$maxcpu2 || maxcpu=$maxcpu1
    [ $maxmem1 -le $maxmem2 ] && maxmem=$maxmem2 || maxmem=$maxmem1
    echo "$avgcpu::$avgmem::$maxcpu::$maxmem::$cant"
}

function list2str {
    array1=$1
    string=""
    for elem in "${array1[@]}"; do
        string=$(echo "$string//$elem")
    done
    echo $string
}

function show {
    echo ""
    echo $1 \
    | tail -n 1 \
    | sed "s|//|\n|g" \
    | awk -F'::' '{printf "%s %.2f %.2f %.0f %.0f %.2f\n", $1, $2, $3, $4, $5, $6 }' \
    | column -t -R 2,3,4,5,6 -N DEPLOY,AVG-CPU,AVG-MEM,MAX-CPU,MAX-MEM,PODS
}

function clean_echo {
    echo -e "\r\c"
    echo -ne "                 "
    echo -e "\r\c"
    echo -ne "$1"
}

function main {
    ####### ----- REGIN INIT BLOK
    TMP=$(mktemp)
    echo "tmp-file: $TMP"
    DT1=$(date +%Y%m%d-%H.%M.%S)
    MINUTES=$1
    WORKCONTEXT=$2
    NS=$3
    CONTEXT1=$(kubectx -c)
    WAITING=10
    _=$(kubectx ${WORKCONTEXT})
    DEPLOYMENT=$(kubectl -n ${NS} get deployments.apps | grep -v NAME | awk '{print $1}')
    ENE=$(echo "$MINUTES*60/($WAITING+2.59)" | bc -l | xargs printf "%.0f") # Aprox. 2.59 seconds per cicle
    i=0
    ND="//"
    for DEP in $DEPLOYMENT; do
        NAME_DEP[$i]="$DEP"
        [ $ND = "//" ] && ND="$DEP" || ND=$(echo "$ND//$DEP")
        LIST[$i]="0::0::0::0::0"
        ((i++))
    done
    ####### ----- END INIT BLOK
    for COUNT in $(seq 1 $ENE); do
        echo -ne "ciclo: $COUNT de $ENE\nget top pod..."
        CONTEXT1=$(kubectx -c)
        [[ "$CONTEXT1" != "$WORKCONTEXT" ]] && _=$(kubectx ${WORKCONTEXT})
        TOP=$(kubectl -n ${NS} top pod | grep -v NAME | awk '{print $1 "::" $2 "::" $3}')
        [[ "$CONTEXT1" != "$WORKCONTEXT" ]] && _=$(kubectx ${CONTEXT1})
        clean_echo "process"
        LV="//"
        for DEP in $DEPLOYMENT; do
            echo -ne "."
            index_list $DEP "${NAME_DEP[@]}"
            i=$?
            POD=$(filter $DEP "$TOP")
            VALUES=$(analize "$POD")
            VALUES=$(calculate $VALUES ${LIST[$i]} $COUNT)
            LIST[$i]="$VALUES"
            [ $LV = "//" ] && LV="$DEP::$VALUES" || LV="$LV//$DEP::$VALUES"
        done
        echo $LV > $TMP
        if [[ $COUNT -ne $ENE ]]; then
            clean_echo "waiting" 
            for i in $(seq 1 ${WAITING}); do
                sleep 1
                echo -ne "."
            done
        fi
        clean_echo "\033[1A\033[s"
    done
    clean_echo "\033[2A\033[s"
    show $LV
    DT2=$(date +%Y%m%d-%H.%M.%S)
    echo -e "Begin:\t$DT1\nEnd:\t$DT2" > ~/$DT1--$DT2.txt
    echo -e "Context: $WORKCONTEXT\nNamespace: $NS" >> ~/$DT1--$DT2.txt
    show $LV >> ~/$DT1--$DT2.txt
    mv $TMP ~/$DT1--$DT2.data
}

function menu {
    VAR=$1
    TEXT=$2
    options=$3
    echo "$TEXT"
    n=1
    for i in $options; do
        echo -e "\t$n.\t$i"
        ((n++))
    done
    while [ 1 = 1 ]; do
        read -p "Enter your option : " OPT
        [[ $OPT =~ ^[0-9]+$ ]] && { \
            [ $OPT > 0 ] && { [ $n > $OPT ] && break || echo "It must be between 0 and $(($n -1))"; } \
            || echo "It must be between 0 and $(($n -1))"; \
        } || echo "It's not a number"
    done
    n=1
    for i in $options; do
        LTMP=$i
        [ $n = $OPT ] && break || ((n++))
    done
    clear
    eval "$VAR=\"$LTMP\""
}

# READ Context
clear
options=$(kubectx)
menu WORKCONTEXT "Select a context" "$options"
echo "New Context: $WORKCONTEXT"

# READ NAMESPACE
CONTEXT0=$(kubectx -c)
_=$(kubectx ${WORKCONTEXT})
NS=$(kubectl get ns | grep -v NAME | awk '{print $1}')
_=$(kubectx ${CONTEXT0})
menu NAMESPACE "Select a namespace:" "$NS"
clear
echo "Namespace: $NAMESPACE by $WORKCONTEXT"

# READ MINUTES
while [ 1 = 1 ]; do
    read -p "Enter minutes : " MINUTES
    [[ $MINUTES =~ ^[0-9]+$ ]] && { \
        [ $MINUTES > 0 ] && break \
        || echo "Must be greater than zero"; \
    } || echo -e "It\'s not a number"
done
clear

echo "Working in namespace \"$NAMESPACE\" of \"$WORKCONTEXT\" by \"$MINUTES\" minutes"
main $MINUTES "$WORKCONTEXT" "$NAMESPACE"
