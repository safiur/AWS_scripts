#!/bin/bash
#
#  About                : Check Local and Foreign Network Connections
#
#  Name                 : cw_netconnection.sh
#  Author               : Safiur Rehman

DIR=$(dirname $0);
PLUGIN_NAME='cw_netconnection';

# Include configuration file
source ${DIR}/../conf/plugin.conf;


#Get Current Instance ID
INSTANCE_ID=(`wget -q -O - http://169.254.169.254/latest/meta-data/instance-id`);
#Get Hostname
HOST_ID=(`wget -q -O - http://169.254.169.254/latest/meta-data/hostname`);

# Help
usage() {
        echo "Usage: $0 [-n <Namespace>] [-d <dimension>] [-m <metrics>] [-s <ESTABLISHED | LISTEN | TIME_WAIT>] -t [ LOCAL | FOREIGN ] -p <TCP Port>" 1>&2;
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



while getopts ":n:d:m:p:s:t:" o; do
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
            METRICS=${OPTARG};
            if [ -z "${METRICS}" ]; then
		logger ERROR "Invalid metrices passed <${METRICS}>";
                usage;
            fi
            ;;
        s)
            STATE=${OPTARG}
	    if [ "${STATE}" != "ESTABLISHED" ] && [ "${STATE}" != "LISTEN" ] && [ "${STATE}" != "TIME_WAIT" ]; then
		logger ERROR "Invalid connection state passed <${STATE}>";
                usage;
	    fi
            ;;
        t)
            TYPE=${OPTARG}
            if [ "${TYPE}" != "LOCAL" ] && [ "${TYPE}" != "FOREIGN" ]; then
                logger ERROR "Invalid connection type passed <${TYPE}>";
                usage;
            fi
            ;;
        p)
            PORT=${OPTARG}
            if [ -z "${PORT}" ]; then
		logger ERROR "Invalid process passed <${PORT}>";
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
if [ -z "${NAMESPACE}" ] || [ -z "${DNAME}" ] || [ -z "$METRICS" ] || [ -z "$PORT" ] || [ -z "${STATE}" ] || [ -z "${TYPE}" ]; then
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

if [ "${TYPE}" == "LOCAL" ]; then
	VALUE=$(netstat -alntp | grep ${STATE} | grep -v grep | awk '{print $4}' | awk -F[:] '{print $2}' | grep -cw ${PORT} 2>&1);
else
	echo ${TYPE};
	VALUE=$(netstat -alntp | grep ${STATE} | grep -v grep | awk '{print $5}' | awk -F[:] '{print $2}' | grep -cw ${PORT} 2>&1);
fi;

if [ "$VALUE" -ne "$VALUE" ] 2>/dev/null; then
        logger ERROR "${NAMESPACE} ${METRICS} ${DNAME}=${DVALUE} | ${STATE} ${TYPE} ${PORT} | value=NULL unit=${UNIT} | ${VALUE}";
        exit 1;
fi;

OUTPUT=$(/usr/local/bin/aws cloudwatch put-metric-data --namespace ${NAMESPACE} --metric-name ${METRICS} --dimensions ${DNAME}=${DVALUE} --value ${VALUE} --unit ${UNIT} 2>&1);

if [ "$?" -ne "0" ]; then
        logger ERROR "${NAMESPACE} ${METRICS} ${DNAME}=${DVALUE} | ${STATE} ${TYPE} ${PORT} value=${VALUE} unit=${UNIT} | ${OUTPUT}";
        exit 1;
fi;

logger INFO "${NAMESPACE} ${METRICS} ${DNAME}=${DVALUE} | ${STATE} ${TYPE} ${PORT} value=${VALUE} unit=${UNIT}";
# Success
exit 0;



