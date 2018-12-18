#!/usr/bin/ksh
#@Description:Get Cod Power Enterprise pool information
#@Author: wclo4,2018-11-13
#@Copyright: wclo4

if [ $# -ne 1  ];then  
   echo "\t\n****** ERROR,NO PARAMETER! ******\n"
   echo "\tUsage:  getcodpool \$hmcIP"
   echo "\t\tPlease input a HMC_IP_ADDRESS after the script!" 
   echo "\tExample:getcodpool 146.248.255.241\n"  
   exit -1
fi

hmcIP=$1
>/nimshl/wclo4/${hmcIP}.info  >/dev/null 2>&1
>/nimshl/wclo4/${hmcIP}.trnout  >/dev/null 2>&1
>/nimshl/wclo4/${hmcIP}.tmp2  >/dev/null 2>&1

srvMacCMP1=`ssh hscroot@$hmcIP lssyscfg -r sys -F name`
ssh hscroot@$hmcIP lscodpool -p "CUP Pool" --level sys -F  name,installed_procs,non_mobile_procs,mobile_procs,inactive_procs | sort -k1nr > /nimshl/wclo4/${hmcIP}.tmp1

ScupPEpermProc=`grep ^870 /nimshl/wclo4/${hmcIP}.tmp1|awk -F\, '{print $3}'`
ScupPEmobProc=`grep ^870 /nimshl/wclo4/${hmcIP}.tmp1|awk -F\, '{print $4}'`
ScupPHpermProc=`grep ^PH /nimshl/wclo4/${hmcIP}.tmp1|awk -F\, '{print $3}'`
ScupPHmobProc=`grep ^PH /nimshl/wclo4/${hmcIP}.tmp1|awk -F\, '{print $4}'`
BcupPEpermProc=`grep ^Server /nimshl/wclo4/${hmcIP}.tmp1|awk -F\, '{print $3}'`
BcupPEmobProc=`grep ^Server /nimshl/wclo4/${hmcIP}.tmp1|awk -F\, '{print $4}'`
ttlScupPEpermProc=0;for vartmp1 in $ScupPEpermProc;do ((ttlScupPEpermProc+=$vartmp1));done
ttlScupPEmobProc=0;for vartmp2 in $ScupPEmobProc;do ((ttlScupPEmobProc+=$vartmp2));done
ttlScupPHpermProc=0;for vartmp3 in $ScupPHpermProc;do ((ttlScupPHpermProc+=$vartmp3));done
ttlScupPHmobProc=0;for vartmp4 in $ScupPHmobProc;do ((ttlScupPHmobProc+=$vartmp4));done
ttlBcupPEpermProc=0;for vartmp5 in $BcupPEpermProc;do ((ttlBcupPEpermProc+=$vartmp5));done
ttlBcupPEmobProc=0;for vartmp6 in $BcupPEmobProc;do ((ttlBcupPEmobProc+=$vartmp6));done

ttlCUPpermProcs=`ssh hscroot@$hmcIP lscodpool --level pool -p "CUP Pool" -F mobile_procs`
ttlCUPavailProcs=`ssh hscroot@$hmcIP lscodpool --level pool -p "CUP Pool" -F avail_mobile_procs`
ttlCUPinuseProcs=`expr $ttlCUPpermProcs - $ttlCUPavailProcs`

echo "\tttlCUPpermProcs=$ttlCUPpermProcs
\tttlCUPinuseProcs=$ttlCUPinuseProcs
\tttlCUPavailProcs=$ttlCUPavailProcs\n
\tttlScupPEpermProc=$ttlScupPEpermProc
\tttlScupPEmobProc=$ttlScupPEmobProc\n
\tttlScupPHpermProc=$ttlScupPHpermProc
\tttlScupPHmobProc=$ttlScupPHmobProc\n
\tttlBcupPEpermProc=$ttlBcupPEpermProc  
\tttlBcupPEmobProc=$ttlBcupPEmobProc" >${hmcIP}.ttl
           
for srvMac in $srvMacCMP1;do
        grep $srvMac /nimshl/wclo4/${hmcIP}.tmp1 >> /nimshl/wclo4/${hmcIP}.info
done

for srvMacCMP2 in `cat /nimshl/wclo4/${hmcIP}.info|awk -F\, '{print $1}'`;do
        sysTrialCPU=`ssh hscroot@$hmcIP lscod -t cap  -m $srvMacCMP2 -c trial -r proc -F activated_trial_procs`
        sysCPU=`ssh hscroot@$hmcIP lshwres -r proc -m $srvMacCMP2 --level sys -F configurable_sys_proc_units,curr_avail_sys_proc_units`
        sysMem=`ssh hscroot@$hmcIP lshwres -r mem -m $srvMacCMP2 --level sys -F configurable_sys_mem,curr_avail_sys_mem`
        echo $sysTrialCPU,$sysCPU,$sysMem >> /nimshl/wclo4/${hmcIP}.tmp2
done

sed 's/^/,/g' ${hmcIP}.tmp2 > ${hmcIP}.trnout
paste /nimshl/wclo4/${hmcIP}.info /nimshl/wclo4/${hmcIP}.trnout|sort -k1nr > ${hmcIP}.detail
printf '%s\n' 0a "name,installed_procs,non_mobile_procs,mobile_procs,inactive_procs,activated_trial_procs,configurable_sys_proc_units,curr_avail_sys_proc_units,configurable_sys_mem,curr_avail_sys_mem" . x|ex ${hmcIP}.detail
