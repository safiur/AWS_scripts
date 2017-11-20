#!/bin/bash
#
#  About                : Percent of Disk usage by Mount based on Mount name
#
#  Name                 : cw_diskuage.sh
#  Author               : Safiur rehman



DIR=$(dirname $0);
PLUGIN_NAME='cw_diskusage';

# Include configuration file
source ${DIR}/../conf/plugin.conf;


#Get Current Instance ID
INSTANCE_ID=(`wget -q -O - http://169.254.169.254/latest/meta-data/instance-id`);
#Get Hostname
HOST_ID=(`wget -q -O - http://169.254.169.254/latest/meta-data/hostname`);

# Help
usage() {
        echo "Usage: $0 [-n <Namespace>] [-d <dimension>] [-m <metrics>] [-f Mount Point]" 1>&2;
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


while getopts ":n:d:m:f:" o; do
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
		logger ERROR "Invalid metric passed <${METRICS}>";
                usage;
            fi
            ;;
        f)
            MOUNT_POINT=${OPTARG}
            if [ -z "${MOUNT_POINT}" ]; then
		logger ERROR "Invalid mount point passed <${MOUNT_POINT}>";
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
if [ -z "${NAMESPACE}" ] || [ -z "${DNAME}" ] || [ -z "$METRICS" ] || [ -z "$MOUNT_POINT" ]; then
    logger ERROR "Invalid arguments passed";
    usage
fi


##########################################################
##########################################################


# If "INSTANCE_ID" is passed as Dimension, then use actual AWS Instanec ID as Dimension
if [ "${DNAME}" == "InstanceId" ]; then
        DVALUE=${INSTANCE_ID};
fi


##########################################################

#Check if mount point is valid
if ! grep -qs ${MOUNT_POINT} /proc/mounts; then
    logger ERROR "Mount point <${MOUNT_POINT}> not found";
    exit 1;
fi;

VALUE=$(df "${MOUNT_POINT}" -m | sed -n 2p | awk '{print $5}' | cut -d% -f1 2>&1);
UNIT="Percent";

## Pushing Cloudwatch Metric data

OUTPUT=$(/usr/local/bin/aws cloudwatch put-metric-data --namespace ${NAMESPACE} --metric-name ${METRICS} --dimensions ${DNAME}=${DVALUE} --value ${VALUE} --unit ${UNIT} 2>&1);

if [ "$?" -ne "0" ]; then
	logger ERROR "${NAMESPACE} ${METRICS} ${DNAME}=${DVALUE} | value=${VALUE} unit=${UNIT} | ${OUTPUT}";
	exit 1;
fi;

logger INFO "${NAMESPACE} ${METRICS} ${DNAME}=${DVALUE} | value=${VALUE} unit=${UNIT}";
# Success
exit 0;

