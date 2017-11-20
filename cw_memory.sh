#!/bin/bash
#
#  About                : Check used memory in percentage
#
#  Name                 : cw_memory.sh
#  Author               : Safiur Rehman



DIR=$(dirname $0);
PLUGIN_NAME='cw_memory';

# Include configuration file
source ${DIR}/../conf/plugin.conf;


#Get Current Instance ID
INSTANCE_ID=(`wget -q -O - http://169.254.169.254/latest/meta-data/instance-id`);
#Get Hostname
HOST_ID=(`wget -q -O - http://169.254.169.254/latest/meta-data/hostname`);

# Help
usage() {
        echo "Usage: $0 [-n <Namespace>] [-d <dimension>] [-m <metrics>] " 1>&2;
        exit 1;
}

# Logger
logger(){

 SEVERITY=$1;
 MESSAGE=$2;
 DATE=`date +"[%Y-%b-%d %H:%M:%S.%3N]"`;

 echo -e "${DATE} [${SEVERITY}] [${PLUGIN_NAME}] [${INSTANCE_ID}] [${HOST_ID}] ${MESSAGE}" >> ${DIR}/../logs/tjcwmon.log;

}

# Process Arguments

if [ $# -eq 0 ]; then
        # When no argument is passed
        logger ERROR "Invalid arguments passed";
        usage;
fi


while getopts ":n:d:m:a:" o; do
    case "${o}" in
        n)
            NAMESPACE=${OPTARG}
            if [ -z "${NAMESPACE}" ]; then
		logger ERROR "Invalid Namespace passed";
                usage;
            fi
            ;;
        d)
            DIMENSION=${OPTARG};
            DNAME=${DIMENSION%=*};
            DVALUE=${DIMENSION#*=};

            if [ -z "${DIMENSION}" ] || [ -z "${DNAME}" ] || [ "${DNAME}" == "${DVALUE}" ]; then
		logger ERROR "Invalid dimension passed <${DIMENSION}>";
                usage;
            fi

            # If Dimension name is 'InstanceId' then Value is not required to be passed
            if [ "${DNAME}" != 'InstanceId' ] && [ -z "${DVALUE}" ]; then
		logger ERROR "Invalid dimension passed <${DIMENSION}>";
                usage;
            fi
            ;;
        m)
            METRICS=${OPTARG}
            if [ -z "${METRICS}" ]; then
		logger ERROR "Invalid metrics passed <${METRICS}>";
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
if [ -z "${NAMESPACE}" ] || [ -z "${DNAME}" ] || [ -z "$METRICS" ]; then
    logger ERROR "Invalid arguments passed";
    usage
fi


##########################################################
##########################################################


# If "INSTANCE_ID" is passed as Dimension, then use actual AWS Instanec ID as Dimension
if [ "${DNAME}" == "InstanceId" ]; then
        DVALUE=${INSTANCE_ID};
fi

##########################

UNIT="Percent"

# Get Total Memory
#MEM_TOTAL=$(free -m | grep 'Mem' | awk '{print $2}' 2>&1);
MEM_TOTAL=$(awk '/^MemTotal/ {print $2}' /proc/meminfo 2>&1);

if [ "$?" -ne "0" ]; then
        logger ERROR "${NAMESPACE} ${METRICS} ${DNAME}=${DVALUE} | value=NULL | ${MEM_TOTAL}";
        exit 1;
fi;

MEM_FREE=$(awk '/^MemFree/ {print $2}' /proc/meminfo 2>&1);

if [ "$?" -ne "0" ]; then
        logger ERROR "${NAMESPACE} ${METRICS} ${DNAME}=${DVALUE} | value=NULL | ${MEM_FREE}";
        exit 1;
fi;

MEM_BUFFER=$(awk '/^Buffers/ {print $2}' /proc/meminfo 2>&1);

if [ "$?" -ne "0" ]; then
        logger ERROR "${NAMESPACE} ${METRICS} ${DNAME}=${DVALUE} | value=NULL | ${MEM_BUFFER}";
        exit 1;
fi;

MEM_CACHED=$(awk '/^Cached/ {print $2}' /proc/meminfo 2>&1);

if [ "$?" -ne "0" ]; then
        logger ERROR "${NAMESPACE} ${METRICS} ${DNAME}=${DVALUE} | value=NULL | ${MEM_CACHED}";
        exit 1;
fi;

# Memory Used (In Percentage)
let "VALUE=((MEM_TOTAL - (MEM_FREE + MEM_BUFFER + MEM_CACHED))*100)/MEM_TOTAL";

if [ "$?" -ne "0" ]; then
        logger ERROR "${NAMESPACE} ${METRICS} ${DNAME}=${DVALUE} | value=NULL | ${VALUE}";
        exit 1;
fi;

## Pushing Cloudwatch Metric data
OUTPUT=$(/usr/local/bin/aws cloudwatch put-metric-data --namespace ${NAMESPACE} --metric-name ${METRICS} --dimensions ${DNAME}=${DVALUE} --value ${VALUE} --unit ${UNIT} 2>&1);

if [ "$?" -ne "0" ]; then
        logger ERROR "${NAMESPACE} ${METRICS} ${DNAME}=${DVALUE} | value=${VALUE} unit=${UNIT} | ${OUTPUT}";
        exit 1;
fi;

logger INFO "${NAMESPACE} ${METRICS} ${DNAME}=${DVALUE} | value=${VALUE} unit=${UNIT}";

# Success
exit 0;
