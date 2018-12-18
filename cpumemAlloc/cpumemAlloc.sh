#!/usr/bin/ksh

# @description:  This Script is for Power CPU Allocation 
# @example: sh cpumemAlloc.sh $ACTION $hmcIP $serialNum $lparName $setQUANTITY 
# @author: wclo4,20181127
# @version: 2.0
# @modify: 
# @Copyright: wclo4

Usage()
{
	echo "Usage: \n \
  \tsh cpumemAlloc.sh \$ACTION \$hmcIP \$serialNum \$lparName \$setQuantity\n \
  \t\t[ACTION] Add or remove, add/cpu|add/mem|remove/cpu|remove/mem.\n \
  \t\t[hmcIP] Target machine's HMC IP address.\n \
  \t\t[serialNum] Target machine's serial number.\n \
  \t\t[LparName] Which LPAR resource will be modify.\n \
  \t\t[setQuantity] The value of processor or memory to add or remove.\n \
  \t\texample:sh cpumemAlloc.sh add/cpu 146.248.255.241 68EFA37 SHCUONL01 2\n" 
}

hmcIP=$2
serialNum=$3
lparName=$4
setQuantity=$5
minProcs=2
minMems=2048

DATE=$(date +%Y%m%d)
TIME=$(date +%Y%m%d%H%M%S)

if [ $# -ne 5 ];then
   Usage
   exit -1
fi

ACTION=$1
if [[ ${ACTION%%/*} = "add" ]];then
  FLAG=a
  calc="+"
elif [[ ${ACTION%%/*} = "remove" ]];then
  FLAG=r
  calc="-"
else 
  echo "[WARNING]:Unknown action $ACTION!"
  exit -1
fi

trgtMac=$(ssh hscroot@$hmcIP lssyscfg -r sys -F name|grep -i $serialNum)
if [[ $? -ne 0 ]];then
  echo "$TIME : [ERROR] $serialNum is NOT managed by the HMC!"
  exit -1
else
  echo "$TIME : [INFO] $trgtMac is managed by the HMC,continue..."
fi

trgtProf=$(ssh hscroot@$hmcIP lssyscfg -r prof -m $trgtMac -F name|grep $lparName|grep -i default)
instSysProcs=$(ssh hscroot@$hmcIP lshwres -r proc -m $trgtMac --level sys -F installed_sys_proc_units|cut -d. -f1)
availProcs=$(ssh hscroot@$hmcIP lshwres -r proc -m $trgtMac --level sys -F curr_avail_sys_proc_units|cut -d. -f1)
currMinProcs=$(ssh hscroot@$hmcIP lshwres -r proc -m $trgtMac --level lpar --filter "lpar_names=$lparName" -F curr_min_procs)
currProcs=$(ssh hscroot@$hmcIP lshwres -r proc -m $trgtMac --level lpar --filter "lpar_names=$lparName" -F curr_procs)
currMaxProcs=$(ssh hscroot@$hmcIP lshwres -r proc -m $trgtMac --level lpar --filter "lpar_names=$lparName" -F curr_max_procs)
instSysMems=$(ssh hscroot@$hmcIP lshwres -r mem -m $trgtMac --level sys -F installed_sys_mem)
availMems=$(ssh hscroot@$hmcIP lshwres -r mem -m $trgtMac --level sys -F curr_avail_sys_mem)
currMinMems=$(ssh hscroot@$hmcIP lshwres -r mem -m $trgtMac --level lpar --filter "lpar_names=$lparName" -F curr_min_mem)
currMems=$(ssh hscroot@$hmcIP lshwres -r mem -m $trgtMac --level lpar --filter "lpar_names=$lparName" -F curr_mem)
currMaxMems=$(ssh hscroot@$hmcIP lshwres -r mem -m $trgtMac --level lpar --filter "lpar_names=$lparName" -F curr_max_mem)

chgProf()
{
  if [[ $1 = "Procs" ]];then
    desireProcs=$(expr $currProcs $calc $setQuantity)
    #minProcs=$(echo "$desireProcs/2+0.5" | bc -l | cut -d. -f1)
    maxProcs=$(expr $desireProcs \* 2)
    if [[ $maxProcs -ge $instSysProcs ]];then
      maxProcs=$instSysProcs
    fi 	  
    ssh hscroot@$hmcIP "chsyscfg -r prof -m $trgtMac \"name=$trgtProf,lpar_name=$lparName,min_procs=$minProcs,desired_procs=$desireProcs,max_procs=$maxProcs\" --force"
    if [ $? -ne 0 ];then
      echo "$TIME : [ERROR] Failed to edit the default profile,exit..."
      exit -1
    else
      echo "$TIME : [INFO] The value of processor in default profile is now setting to min_procs=$minProcs,desired_procs=$desireProcs,max_procs=$maxProcs,continue.."
    fi
  fi
  if [[ $1 = "Mems" ]];then 
    desireMems=$(echo "$currMems $calc ($setQuantity*1024)"|bc)
    maxMems=$(expr $desireMems \* 2)
      if [[ $maxMems -ge $instSysMems ]];then
        maxMems=$instSysMems
      fi
      ssh hscroot@$hmcIP "chsyscfg -r prof -m $trgtMac -i \"name=$trgtProf,lpar_name=$lparName,min_mem=$minMems,desired_mem=$desireMems,max_mem=$maxMems\" --force"
      if [ $? -ne 0 ];then
        echo "$TIME : [ERROR] Failed to edit the default profile,exit..."
        exit -1
      else
        echo "$TIME : [INFO] The value of memory in default profile is now setting to min_mem=$minMems,desired_mem=$desireMems,max_mem=$maxMems,continue..."
      fi
  fi
}

dlpar()
{
  if [[ $1 = "Procs" ]];then
    ssh hscroot@$hmcIP "chhwres -r proc -m $trgtMac -o $FLAG -p $lparName --procs $setQuantity"
    if [ $? -ne 0 ];then
      echo "$TIME : [ERROR] ACTION: Failed to "$ACTION" $setQuantity procs,exit..."
      exit -1
    else
      echo "$TIME : [INFO] ACTION: "$ACTION" $setQuantity procs successfully,continue..."
    fi 
  fi
  if [[ $1 = "Mems" ]];then 
    ssh hscroot@$hmcIP "chhwres -r mem -m $trgtMac -o $FLAG -p $lparName -q $(expr $setQuantity \* 1024)"
    if [ $? -ne 0 ];then
      echo "$TIME : [ERROR] ACTION: Failed to "$ACTION" $setQuantity mems,exit..."
      exit -1
    else
      echo "$TIME : [INFO] ACTION: "$ACTION" $setQuantity mems successfully,continue..."
    fi   	
  fi
}

#PH-870-3-9119-MME-SN68EFA17,SHCUONL01
case $ACTION in
  "add/cpu")
    isableToAdd=$(expr $availProcs - $setQuantity)
    desireProcs=$(expr $currProcs + $setQuantity)
    if [[ $isableToAdd -ge 0 ]];then
      echo "$TIME : [INFO] Currently available processor supports processor dynamic increase operation.continue..."
      dlpar Procs
      chgProf Procs
    elif [[ $desireProcs -lt $instSysProcs && $desireProcs -gt $currMaxProcs ]];then
      echo "$TIME : [ERROR] The current maximum procs is : $currMaxProcs .After adding $setQuantity procs,the desired procs is bigger than currMaxproc,REBOOT is neccessary to finish the job..."
    elif [[ $desireProcs -gt $instSysProcs ]];then
      echo "$TIME : [ERROR] Failed to add $setQuantity procs,the current installed procs is : $instSysProcs ."
    else
      echo "$TIME : [ERROR] There's no enough resource to finish the job,the current available processor is : $availProcs ,please try again...."
      exit -1
    fi
    ;;
  
  "add/mem")
    wannaAdd=$(expr $setQuantity \* 1024)
    isableToAdd=$(expr $availMems - $wannaAdd)
    desireMems=$(expr $currMems + $wannaAdd)
    if [[ $isableToAdd -ge 0 ]];then
      echo "$TIME : [INFO] Currently available memory supports memory dynamic increase operation.continue..."
      dlpar Mems
      chgProf Mems
    elif [[ $desireMems -lt $instSysMems && $desireMems -gt $currMaxMems ]];then
    echo "$TIME : [ERROR] The current maximum mems is : $currMaxMems .After adding $wannaAdd Mems,the desired Mems is bigger than currMaxMem,REBOOT is neccessary to finish the job..."
    elif [[ $desireMems -gt $instSysMems ]];then
      echo "$TIME : [ERROR] Failed to add $wannaAdd Mems,the current installed mems is : $instSysMems ."
  	else
    	echo "$TIME : [ERROR] There's no enough resource to finish the job,the current available memory is : $availMems ,please try again...."
    	exit -1
    fi  	
    ;;
  
  "remove/cpu")
    isableToRemove=$(expr $currProcs - $setQuantity - $currMinProcs)
    if [[ $isableToRemove -ge 0 ]];then
      echo "$TIME : [INFO] The current procs is able to be removed."			
      dlpar Procs
      chgProf Procs		
    else
      echo "$TIME : [ERROR] The adjusted minimum value is less than the current minimum.U need to modify profile manually & REBOOT $lparName to finish the job,exit..."
      exit -1
    fi  
    ;;
  
  "remove/mem")
    wannaRemove=$(expr $setQuantity \* 1024)
    isableToRemove=$(expr $currMems - $wannaRemove - $currMinMems)
    if [[ $isableToRemove -ge 0 ]];then
      echo "$TIME : [INFO] The current mems is able to be removed."			
      dlpar Mems
      chgProf Mems		
    else
      echo "$TIME : [ERROR] The adjusted minimum value is less than the current minimum.U need to modify profile manually & REBOOT $lparName to finish the job,exit..."
      exit -1
    fi    
    ;;
  
  *)
    Usage
    exit -1
    ;;
esac
