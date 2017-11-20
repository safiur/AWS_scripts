#!/bin/bash
#
#  About                : Check TCP connections
#
#  Name                 : cw_tcpconnection.sh
#  Author               : Safiur Rehman


DIR=$(dirname $0);
PLUGIN_NAME='cw_tcpconnection';

# Include configuration file
source ${DIR}/../conf/plugin.conf;


#Get Current Instance ID
INSTANCE_ID=(`wget -q -O - http://169.254.169.254/latest/meta-data/instance-id`);
#Get Hostname
HOST_ID=(`wget -q -O - http://169.254.169.254/latest/meta-data/hostname`);

# Help
usage() {
        echo "Usage: $0 [-n <Namespace>] [-d <dimension>] [-m <metrics>] [-h <hostname>] [-p <port>]" 1>&2;
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



while getopts ":n:d:m:h:p:" o; do
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
        h)
            HOST=${OPTARG}
            if [ -z "${HOST}" ]; then
		logger ERROR "Invalid hostname passed <${HOST}>";
                usage;
            fi
            ;;
        p)
            PORT=${OPTARG}
            if [ -z "${PORT}" ]; then
                logger ERROR "Invalid port passed <${PORT}>";
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
if [ -z "${NAMESPACE}" ] || [ -z "${DNAME}" ] || [ -z "$METRICS" ] || [ -z "$HOST" ] || [ -z "$PORT" ]; then
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

</dev/tcp/${HOST}/${PORT}
if [ "$?" -ne 0 ]; then
	VALUE=2;
else
	VALUE=1;
fi

OUTPUT=$(/usr/local/bin/aws cloudwatch put-metric-data --namespace ${NAMESPACE} --metric-name ${METRICS} --dimensions ${DNAME}=${DVALUE} --value ${VALUE} --unit ${UNIT} 2>&1);

if [ "$?" -ne "0" ]; then
        logger ERROR "${NAMESPACE} ${METRICS} ${DNAME}=${DVALUE} | value=${VALUE} unit=${UNIT} $HOST $PORT | ${OUTPUT}";
        exit 1;
fi;

logger INFO "${NAMESPACE} ${METRICS} ${DNAME}=${DVALUE} | value=${VALUE} unit=${UNIT} $HOST $PORT";
# Success
exit 0;



