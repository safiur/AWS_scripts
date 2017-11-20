#!/bin/bash
#
#  About                : This script will uplaod the Compressed Application logs to specified s3 bucket
#  Usage                : ./cw_file2s3.sh [-b <Bucket>] [-f <Source File>] [-d <Destination Folder>]
#
#  Name                 : cw_file2S3.sh
#  Author               : Safiur Rehman


DIR=$(dirname $0);
PLUGIN_NAME='cw_file2S3';

# Include configuration file proxy
source ${DIR}/../conf/plugin.conf;


#Get Instance ID
INSTANCE_ID=(`wget -q -O - http://169.254.169.254/latest/meta-data/instance-id`);
#Get Hostname
HOST_ID=(`wget -q -O - http://169.254.169.254/latest/meta-data/hostname`);

# Help
usage() {
        echo "Usage: $0 [-b <Bucket>] [-f <Source File>] [-d <Destination Folder>] " 1>&2;
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
        usage;
fi

while getopts ":b:f:d:" o; do
    case "${o}" in
        b)
            BUCKET=${OPTARG}
            if [ -z "${BUCKET}" ]; then
                usage;
            fi
            ;;
        f)
            SOURCE=${OPTARG}
            if [ -z "${SOURCE}" ]; then
                usage;
            fi
            ;;
        d)
            DPATH=${OPTARG}
            if [ -z "${DPATH}" ]; then
                usage;
            fi
            ;;
        *)
            usage;
            ;;
    esac
done
shift $((OPTIND-1))

# Input Validation
if [ -z "${BUCKET}" ] || [ -z "${SOURCE}" ] || [ -z "${DPATH}" ]; then
    logger ERROR "Invalid Arguments Passed";
    usage;
fi

dateL=`date +"%Y-%m-%d-%H"`

        ## Upload Logs to S3
	echo ${SOURCE};
        for i in `ls ${SOURCE}`
        do
                OUTPUT=$(/usr/local/bin/aws s3 mv "$i" s3://"${BUCKET}"/"${DPATH}"/"${dateL}"/"${HOST_ID}"/ 2>&1)
                if [ "$?" -ne "0" ]; then
                      logger ERROR " Source=$i Destination=${DPATH} Bucket=${BUCKET} | ${OUTPUT}";
                      exit 1;
                else
                       logger INFO "$i Copied to s3://${BUCKET}/${DPATH}/${dateL}/${HOST_ID} | ${OUTPUT}";
                fi

        done;

# Success
exit 0;

