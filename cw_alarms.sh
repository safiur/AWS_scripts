#!/bin/bash
#
#  About                : Create or Delete Cloudwatch alarms
#
#  Name                 : cw_alarms.sh
#  Author               : Safiur Rehman



DIR=$(dirname $0);
PLUGIN_NAME='cw_alarms';

# Include configuration file
source ${DIR}/../conf/plugin.conf;

#Get Current Instance ID
INSTANCE_ID=(`wget -q -O - http://169.254.169.254/latest/meta-data/instance-id`);
#Get Hostname
HOST_ID=(`wget -q -O - http://169.254.169.254/latest/meta-data/hostname`);

# Include Alarm Configuation
source ${DIR}/../conf/alarm.conf;

# Help
usage() {
        echo "Usage: $0 [-a <CREATE | DELETE | PUSH_CREATE>]" 1>&2;
        exit 1;
}

# Logger
logger(){

 SEVERITY=$1;
 MESSAGE=$2;
 DATE=`date +"[%Y-%b-%d %H:%M:%S.%3N]"`;

 echo -e "${DATE} [${SEVERITY}] [${PLUGIN_NAME}] [${INSTANCE_ID}] [${HOST_ID}] ${MESSAGE}" >> ${DIR}/../logs/tjcwmon.log;

}

# Create Alarm
createAlarm(){ 

	TOTAL_ALARMS=${#ALARM_ARRAY[@]};

	COUNT=0
	while [[ $COUNT -lt $TOTAL_ALARMS ]]
	do
	 ALARM=${ALARM_ARRAY[$COUNT]};
	 
	 OUTPUT=$(/usr/local/bin/aws cloudwatch put-metric-alarm $ALARM 2>&1);

	 if [ "$?" -ne "0" ]; then
        	logger ERROR "Failed to Create Alarm | [${COUNT}] ${ALARM} |  ${OUTPUT}";
        	exit 1;
	 fi;

	 logger INFO "Alarm Created Successfully | [${COUNT}] ${ALARM} ";

	 COUNT=$(expr $COUNT + 1);
	done

}


# Delete Alarm
deleteAlarm() {

        TOTAL_ALARMS=${#ALARM_ARRAY[@]};

        COUNT=0
        while [[ $COUNT -lt $TOTAL_ALARMS ]]
        do
         ALARM=$(echo ${ALARM_ARRAY[$COUNT]} | awk '{print $2}');
         OUTPUT=$(/usr/local/bin/aws cloudwatch delete-alarms --alarm-names $ALARM 2>&1);

         if [ "$?" -ne "0" ]; then
                logger ERROR "Failed to delete Alarm | [${COUNT}] ${ALARM} |  ${OUTPUT}";
                exit 1;
         fi;

         logger INFO "Alarm delete Successfully | [${COUNT}] ${ALARM} ";

         COUNT=$(expr $COUNT + 1);
        done

}

# Push Metrices
pushMetrices(){

	OUTPUT=$(${DIR}/../script/push_metrics.sh 2>&1);
	if [ "$?" -ne "0" ]; then
        	logger ERROR "Failed to push metrices | ${OUTPUT}";
	fi;
	
}

if [ $# -eq 0 ]; then
        # When no argument is passed
        logger ERROR "Invalid arguments passed";
        usage;
fi


while getopts ":a:" o; do
    case "${o}" in
        a)
            ACTION=${OPTARG}
	    if [ "${ACTION}" != 'CREATE' ] && [ "${ACTION}" != 'DELETE' ] && [ "${ACTION}" != 'PUSH_CREATE' ]; then
                logger ERROR "Invalid dimension passed <${ACTION}>";
                usage;
            fi
            ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))

# Input Validation
if [ -z "${ACTION}" ]; then
    logger ERROR "Invalid arguments passed";
    usage
fi


#Check if Alarm is not to be created for this VM
CREATE_ALARM=$(/usr/local/bin/aws ec2 describe-tags --filters "Name=resource-id,Values=$INSTANCE_ID" "Name=key,Values=CREATE_ALARM" --output text | cut -f5 2>&1);

if [ "$?" -ne "0" ]; then
        logger ERROR "${CREATE_ALARM}";
        exit 1;
fi;

if [ "$CREATE_ALARM" == "N" ];
then
        logger INFO "CREATE_ALARM Tag is set to 'N'";
        exit 1;
fi;

if [ "${ACTION}" == "CREATE" ];
then
	createAlarm;
fi;

if [ "${ACTION}" == "DELETE" ];
then
        deleteAlarm;
fi;

if [ "${ACTION}" == "PUSH_CREATE" ];
then
        createAlarm;
	sleep 2;
	pushMetrices;
fi;

exit 0;

