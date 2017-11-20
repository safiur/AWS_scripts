#!/bin/bash
#
#  About                : Check Process Running Status
#
#  Name                 : cw_process.sh
#  Author               : Safiur Rehman
#  Creation Date        : 20-Sep-2017


DIR=$(dirname $0);
PLUGIN_NAME='cw_process';

# Include configuration file
source ${DIR}/../conf/plugin.conf;


#Get Current Instance ID
INSTANCE_ID=(`wget -q -O - http://169.254.169.254/latest/meta-data/instance-id`);
#Get Hostname
HOST_ID=(`wget -q -O - http://169.254.169.254/latest/meta-data/hostname`);

# Help
usage() {
        echo "Usage: $0 [-n <Namespace>] [-d <dimension>] [-m <metrics>] [-p <process name pattern>]" 1>&2;
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



while getopts ":n:d:m:p:" o; do
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
		logger ERROR "Invalid metrices passed <${METRICS}>";
                usage;
            fi
            ;;
        p)
            PROCESS=${OPTARG}
            if [ -z "${PROCESS}" ]; then
		logger ERROR "Invalid process passed <${PROCESS}>";
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
if [ -z "${NAMESPACE}" ] || [ -z "${DNAME}" ] || [ -z "$METRICS" ] || [ -z "$PROCESS" ]; then
		logger ERROR "Invalid argument passed";
    usage
fi


##########################################################
##########################################################


# If "INSTANCE_ID" is passed as Dimension, then use actual AWS Instanec ID as Dimension
if [ "${DNAME}" == "InstanceId" ]; then
        DVALUE=${INSTANCE_ID};
fi


UNIT="Count";

VALUE=$(ps aux | grep "${PROCESS}" | grep -v cw_process.sh | grep -vc grep 2>&1);

if [ "$?" -ne "0" ]; then
        logger ERROR "${NAMESPACE} ${METRICS} ${DNAME}=${DVALUE} | value=${VALUE} unit=${UNIT} | ${VALUE}";
        exit 1;
fi;

OUTPUT=$(/usr/local/bin/aws cloudwatch put-metric-data --namespace ${NAMESPACE} --metric-name ${METRICS} --dimensions ${DNAME}=${DVALUE} --value ${VALUE} --unit ${UNIT} 2>&1);

if [ "$?" -ne "0" ]; then
        logger ERROR "${NAMESPACE} ${METRICS} ${DNAME}=${DVALUE} | value=${VALUE} unit=${UNIT} | ${OUTPUT}";
        exit 1;
fi;

logger INFO "${NAMESPACE} ${METRICS} ${DNAME}=${DVALUE} | value=${VALUE} unit=${UNIT}";
# Success
exit 0;



