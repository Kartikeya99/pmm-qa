#!/bin/bash
# Created by Ramesh Sivaraman, Percona LLC
# Additions by Roel Van de Paar, Percona LLC

# PMM Framework
# This script enables one to quickly setup a Percona Monitoring and Management environment. One can setup a PMM server and quickly add multiple clients
# The intention of this script is to be robust from a quality assurance POV; it should handle many different server configurations accurately

# Internal variables
WORKDIR=${PWD}
SCRIPT_PWD=$(cd `dirname $0` && pwd)
RPORT=$(( RANDOM%21 + 10 ))
RBASE="$(( RPORT*1000 ))"
SERVER_START_TIMEOUT=100
SUSER="root"
SPASS=""
OUSER="admin"
OPASS="passw0rd"
ADDR="127.0.0.1"
download_link=0
disable_ssl=0
create_pgsql_user=0
PGSQL_PORT=5432
PS_PORT=43306
with_replica=1

mkdir -p $WORKDIR/logs
# User configurable variables
IS_BATS_RUN=0

# Dispay script usage details
usage () {
  echo "Usage: [ options ]"
  echo "Options:"
  echo " --setup                        This will setup and configure a PMM server"
  echo " --dev                          When this option is specified, PMM framework will use the latest PMM development version. Otherwise, the latest 1.x version is used"
  echo " --dev-fb                       This will install specified feature build (must be used with --setup and --dev options)" 
  echo " --pmm2                         When this option is specified, PMM framework will use specified PMM 2.x development version. Must be used with pmm-server-version option"
  echo " --skip-docker-setup            Pass this parameter if Docker Setup for PMM2-Server is not needed, Only Pmm2-client needs to be installed"
  echo " --is-bats-run                  Change Bats run option, set to 1 if not user interaction required"
  echo " --link-client                  Pass URL to download pmm-client"
  echo " --addclient=ps,2               Add Percona (ps), MySQL (ms), MariaDB (md), Percona XtraDB Cluster (pxc), and/or mongodb (mo) pmm-clients to the currently live PMM server (as setup by --setup)"
  echo "                                You can add multiple client instances simultaneously. eg : --addclient=ps,2  --addclient=ms,2 --addclient=md,2 --addclient=mo,2 --addclient=pxc,3"
  echo " --download                     This will help us to download pmm client binary tar balls"
  echo " --dbdeployer                   This option will use dbdeployer tool for deploying PS, MS Databases"
  echo " --pmm-server-version           Pass PMM version"
  echo " --pmm-port                     Pass port for PMM docker"
  echo " --pmm2-server-ip               Pass Address for PMM2-Server"
  echo " --package-name                 Name of the Server package installed"
  echo " --ps-version                   Pass Percona Server version info"
  echo " --ms-version                   Pass MySQL Server version info"
  echo " --pgsql-version                Pass Postgre SQL server version Info"
  echo " --md-version                   Pass MariaDB Server version info"
  echo " --pxc-version                  Pass Percona XtraDB Cluster version info"
  echo " --mysqld-startup-options       Pass MySQL startup options. eg : --mysqld-startup-options='--innodb_buffer_pool_size=1G --innodb_log_file_size=1G'"
  echo " --with-proxysql                This allow to install PXC with proxysql"
  echo " --sysbench-data-load           This will initiate sysbench data load on mysql instances"
  echo " --sysbench-oltp-run            This will initiate sysbench oltp run on mysql instances"
  echo " --storage-engine               This will create sysbench tables with specific storage engine"
  echo " --mo-version                   Pass MongoDB Server version info"
  echo " --mongo-with-rocksdb           This will start mongodb with rocksdb engine"
  echo " --replcount                    You can configure multiple mongodb replica sets with this oprion"
  echo " --with-replica                 This will configure mongodb replica setup"
  echo " --with-sharding                This will configure mongodb sharding setup"
  echo " --mongo-sysbench               This option initiates sysbench oltp prepare and run for MongoDB instance"
  echo " --add-docker-client            Add docker pmm-clients with percona server to the currently live PMM server"
  echo " --list                         List all client information as obtained from pmm-admin"
  echo " --wipe-clients                 This will stop all client instances and remove all clients from pmm-admin"
  echo " --wipe-pmm2-clients            This will stop all pmm-server from monitoring client instances"
  echo " --wipe-docker-clients          This will stop all docker client instances and remove all clients from docker container"
  echo " --wipe-server                  This will stop pmm-server container and remove all pmm containers"
  echo " --wipe                         This will wipe all pmm configuration"
  echo " --pmm-server-username          User name to access the PMM Server web interface"
  echo " --pmm-server-password          Password to access the PMM Server web interface"
  echo " --pmm-server-memory            Set METRICS_MEMORY option to PMM server"
  echo " --pmm-docker-memory            Set memory for docker container"
  echo " --pmm-server=[docker|ami|ova]  Choose PMM server appliance, default pmm server appliance is docker"
  echo " --ami-image                    Pass PMM server ami image name"
  echo " --key-name                     Pass your aws access key file name"
  echo " --ova-image                    Pass PMM server ova image name"
  echo " --ova-memory                   Pass memory(memorysize in MB) for OVA virtual box"
  echo " --disable-ssl                  Disable ssl mode on exporter"
  echo " --create-pgsql-user            Set this option if a Dedicated PGSQl User creation is required username: psql and no password"
  echo " --upgrade-server               When this option is specified, PMM Server will be updated to the last version"
  echo " --upgrade-client               When this option is specified, PMM client will be updated to the last version"
  echo " --query-source                 Set query source (perfschema or slowlog)"
  echo " --compare-query-count          This will help us to compare the query count between PMM client instance and PMM QAN/Metrics page"
}

# Check if we have a functional getopt(1)
if ! getopt --test
  then
  go_out="$(getopt --options=u: --longoptions=addclient:,replcount:,pmm-server:,ami-image:,key-name:,pmm2-server-ip:,ova-image:,ova-memory:,pmm-server-version:,dev-fb:,link-client:,pmm-port:,package-name:,pmm-server-memory:,pmm-docker-memory:,pmm-server-username:,pmm-server-password:,query-source:,setup,pmm2,dbdeployer,install-client,skip-docker-setup,with-replica,with-sharding,download,ps-version:,ms-version:,pgsql-version:,md-version:,pxc-version:,mysqld-startup-options:,mo-version:,mongo-with-rocksdb,add-docker-client,list,wipe-clients,wipe-pmm2-clients,delete-package,wipe-docker-clients,wipe-server,is-bats-run,disable-ssl,create-pgsql-user,upgrade-server,upgrade-client,wipe,dev,with-proxysql,sysbench-data-load,sysbench-oltp-run,mongo-sysbench,storage-engine:,compare-query-count,help \
  --name="$(basename "$0")" -- "$@")"
  test $? -eq 0 || exit 1
  eval set -- $go_out
fi

if [[ $go_out == " --" ]];then
  usage
  exit 1
fi

for arg
do
  case "$arg" in
    -- ) shift; break;;
    --addclient )
    ADDCLIENT+=("$2")
    shift 2
    ;;
    --with-replica )
    shift
    with_replica=1
    ;;
    --replcount )
    REPLCOUNT=$2
    shift 2
    ;;
    --with-sharding )
    shift
    with_sharding=1
    ;;
    --download )
    shift
    download_link=1
    ;;
    --link-client )
    link_client="$2"
    shift 2
    ;;
    --pmm-server )
    pmm_server="$2"
	shift 2
    if [ "$pmm_server" != "docker" ] && [ "$pmm_server" != "ami" ] && [ "$pmm_server" != "ova" ] && [ "$pmm_server" != "custom" ]; then
      echo "ERROR: Invalid --pmm-server passed:"
      echo "  Please choose any of these pmm-server options: 'docker', 'ami', 'custom', or 'ova'"
      exit 1
    fi
    ;;
    --pmm-server-version )
    pmm_server_version="$2"
    PMM_VERSION=$pmm_server_version
    shift 2
    ;;
    --dev-fb )
    DEV_FB="$2"
    shift 2
    ;;
    --pmm-server-memory )
    MEMORY="$2"
    shift 2
    ;;
    --pmm-port )
    PMM_PORT="$2"
    shift 2
    ;;
    --pmm2-server-ip )
    IP_ADDRESS="$2"
    shift 2
    ;;
    --package-name )
    package_name="$2"
    shift 2
    ;;
    --pmm-docker-memory )
    DOCKER_MEMORY="$2"
    shift 2
    ;;
    --ami-image )
    ami_image="$2"
    shift 2
    ;;
    --key-name )
    key_name="$2"
    shift 2
    ;;
    --is-bats-run )
    IS_BATS_RUN=1
    shift 2
    ;;
    --ova-image )
    ova_image="$2"
    shift 2
    ;;
    --ova-memory )
    ova_memory="$2"
    shift 2
    ;;
    --ps-version )
    ps_version="$2"
    shift 2
    ;;
    --ms-version )
    ms_version="$2"
    shift 2
    ;;
    --pgsql-version )
    pgsql_version="$2"
    shift 2
    ;;
    --md-version )
    md_version="$2"
    shift 2
    ;;
    --pxc-version )
    pxc_version="$2"
    shift 2
    ;;
    --mysqld-startup-options )
    mysqld_startup_options="$2"
    shift 2
    ;;
    --query-source )
    query_source="$2"
    shift 2
    ;;
    --mo-version )
    mo_version="$2"
    shift 2
    ;;
    --mongo-storage-engine )
    shift
    mongo_storage_engine="--storageEngine  $2"
    ;;
    --add-docker-client )
    shift
    add_docker_client=1
    ;;
    --setup )
    shift
    setup=1
    ;;
    --pmm2 )
    shift
    PMM2=1
    ;;
    --dbdeployer )
    shift
    use_dbdeployer=1
    ;;
    --skip-docker-setup )
    shift
    skip_docker_setup=1
    ;;
    --list )
    shift
    list=1
    ;;
    --wipe-clients )
    shift
    wipe_clients=1
    ;;
    --wipe-pmm2-clients )
    shift
    wipe_pmm2_clients=1
    ;;
    --delete-package )
    shift
    delete_package=1
    ;;
    --disable-ssl )
    shift
    disable_ssl=1
    ;;
    --create-pgsql-user )
    shift
    create_pgsql_user=1
    ;;
    --wipe-docker-clients )
    shift
    wipe_docker_clients=1
    ;;
    --wipe-server )
    shift
    wipe_server=1
    ;;
    --wipe )
    shift
    wipe=1
    ;;
    --dev )
    shift
    dev=1
    ;;
    --with-proxysql )
    shift
    with_proxysql=1
    ;;
    --sysbench-data-load )
    shift
    sysbench_data_load=1
    ;;
    --sysbench-oltp-run )
    shift
    sysbench_oltp_run=1
    ;;
    --storage-engine )
    storage_engine="$2"
    shift 2
    ;;
    --mongo-sysbench )
    shift
    mongo_sysbench=1
    ;;
    --compare-query-count )
    shift
    compare_query_count=1
    ;;
    --upgrade-server )
    upgrade_server=1
    shift
    ;;
    --upgrade-client )
    upgrade_client=1
    shift
    ;;
    --pmm-server-username )
    pmm_server_username="$2"
    shift 2
    ;;
    --pmm-server-password )
    case "$2" in
      "")
      read -r -s -p  "Enter PMM Server web interface password:" INPUT_PASS
      if [ -z "$INPUT_PASS" ]; then
        pmm_server_password=""
        printf "\nConfiguring without PMM Server web interface password...\n";
      else
        pmm_server_password="$INPUT_PASS"
      fi
      printf "\n"
      ;;
      *)
      pmm_server_password="$2"
      ;;
    esac
    shift 2
    ;;
    --help )
    usage
    exit 0
    ;;
  esac
done

check_script(){
  MPID=$1
  ERROR_MSG=$2
  if [ ${MPID} -ne 0 ]; then echo "Assert! ${MPID}. Terminating!"; exit 1; fi
}

mongo_sysbench(){
  SYSBENCH=$(which sysbench)
  if [[ -z "SYSBENCH" ]];then
    echo "ERROR! 'sysbench' is not installed. Please install sysbench. Terminating."
    exit 1
  fi
  wget https://raw.githubusercontent.com/Percona-Lab/sysbench-mongodb-lua/master/oltp-mongo.lua
  PORT=$(sudo pmm-admin list  | awk -F '[: ]+' '/mongodb:metrics/{print $7}'| head -n1) 
  echo "PORT "$PORT
  sysbench oltp-mongo.lua --tables=10 --threads=10 --table-size=1000000 --mongodb-db=sbtest --mongodb-host=localhost --mongodb-port=${PORT}  --rand-type=pareto prepare > $WORKDIR/logs/mongo_sysbench_prepare.txt 2>&1 &
  sysbench oltp-mongo.lua --tables=10 --threads=10 --table-size=1000000 --mongodb-db=sbtest --mongodb-host=localhost --mongodb-port=${PORT} --time=1200 --report-interval=1 --rand-type=pareto run > $WORKDIR/logs/mongo_sysbench_run.txt 2>&1 &
  check_script $? "Failed to run sysbench for MongoDB dataload"

}
# Add check for --pmm-server-memory
if [[ -z "$MEMORY" ]]; then
  PMM_METRICS_MEMORY=""
else
  PMM_METRICS_MEMORY="-e METRICS_MEMORY=$MEMORY"
fi

# Add check for --pmm-docker-memory
if [[ -z "$DOCKER_MEMORY" ]]; then
  DOCKER_CONTAINER_MEMORY=""
else
  DOCKER_CONTAINER_MEMORY="--memory=$DOCKER_MEMORY"
fi

if [[ -z "$storage_engine" ]];then
  storage_engine=INNODB
fi

if [[ -z "$disable_ssl" ]];then
  disable_ssl=0
fi

if [[ -z "$create_pgsql_user" ]]; then
  create_pgsql_user=0
fi

if [[ "$with_sharding" == "1" ]];then
  with_replica=1
fi
if [[ -z "$pmm_server_username" ]];then
  if [[ ! -z "$pmm_server_password" ]];then
    echo "ERROR! PMM Server web interface username is empty. Terminating"
    exit 1
  fi
fi

if [[ -z "$pmm_server" ]];then
  pmm_server="docker"
elif [[ "$pmm_server" == "ami" ]];then
  if [[ "$setup" == "1" ]];then
    if [[ -z "$ami_image" ]];then
      echo "ERROR! You have not given AMI image name. Please use --ami-image to pass image name. Terminating"
      exit 1
    fi
    if [[ -z "$key_name" ]];then
      echo "ERROR! You have not entered  aws key name. Please use --key-name to pass key name. Terminating"
      exit 1
    fi
  fi
elif [[ "$pmm_server" == "ova" ]];then
  if [[ "$setup" == "1" ]];then
    if [[ -z "$ova_image" ]];then
      echo "ERROR! You have not given OVA image name. Please use --ova-image to pass image name. Terminating"
      exit 1
    fi
  fi
elif [[ "$pmm_server" == "custom" ]];then
  if ! sudo pmm-admin ping | grep -q "OK, PMM server is alive"; then
    echo "ERROR! PMM Server is not running. Please check PMM server status. Terminating"
    exit 1
  fi
fi

sanity_check(){
  if [[ "$pmm_server" == "docker" ]];then
    if ! sudo docker ps | grep 'pmm-server' > /dev/null ; then
      echo "ERROR! pmm-server docker container is not runnning. Terminating"
      #exit 1
    fi
  elif [[ "$pmm_server" == "ami" ]];then
    if [ -f $WORKDIR/aws_instance_config.txt ]; then
      INSTANCE_ID=$(cat $WORKDIR/aws_instance_config.txt | grep "InstanceId"  | awk -F[\"\"] '{print $4}')
	else
	  echo "ERROR! Could not read aws instance id. $WORKDIR/aws_instance_config.txt does not exist. Terminating"
	  exit 1
	fi
    INSTANCE_ACTIVE=$(aws ec2 describe-instance-status --instance-ids  $INSTANCE_ID | grep "Code" | sed 's/[^0-9]//g')
	if [[ "$INSTANCE_ACTIVE" != "16" ]];then
      echo "ERROR! pmm-server ami instance is not runnning. Terminating"
      exit 1
	fi
  elif [[ "$pmm_server" == "ova" ]];then
    VMBOX=$(vboxmanage list runningvms | grep "PMM-Server" | awk -F[\"\"] '{print $2}')
	VMBOX_STATUS=$(vboxmanage showvminfo $VMBOX  | grep State | awk '{print $2}')
	if [[ "$VMBOX_STATUS" != "running" ]]; then
	  echo "ERROR! pmm-server ova instance is not runnning. Terminating"
      exit 1
	fi
  fi
}

sudo_check(){

  USER=$1
    # Sudo check
    echo "Checking for user $1"
  if [ "$(sudo -H -u ${USER} bash -c "echo 'test'" 2>/dev/null)" != "test" ]; then
    echo "Error: sudo is not available or requires a password. This script needs to be able to use sudo, without password, from the userID that invokes it ($(whoami))"
    echo "To get your setup correct, you may like to use a tool like visudo (use 'sudo visudo' or 'su' and then 'visudo') and consider adding the following line to the file:"
    echo "$(whoami)   ALL=(ALL)      NOPASSWD:ALL"
    echo "If you do not have sudo installed yet, try 'su' and then 'yum install sudo' or the apt-get equivalent"
    echo "Terminating now."
    exit 1
  fi
}

if [[ -z "${ps_version}" ]]; then ps_version="5.7"; fi
if [[ -z "${pxc_version}" ]]; then pxc_version="5.7"; fi
if [[ -z "${ms_version}" ]]; then ms_version="8.0"; fi
if [[ -z "${md_version}" ]]; then md_version="10.3"; fi
if [[ -z "${mo_version}" ]]; then mo_version="4.0"; fi
if [[ -z "${REPLCOUNT}" ]]; then REPLCOUNT="1"; fi
if [[ -z "${ova_memory}" ]]; then ova_memory="2048";fi
if [[ -z "${pgsql_version}" ]]; then pgsql_version="10.8";fi

if [[ -z "$query_source" ]];then
  query_source=perfschema
fi

setup(){
  if [ $IS_BATS_RUN -eq 0 ];then
    read -p "Would you like to enable SSL encryption to protect PMM from unauthorized access[y/n] ? " check_param
    case $check_param in
      y|Y)
        echo -e "\nGenerating SSL certificate files to protect PMM from unauthorized access"
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout server.key -out server.crt -subj '/CN=www.percona.com/O=Database Performance./C=US'
        IS_SSL="Yes"
        if [[ -z $PMM_PORT ]]; then
          PMM_PORT=443
        fi
      ;;
      n|N)
        echo ""
        IS_SSL="No"
        if [[ -z $PMM_PORT ]]; then
          PMM_PORT=80
        fi
      ;;
      *)
        echo "Please type [y/n]! Terminating."
        exit 1
      ;;
    esac
  else
    IS_SSL="No"
  fi

  
  if [[ ! -e $(which lynx 2> /dev/null) ]] ;then
    echo "ERROR! The program 'lynx' is currently not installed. Please install lynx. Terminating"
    exit 1
  fi
  #IP_ADDRESS=$(ip route get 8.8.8.8 | head -1 | cut -d' ' -f8)
  if [ -z $IP_ADDRESS ]; then
    IP_ADDRESS=$(ip route get 8.8.8.8 | awk -F"src " 'NR==1{split($2,a," ");print a[1]}')
  fi
  if [[ "$pmm_server" == "docker" ]];then
    #PMM configuration setup
    if [ -z $pmm_server_version ]; then
      if [ -z $dev ]; then
        echo "dev is == " $dev
        PMM_VERSION=$(lynx --dump https://hub.docker.com/r/percona/pmm-server/tags/ | grep '[0-9].[0-9].[0-9]' | sed 's|   ||' | head -n1)
        echo "PMM VERSION IS $PMM_VERSION"
      else
        PMM_VERSION=$(lynx --dump https://hub.docker.com/r/perconalab/pmm-server/tags/ | grep '[0-9].[0-9].[0-9]' | sed 's|   ||' | head -n1)
        echo "PMM VERSION IS $PMM_VERSION"
      fi
    #PMM sanity check
      if ! pgrep docker > /dev/null ; then
        echo "ERROR! docker service is not running. Terminating"
        exit 1
      fi
      if sudo docker ps | grep 'pmm-server' > /dev/null ; then
        echo "ERROR! pmm-server docker container is already runnning. Terminating"
        exit 1
      elif  sudo docker ps -a | grep 'pmm-server' > /dev/null ; then
        CONTAINER_NAME=$(sudo docker ps -a | grep 'pmm-server' | grep $PMM_VERSION | grep -v pmm-data | awk '{ print $1}')
        echo "ERROR! The name 'pmm-server' is already in use by container $CONTAINER_NAME"
        exit 1
      fi
    fi
   if [[ "$pmm_server" == "aws" ]];then
	    aws ec2 describe-instance-status --instance-ids  $INSTANCE_ID | grep "Code" | sed 's/[^0-9]//g'
    fi
    echo "Initiating PMM configuration"
    if [[ ! -z $PMM2  && -z $skip_docker_setup ]]; then
      sudo docker create -v /srv    --name pmm-data    perconalab/pmm-server:$PMM_VERSION  /bin/true
      sudo docker run -d  -p $PMM_PORT:80 -p 443:443 -p 9000:9000  --name pmm-server perconalab/pmm-server:$PMM_VERSION
    else
    if [ ! -z $DEV_FB ]; then
      sudo docker create -v /opt/prometheus/data  -v /var/lib/grafana -v /opt/consul-data -v /var/lib/mysql -e SERVER_USER="$pmm_server_username" -e SERVER_PASSWORD="$pmm_server_password" --name pmm-data perconalab/pmm-server-fb:$DEV_FB /bin/true 2>/dev/null
      sudo docker run -d -p $PMM_PORT:80 -p 8500:8500 $DOCKER_CONTAINER_MEMORY $PMM_METRICS_MEMORY -e SERVER_USER="$pmm_server_username" -e SERVER_PASSWORD="$pmm_server_password" -e ORCHESTRATOR_USER=$OUSER -e ORCHESTRATOR_PASSWORD=$OPASS --volumes-from pmm-data --name pmm-server --restart always perconalab/pmm-server-fb:$DEV_FB 2>/dev/null
    else

      if [ -z $dev ]; then
        sudo docker create -v /opt/prometheus/data -v /var/lib/grafana -v /opt/consul-data -v /var/lib/mysql -e SERVER_USER="$pmm_server_username" -e SERVER_PASSWORD="$pmm_server_password" --name pmm-data percona/pmm-server:$PMM_VERSION /bin/true 2>/dev/null
      else
        sudo docker create -v /opt/prometheus/data  -v /var/lib/grafana -v /opt/consul-data -v /var/lib/mysql -e SERVER_USER="$pmm_server_username" -e SERVER_PASSWORD="$pmm_server_password" --name pmm-data perconalab/pmm-server:$PMM_VERSION /bin/true 2>/dev/null
      fi
      if [ -z $dev ]; then
        if [ "$IS_SSL" == "Yes" ];then
          sudo docker run -d -p $PMM_PORT:443 -p 8500:8500 $DOCKER_CONTAINER_MEMORY $PMM_METRICS_MEMORY  -e SERVER_USER="$pmm_server_username" -e SERVER_PASSWORD="$pmm_server_password" -e ORCHESTRATOR_USER=$OUSER -e ORCHESTRATOR_PASSWORD=$OPASS --volumes-from pmm-data --name pmm-server --restart always percona/pmm-server:$PMM_VERSION 2>/dev/null
        else
          sudo docker run -d -p $PMM_PORT:80 -p 8500:8500 $DOCKER_CONTAINER_MEMORY $PMM_METRICS_MEMORY -e SERVER_USER="$pmm_server_username" -e SERVER_PASSWORD="$pmm_server_password" -e ORCHESTRATOR_USER=$OUSER -e ORCHESTRATOR_PASSWORD=$OPASS --volumes-from pmm-data --name pmm-server --restart always percona/pmm-server:$PMM_VERSION 2>/dev/null
        fi
      else
        if [ "$IS_SSL" == "Yes" ];then
          sudo docker run -d -p $PMM_PORT:443 -p 8500:8500 $DOCKER_CONTAINER_MEMORY $PMM_METRICS_MEMORY -e SERVER_USER="$pmm_server_username" -e SERVER_PASSWORD="$pmm_server_password" -e ORCHESTRATOR_USER=$OUSER -e ORCHESTRATOR_PASSWORD=$OPASS --volumes-from pmm-data --name pmm-server --restart always perconalab/pmm-server:$PMM_VERSION 2>/dev/null
        else
          sudo docker run -d -p $PMM_PORT:80 -p 8500:8500 $DOCKER_CONTAINER_MEMORY $PMM_METRICS_MEMORY -e SERVER_USER="$pmm_server_username" -e SERVER_PASSWORD="$pmm_server_password" -e ORCHESTRATOR_USER=$OUSER -e ORCHESTRATOR_PASSWORD=$OPASS --volumes-from pmm-data --name pmm-server --restart always perconalab/pmm-server:$PMM_VERSION 2>/dev/null
        fi
     fi
   fi
  fi
  elif [[ "$pmm_server" == "ami" ]] ; then
    if [[ ! -e $(which aws 2> /dev/null) ]] ;then
      echo "ERROR! AWS client program is currently not installed. Please install awscli. Terminating"
      exit 1
    fi
    if [ ! -f $HOME/.aws/credentials ]; then
      echo "ERROR! AWS access key is not configured. Terminating"
	  exit 1
	fi
	aws ec2 run-instances \
	--image-id $ami_image \
	--security-group-ids sg-3b6e5e46 \
	--instance-type t2.micro \
    --subnet-id subnet-4765a930 \
    --region us-east-1 \
    --key-name $key_name > $WORKDIR/aws_instance_config.txt 2> /dev/null

	INSTANCE_ID=$(cat $WORKDIR/aws_instance_config.txt | grep "InstanceId"  | awk -F[\"\"] '{print $4}')

	aws ec2 create-tags  \
    --resources $INSTANCE_ID \
    --region us-east-1 \
    --tags Key=Name,Value=PMM_test_image 2> /dev/null

	sleep 30

	AWS_PUBLIC_IP=$(aws ec2 describe-instances --instance-ids  $INSTANCE_ID | grep "PublicIpAddress" | awk -F[\"\"] '{print $4}')
  elif [[ "$pmm_server" == "ova" ]] ; then
    if [[ ! -e $(which VBoxManage 2> /dev/null) ]] ;then
      echo "ERROR! VBoxManage client program is currently not installed. Please install VirtualBox. Terminating"
      exit 1
    fi
	ova_image_name=$(echo $ova_image | sed 's/.ova//')
    VMBOX=$(vboxmanage list runningvms | grep $ova_image_name | awk -F[\"\"] '{print $2}')
	VMBOX_STATUS=$(vboxmanage showvminfo $VMBOX  | grep State | awk '{print $2}')
	if [[ "$VMBOX_STATUS" == "running" ]]; then
	  echo "ERROR! pmm-server ova instance is already runnning. Terminating"
      exit 1
	fi
	# import image
	if [ ! -f $ova_image ] ;then
	  echo "Alert! ${ova_image} does not exist in $WORKDIR. Downloading ${ova_image} ..."
	  wget https://s3.amazonaws.com/percona-vm/$ova_image
	fi
    VBoxManage import $ova_image > $WORKDIR/ova_instance_config.txt 2> /dev/null
	NETWORK_INTERFACE=$(ip addr | grep $IP_ADDRESS |  awk 'NF>1{print $NF}')
	VBoxManage modifyvm $ova_image_name --nic1 bridged --bridgeadapter1 ${NETWORK_INTERFACE}
	VBoxManage modifyvm $ova_image_name --uart1 0x3F8 4 --uartmode1 file $WORKDIR/pmm-server-console.log
    VBoxManage modifyvm $ova_image_name --memory ${ova_memory}
    # start instance
    VBoxManage startvm --type headless $ova_image_name > $WORKDIR/pmm-server-starup.log 2> /dev/null
	sleep 120
	OVA_PUBLIC_IP=$(grep 'Percona Monitoring and Management' $WORKDIR/pmm-server-console.log | awk -F[\/\/] '{print $3}')
  fi
 #  #PMM configuration setup
  if [ -z $pmm_server_version ] && [ -z $dev ]; then
   PMM_VERSION=$(lynx --dump https://hub.docker.com/r/percona/pmm-server/tags/ | grep '[0-9].[0-9].[0-9]' | sed 's|   ||' | head -n1)
 else
   if [[ ! -z $pmm_server_version ]]; then
     PMM_VERSION=$pmm_server_version
   fi
   echo "PMM version is ====== $PMM_VERSION"
 fi
  echo "Initiating PMM client configuration"
  PMM_CLIENT_BASEDIR=$(ls -1td pmm-client-* 2>/dev/null | grep -v ".tar" | head -n1)
  if [ -z $PMM_CLIENT_BASEDIR ]; then
    PMM_CLIENT_TAR=$(ls -1td pmm-client-* 2>/dev/null | grep ".tar" | head -n1)
    if [ ! -z $PMM_CLIENT_TAR ];then
      tar -xzf $PMM_CLIENT_TAR
      PMM_CLIENT_BASEDIR=$(ls -1td pmm-client-* 2>/dev/null | grep -v ".tar" | head -n1)
      pushd $PMM_CLIENT_BASEDIR > /dev/null
      sudo ./install
      popd > /dev/null
    else
      if [ ! -z $PMM2 ]; then
        install_client
      else  
      if [ ! -z $dev ]; then
        if [  -z $link_client]; then
         PMM_CLIENT_TARBALL_URL=$(lynx --listonly --dump https://www.percona.com/downloads/TESTING/pmm/ | grep  "pmm-client" |awk '{print $2}'| grep "tar.gz" | head -n1)
        else
          PMM_CLIENT_TARBALL_URL=$link_client
        fi
        #echo "PMM client URL $PMM_CLIENT_URL"
        echo "PMM client tarball $PMM_CLIENT_TARBALL_URL"
        wget $PMM_CLIENT_TARBALL_URL
        PMM_CLIENT_TAR=$(echo $PMM_CLIENT_TARBALL_URL | grep -o '[^/]*$')
        tar -xzf $PMM_CLIENT_TAR
        PMM_CLIENT_BASEDIR=$(ls -1td pmm-client-* 2>/dev/null | grep -v ".tar" | head -n1)
        pushd $PMM_CLIENT_BASEDIR > /dev/null
        sudo ./install
        popd > /dev/null
      else
        PMM_CLIENT_TAR=$(lynx --dump  https://www.percona.com/downloads/pmm-client/$PMM_VERSION/binary/tarball/ | grep -o pmm-client.*.tar.gz | head -n1)
        echo "PMM client tar 2 $PMM_CLIENT_TAR"
        wget https://www.percona.com/downloads/pmm-client/$PMM_VERSION/binary/tarball/$PMM_CLIENT_TAR
        tar -xzf $PMM_CLIENT_TAR
        PMM_CLIENT_BASEDIR=$(ls -1td pmm-client-* 2>/dev/null | grep -v ".tar" | head -n1)
        pushd $PMM_CLIENT_BASEDIR > /dev/null
        sudo ./install
        popd > /dev/null
      fi
    fi
  fi
  else
    pushd $PMM_CLIENT_BASEDIR > /dev/null
    sudo ./install
    popd > /dev/null
  fi
  if [ "$IS_SSL" == "Yes" ];then
    PMM_MYEXTRA="--server-insecure-ssl"
  else
    PMM_MYEXTRA=""
  fi
  if [[ ! -e $(which pmm-admin 2> /dev/null) ]] ;then
    echo "ERROR! The pmm-admin client binary was not found, please install the pmm-client package"
    exit 1
  else
    sleep 10
  if [[ ! -e $(which pmm-agent 2> /dev/null) ]] && [ ! -z $PMM2 ] ;then
    echo "ERROR! The pmm-agent was not found, please install the pmm2-client package"
    exit 1
  fi
   #Cleaning existing PMM server configuration
  if [ ! -z $PMM2 ]; then
    configure_client
  else
    sudo truncate -s0 /usr/local/percona/pmm-client/pmm.yml
    if [[ "$pmm_server" == "ami" ]]; then
	  sudo pmm-admin config --server $AWS_PUBLIC_IP --client-address $IP_ADDRESS $PMM_MYEXTRA
	  echo "Alert! Password protection is not enabled in ami image, Please configure it manually"
	  SERVER_IP=$AWS_PUBLIC_IP
    elif [[ "$pmm_server" == "ova" ]]; then
	  sudo pmm-admin config --server $OVA_PUBLIC_IP --client-address $IP_ADDRESS $PMM_MYEXTRA
	  echo "Alert! Password protection is not enabled in ova image, Please configure it manually"
	  SERVER_IP=$OVA_PUBLIC_IP
    else
      sudo pmm-admin config --server $IP_ADDRESS:$PMM_PORT --server-user=$pmm_server_username --server-password=$pmm_server_password $PMM_MYEXTRA
	  SERVER_IP=$IP_ADDRESS
    fi
  fi
fi

  echo -e "******************************************************************"
  if [[ "$pmm_server" == "docker" ]]; then
    echo -e "Please execute below command to access docker container"
    echo -e "docker exec -it pmm-server bash\n"
  fi
  if [ "$IS_SSL" == "Yes" ];then
    (
    printf "%s\t%s\n" "PMM landing page" "https://$SERVER_IP:$PMM_PORT"
    if [ ! -z $pmm_server_username ];then
      printf "%s\t%s\n" "PMM landing page username" "$pmm_server_username"
    fi
    if [ ! -z $pmm_server_password ];then
      printf "%s\t%s\n" "PMM landing page password" "$pmm_server_password"
    fi
    printf "%s\t%s\n" "Query Analytics (QAN web app)" "https://$SERVER_IP:$PMM_PORT/qan"
    printf "%s\t%s\n" "Metrics Monitor (Grafana)" "https://$SERVER_IP:$PMM_PORT/graph"
    printf "%s\t%s\n" "Metrics Monitor username" "admin"
    printf "%s\t%s\n" "Metrics Monitor password" "admin"
    printf "%s\t%s\n" "Orchestrator" "https://$SERVER_IP:$PMM_PORT/orchestrator"
    ) | column -t -s $'\t'
  else
    (
    printf "%s\t%s\n" "PMM landing page" "http://$SERVER_IP:$PMM_PORT"
    if [ ! -z $pmm_server_username ];then
      printf "%s\t%s\n" "PMM landing page username" "$pmm_server_username"
    fi
    if [ ! -z $pmm_server_password ];then
      printf "%s\t%s\n" "PMM landing page password" "$pmm_server_password"
    fi
    printf "%s\t%s\n" "Query Analytics (QAN web app)" "http://$SERVER_IP/qan"
    printf "%s\t%s\n" "Metrics Monitor (Grafana)" "http://$SERVER_IP/graph"
    printf "%s\t%s\n" "Metrics Monitor username" "admin"
    printf "%s\t%s\n" "Metrics Monitor password" "admin"
    printf "%s\t%s\n" "Orchestrator" "http://$SERVER_IP/orchestrator"
    ) | column -t -s $'\t'
  fi
  echo -e "******************************************************************"
}

#Download and install PMM2.x client
install_client(){
  if [ ! -z $link_client ]; then
    PMM_CLIENT_TAR_URL=$link_client;
  else
    PMM_CLIENT_TAR_URL=$(lynx --listonly --dump https://www.percona.com/downloads/TESTING/pmm/ | grep  "pmm2-client" |awk '{print $2}'| grep "tar.gz" | head -n1)
  fi
  echo "PMM2 client  $PMM_CLIENT_TAR_URL"
  wget $PMM_CLIENT_TAR_URL
  PMM_CLIENT_TAR=$(echo $PMM_CLIENT_TAR_URL | grep -o '[^/]*$')
  tar -xzf $PMM_CLIENT_TAR
  PMM_CLIENT_BASEDIR=$(ls -1td pmm2-client-* 2>/dev/null | grep -v ".tar" | head -n1)
  pushd $PMM_CLIENT_BASEDIR > /dev/null
  echo "export PATH=$PATH:$PWD/bin" >> ~/.bash_profile
  source ~/.bash_profile
  pmm-admin --version
  pmm-agent setup --config-file=$PWD/config/pmm-agent.yaml --server-insecure-tls --server-address=$IP_ADDRESS:443
  pmm-agent --config-file=$PWD/config/pmm-agent.yaml > pmm-agent.log 2>&1 &
}

configure_client() {
  if [ ! -z $IP_ADDRESS ]; then
    if [ ! -z $setup ]; then
      pmm-agent setup --server-insecure-tls --server-address=$IP_ADDRESS:443
    else
      sudo pmm-agent setup --server-insecure-tls --server-address=$IP_ADDRESS:443
    fi
    SERVER_IP=$IP_ADDRESS
  else
    IP_ADDRESS=$(ip route get 8.8.8.8 | awk -F"src " 'NR==1{split($2,a," ");print a[1]}')
    SERVER_IP=$IP_ADDRESS
    if [ ! -z $setup ]; then
      pmm-agent setup --server-insecure-tls --server-address=$IP_ADDRESS:443
    else
      sudo pmm-agent setup --server-insecure-tls --server-address=$IP_ADDRESS:443
    fi
  fi
  sleep 5
}

setup_db_tar(){
  PRODUCT_NAME=$1
  SERVER_STRING=$2
  CLIENT_MSG=$3
  VERSION=$4
  if cat /etc/os-release | grep rhel >/dev/null ; then
   DISTRUBUTION=centos
  fi
  LINK=`$SCRIPT_PWD/../get_download_link.sh --product=${PRODUCT_NAME} --distribution=$DISTRUBUTION --version=$VERSION`
  echo "Downloading $CLIENT_MSG(Version : $VERSION)"
  FILE=`$SCRIPT_PWD/../get_download_link.sh --product=${PRODUCT_NAME} --distribution=$DISTRUBUTION --version=$VERSION | awk -F"/" '{print $7}'`
  if [ ! -f $FILE ]; then
    wget $LINK 2>/dev/null
  fi
  VERSION_ACCURATE=`$SCRIPT_PWD/../get_download_link.sh --product=${PRODUCT_NAME} --distribution=$DISTRUBUTION --version=$VERSION | awk -F"-" '{ print $3 }'`
  PORT_NUMBER=`$SCRIPT_PWD/../get_download_link.sh --product=${PRODUCT_NAME} --distribution=$DISTRUBUTION --version=$VERSION | awk -F"-" '{ print $3 }' | tr -d .`
  BASEDIR=$(ls -1td $SERVER_STRING 2>/dev/null | grep -v ".tar" | head -n1)
}
#Get PMM client basedir.
get_basedir(){
  PRODUCT_NAME=$1
  SERVER_STRING=$2
  CLIENT_MSG=$3
  VERSION=$4
  if cat /etc/os-release | grep rhel >/dev/null ; then
   DISTRUBUTION=centos
  fi
  if [ $download_link -eq 1 ]; then
    if [ -f $SCRIPT_PWD/../get_download_link.sh ]; then
      LINK=`$SCRIPT_PWD/../get_download_link.sh --product=${PRODUCT_NAME} --distribution=$DISTRUBUTION --version=$VERSION`
      echo "Downloading $CLIENT_MSG(Version : $VERSION)"
      wget $LINK 2>/dev/null
      BASEDIR=$(ls -1td $SERVER_STRING 2>/dev/null | grep -v ".tar" | head -n1)
      if [ -z $BASEDIR ]; then
        BASE_TAR=$(ls -1td $SERVER_STRING 2>/dev/null | grep ".tar" | head -n1)
        if [ ! -z $BASE_TAR ];then
          tar -xvf $BASE_TAR >/dev/null
          if [[ "${PRODUCT_NAME}" == "postgresql" ]]; then
            BASEDIR=$(ls -1td pgsql 2>/dev/null | grep -v ".tar" | head -n1)
          else
            BASEDIR=$(ls -1td $SERVER_STRING 2>/dev/null | grep -v ".tar" | head -n1)
          fi
          BASEDIR="$WORKDIR/$BASEDIR"
          rm -rf $BASEDIR/node*
        else
          echo "ERROR! $CLIENT_MSG(this script looked for '$SERVER_STRING') does not exist. Terminating."
          exit 1
        fi
      else
        BASEDIR="$WORKDIR/$BASEDIR"
      fi
    else
      echo "ERROR! $SCRIPT_PWD/../get_download_link.sh does not exist. Terminating."
      exit 1
    fi
  else
    BASEDIR=$(ls -1td $SERVER_STRING 2>/dev/null | grep -v ".tar" | head -n1)
    if [ -z $BASEDIR ]; then
      BASE_TAR=$(ls -1td $SERVER_STRING 2>/dev/null | grep ".tar" | head -n1)
      if [ ! -z $BASE_TAR ];then
        tar -xvf $BASE_TAR >/dev/null
        if [[ "${PRODUCT_NAME}" == "postgresql" ]]; then
            BASEDIR=$(ls -1td pgsql 2>/dev/null | grep -v ".tar" | head -n1)
        else
          BASEDIR=$(ls -1td $SERVER_STRING 2>/dev/null | grep -v ".tar" | head -n1)
        fi
        BASEDIR="$WORKDIR/$BASEDIR"
        if [[ "${CLIENT_NAME}" == "mo" ]]; then
          sudo rm -rf $BASEDIR/data
        else
          rm -rf $BASEDIR/node*
        fi
      else
        echo "ERROR! $CLIENT_MSG(this script looked for '$SERVER_STRING') does not exist. Terminating."
        exit 1
      fi
    else
      BASEDIR="$WORKDIR/$BASEDIR"
    fi
  fi
}

# Function to compare query count
compare_query(){
  insert_loop(){
    NUM_START=$((CURRENT_QUERY_COUNT + 1))
    NUM_END=$(shuf -i ${1} -n 1)
	TOTAL_QUERY_COUNT_BEFORE_RUN=$(${BASEDIR}/bin/mysql -uroot --socket=$TEST_SOCKET -Bse "SELECT COUNT_STAR  FROM performance_schema.events_statements_summary_by_digest WHERE DIGEST_TEXT LIKE 'INSERT INTO `test`%';")
    for i in `seq $NUM_START $NUM_END`; do
      STRING=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
      ${BASEDIR}/bin/mysql -uroot --socket=$TEST_SOCKET -e "INSERT INTO test.t1 (str) VALUES ('${STRING}')"
    done
	TOTAL_QUERY_COUNT_AFTER_RUN=$(${BASEDIR}/bin/mysql -uroot --socket=$TEST_SOCKET -Bse "SELECT COUNT_STAR  FROM performance_schema.events_statements_summary_by_digest WHERE DIGEST_TEXT LIKE 'INSERT INTO `test`%';")
	CURRENT_QUERY_COUNT=$((TOTAL_QUERY_COUNT_AFTER_RUN - TOTAL_QUERY_COUNT_BEFORE_RUN))
    START_TIME=$(${BASEDIR}/bin/mysql -uroot --socket=$TEST_SOCKET -Bse "SELECT FIRST_SEEN  FROM performance_schema.events_statements_summary_by_digest WHERE DIGEST_TEXT LIKE 'INSERT INTO `test`%';")
    END_TIME=$(${BASEDIR}/bin/mysql -uroot --socket=$TEST_SOCKET -Bse "SELECT LAST_SEEN  FROM performance_schema.events_statements_summary_by_digest WHERE DIGEST_TEXT LIKE 'INSERT INTO `test`%';")
  }

  #BASEDIR="/home/ramesh/pmmwork/ps57"
  TEST_SOCKET=$(sudo pmm-admin list | grep "mysql:metrics[ \t].*_NODE-" | head -1 | awk -F[\(\)] '{print $2}')
  TEST_NODE_NAME=$(sudo pmm-admin list | grep "mysql:metrics[ \t].*_NODE-" | head -1  | awk '{print $2}')
  if [ $disable_ssl -eq 1 ]; then
    sudo pmm-admin add mysql --user=root --socket=$TEST_SOCKET SHADOW_NODE --disable-ssl
  else
    sudo pmm-admin add mysql --user=root --socket=$TEST_SOCKET SHADOW_NODE
  fi
  if [ -z $TEST_SOCKET ];then
    echo "ERROR! PMM client instance does not exist. Terminating"
	exit 1
  fi
  echo "Initializing query count testing"
  ${BASEDIR}/bin/mysql -uroot --socket=$TEST_SOCKET -e "create database if not exists test;"  2>&1
  ${BASEDIR}/bin/mysql -uroot --socket=$TEST_SOCKET -e "create table test.t1 (id int auto_increment,str varchar(32), primary key(id))" 2>&1
  echo "Running first set INSERT statement execution"
  insert_loop 1000-5000
  echo "Sleeping 60 secs"
  sleep 60
  echo "INSERT INTO test.t1 .. query count between ${START_TIME} and ${END_TIME}"
  ${BASEDIR}/bin/mysql -uroot --socket=$TEST_SOCKET -e "SELECT DIGEST_TEXT QUERY,COUNT_STAR ALL_QUERY_COUNT,$CURRENT_QUERY_COUNT QUERY_COUNT_CURRENT_RUN FROM performance_schema.events_statements_summary_by_digest WHERE DIGEST_TEXT LIKE 'INSERT INTO `test`%';"
  echo "Running second set INSERT statement execution"
  insert_loop 5001-10000
  echo "Sleeping 60 secs"
  sleep 60
  echo "INSERT INTO test.t1 .. query count between ${START_TIME} and ${END_TIME}"
  ${BASEDIR}/bin/mysql -uroot --socket=$TEST_SOCKET -e "SELECT DIGEST_TEXT QUERY,COUNT_STAR ALL_QUERY_COUNT,$CURRENT_QUERY_COUNT QUERY_COUNT_CURRENT_RUN FROM performance_schema.events_statements_summary_by_digest WHERE DIGEST_TEXT LIKE 'INSERT INTO `test`%';"
  echo "Running third set INSERT statement execution"
  insert_loop 10001-15000
  echo "Sleeping 60 secs"
  sleep 60
  echo "INSERT INTO test.t1 .. query count between ${START_TIME} and ${END_TIME}"
  ${BASEDIR}/bin/mysql -uroot --socket=$TEST_SOCKET -e "SELECT DIGEST_TEXT QUERY,COUNT_STAR ALL_QUERY_COUNT,$CURRENT_QUERY_COUNT QUERY_COUNT_CURRENT_RUN FROM performance_schema.events_statements_summary_by_digest WHERE DIGEST_TEXT LIKE 'INSERT INTO `test`%';"
  echo "Running fourth set INSERT statement execution"
  insert_loop 15001-20000
  echo "Sleeping 60 secs"
  sleep 60
  echo "INSERT INTO test.t1 .. query count between ${START_TIME} and ${END_TIME}"
  ${BASEDIR}/bin/mysql -uroot --socket=$TEST_SOCKET -e "SELECT DIGEST_TEXT QUERY,COUNT_STAR ALL_QUERY_COUNT,$CURRENT_QUERY_COUNT QUERY_COUNT_CURRENT_RUN FROM performance_schema.events_statements_summary_by_digest WHERE DIGEST_TEXT LIKE 'INSERT INTO `test`%';"
  sleep 300
  echo "INSERT INTO test.t1 .. query count from pmm client instance $TEST_NODE_NAME (Performance Schema)."
  docker exec -it pmm-server mysql -e"select sum(query_count) from pmm.query_class_metrics where query_class_id in (select query_class_id from pmm.query_classes where fingerprint like 'INSERT%') and instance_id=(select instance_id from pmm.instances where name='$TEST_NODE_NAME');"
  echo "INSERT INTO test.t1 .. query count from pmm client instance SHADOW_NODE (Slow log)."
  docker exec -it pmm-server mysql -e"select sum(query_count) from pmm.query_class_metrics where query_class_id in (select query_class_id from pmm.query_classes where fingerprint like 'INSERT%') and instance_id=(select instance_id from pmm.instances where name='SHADOW_NODE');"
  echo "Please compare these query count with QAN/Metrics webpage"
}

check_disable_ssl(){
  EXPORTER_NAME=$1
  echo ${EXPORTER_NAME}
  PMM_OUTPUT=$(sudo pmm-admin list | grep ${EXPORTER_NAME} | grep 'scheme=http')
  if [ ! -z "$PMM_OUTPUT" ]; then
    echo "SSL Disabled Succcesfully for" ${EXPORTER_NAME}
  else
    echo "Could not disable_ssl Please check again"
    exit 1;
  fi
}

remove_packages(){
  if [[ "${package_name}" == "ps" ]]; then
    BASEDIR=$(ls -1td [Pp]ercona-[Ss]erver-${ps_version}* 2>/dev/null | grep -v ".tar" | head -n1)
    BASETAR=$(ls -1td [Pp]ercona-[Ss]erver-${ps_version}* 2>/dev/null | grep ".tar" | head -n1)
  elif [[ "${package_name}" == "psmyr" ]]; then
    BASEDIR=$(ls -1td [Pp]ercona-[Ss]erver-${ps_version}* 2>/dev/null | grep -v ".tar" | head -n1)
    BASETAR=$(ls -1td [Pp]ercona-[Ss]erver-${ps_version}* 2>/dev/null | grep ".tar" | head -n1)
  elif [[ "${package_name}" == "ms" ]]; then
    BASEDIR=$(ls -1td mysql-${ms_version}* 2>/dev/null | grep -v ".tar" | head -n1)
    BASETAR=$(ls -1td mysql-${ms_version}* 2>/dev/null | grep ".tar" | head -n1)
  elif [[ "${package_name}" == "pgsql" ]]; then
    BASEDIR=$(ls -1td postgresql-${pgsql_version}* 2>/dev/null | grep -v ".tar" | head -n1)
    BASETAR=$(ls -1td postgresql-${pgsql_version}* 2>/dev/null | grep ".tar" | head -n1)
  elif [[ "${package_name}" == "md" ]]; then
    BASEDIR=$(ls -1td mariadb-${md_version}* 2>/dev/null | grep -v ".tar" | head -n1)
    BASETAR=$(ls -1td mariadb-${md_version}* 2>/dev/null | grep ".tar" | head -n1)
  elif [[ "${package_name}" == "pxc" ]]; then
    BASEDIR=$(ls -1td Percona-XtraDB-Cluster-${pxc_version}* 2>/dev/null | grep -v ".tar" | head -n1)
    BASETAR=$(ls -1td Percona-XtraDB-Cluster-${pxc_version}* 2>/dev/null | grep ".tar" | head -n1)
  elif [[ "${package_name}" == "mo" ]]; then
    BASEDIR=$(ls -1td percona-server-mongodb-${mo_version}* 2>/dev/null | grep -v ".tar" | head -n1)
    BASETAR=$(ls -1td percona-server-mongodb-${mo_version}* 2>/dev/null | grep ".tar" | head -n1)
  fi
  if [[ ! -z $BASEDIR ]]; then
    sudo rm -rf $BASEDIR;
  fi
  if [[ ! -z $BASETAR ]]; then
    sudo rm -rf $BASETAR;
  fi
}

add_clients_pmm2(){
  mkdir -p $WORKDIR/logs
  for i in ${ADDCLIENT[@]};do
    CLIENT_NAME=$(echo $i | grep -o  '[[:alpha:]]*')
    ADDCLIENTS_COUNT=$(echo "${i}" | sed 's|[^0-9]||g')
    if [[ "${CLIENT_NAME}" == "ms" ]]; then
      setup_db_tar mysql "mysql-${ms_version}*" "MySQL Server binary tar ball" ${ms_version}
      if [ -d "$WORKDIR/mysql" ]; then
        rm -Rf $WORKDIR/mysql;
      fi
      mkdir $WORKDIR/mysql
      dbdeployer unpack mysql-${ms_version}* --sandbox-binary $WORKDIR/mysql --overwrite
      rm -Rf mysql-${ms_version}*
      if [[ "${ADDCLIENTS_COUNT}" == "1" ]]; then
        dbdeployer deploy single $VERSION_ACCURATE --sandbox-binary $WORKDIR/mysql --force
        node_port=`dbdeployer sandboxes --header | grep $VERSION_ACCURATE | grep 'single' | awk -F'[' '{print $2}' | awk -F' ' '{print $1}'`
        pmm-admin add mysql --use-perfschema --username=msandbox --password=msandbox 127.0.0.1:$node_port mysql-single
      else
        dbdeployer deploy multiple $VERSION_ACCURATE --sandbox-binary $WORKDIR/mysql --nodes $ADDCLIENTS_COUNT --force
        node_port=`dbdeployer sandboxes --header | grep $VERSION_ACCURATE | grep 'multiple' | awk -F'[' '{print $2}' | awk -F' ' '{print $1}'`
        for j in `seq 1  ${ADDCLIENTS_COUNT}`;do
          #node_port=`dbdeployer sandboxes --header | grep $VERSION_ACCURATE | grep 'multiple' | awk -F'[' '{print $2}' | awk -v var="$j" -F' ' '{print $var}'`
          pmm-admin add mysql --use-perfschema --username=msandbox --password=msandbox 127.0.0.1:$node_port mysql-multiple-node-$j --debug
          node_port=$(($node_port + 1))
        done
      fi
    fi
    if [[ "${CLIENT_NAME}" == "mo" ]]; then
      get_basedir psmdb "percona-server-mongodb-${mo_version}*" "Percona Server Mongodb binary tar ball" ${mo_version}
      rm -rf $BASEDIR/data
      for k in `seq 1  ${REPLCOUNT}`;do
          PSMDB_PORT=$(( (RANDOM%21 + 10) * 1001 ))
          PSMDB_PORTS+=($PSMDB_PORT)
          for j in `seq 1  ${ADDCLIENTS_COUNT}`;do
            PORT=$(( $PSMDB_PORT + $j - 1 ))
            mkdir -p ${BASEDIR}/data/rpldb${k}_${j}
            $BASEDIR/bin/mongod --profile 2 --slowms 1  $mongo_storage_engine  --replSet r${k} --dbpath=$BASEDIR/data/rpldb${k}_${j} --logpath=$BASEDIR/data/rpldb${k}_${j}/mongod.log --port=$PORT --logappend --fork &
            sleep 10
            if [ $disable_ssl -eq 1 ]; then
              pmm-admin add mongodb --cluster mongodb_cluster  --uri localhost:$PORT mongodb_inst_rpl${k}_${j} --disable-ssl
              check_disable_ssl mongodb_inst_rpl${k}_${j}
            else
              pmm-admin add mongodb --use-profiler --use-exporter --debug localhost:$PORT mongodb_inst_rpl${k}_${j}
            fi
          done
      done
    fi
  done
}

#Percona Server configuration.
add_clients(){
  mkdir -p $WORKDIR/logs
  for i in ${ADDCLIENT[@]};do
    CLIENT_NAME=$(echo $i | grep -o  '[[:alpha:]]*')
    if [[ "${CLIENT_NAME}" == "ps" && -z $PMM2 ]]; then
      PORT_CHECK=101
      NODE_NAME="PS_NODE"
      get_basedir ps "Percona-Server-${ps_version}*" "Percona Server binary tar ball" ${ps_version}
      MYSQL_CONFIG="--init-file ${SCRIPT_PWD}/QRT_Plugin.sql --log_output=file --slow_query_log=ON --long_query_time=0 --log_slow_rate_limit=100 --log_slow_rate_type=query --log_slow_verbosity=full --log_slow_admin_statements=ON --log_slow_slave_statements=ON --slow_query_log_always_write_time=1 --slow_query_log_use_global_control=all --innodb_monitor_enable=all --userstat=1"
    elif [[ "${CLIENT_NAME}" == "psmyr" ]]; then
      PORT_CHECK=601
      NODE_NAME="PSMR_NODE"
      get_basedir ps "[Pp]ercona-[Ss]erver-${ps_version}*" "Percona Server binary tar ball" ${ps_version}
      MYSQL_CONFIG="--init-file ${SCRIPT_PWD}/QRT_Plugin.sql --log_output=file --slow_query_log=ON --long_query_time=0 --log_slow_rate_limit=100 --log_slow_rate_type=query --log_slow_verbosity=full --log_slow_admin_statements=ON --log_slow_slave_statements=ON --slow_query_log_always_write_time=1 --slow_query_log_use_global_control=all --innodb_monitor_enable=all --userstat=1 --plugin-load-add=rocksdb=ha_rocksdb.so --default-storage-engine=rocksdb"
    elif [[ "${CLIENT_NAME}" == "ms" && -z $PMM2 ]]; then
      PORT_CHECK=201
      NODE_NAME="MS_NODE"
      get_basedir mysql "mysql-${ms_version}*" "MySQL Server binary tar ball" ${ms_version}
      MYSQL_CONFIG="--init-file ${SCRIPT_PWD}/QRT_Plugin.sql --innodb_monitor_enable=all --performance_schema=ON"
    elif [[ "${CLIENT_NAME}" == "pgsql" && -z $PMM2 ]]; then
      PORT_CHECK=501
      NODE_NAME="PGSQL_NODE"
      get_basedir postgresql "postgresql-${pgsql_version}*" "Postgre SQL Binary tar ball" ${pgsql_version}
    elif [[ "${CLIENT_NAME}" == "md" ]]; then
      PORT_CHECK=301
      NODE_NAME="MD_NODE"
      get_basedir mariadb "mariadb-${md_version}*" "MariaDB Server binary tar ball" ${md_version}
      MYSQL_CONFIG="--init-file ${SCRIPT_PWD}/QRT_Plugin.sql  --innodb_monitor_enable=all --performance_schema=ON"
    elif [[ "${CLIENT_NAME}" == "pxc" ]]; then
      PORT_CHECK=401
      NODE_NAME="PXC_NODE"
      get_basedir pxc "Percona-XtraDB-Cluster-${pxc_version}*" "Percona XtraDB Cluster binary tar ball" ${pxc_version}
      MYSQL_CONFIG="--init-file ${SCRIPT_PWD}/QRT_Plugin.sql --log_output=file --slow_query_log=ON --long_query_time=0 --log_slow_rate_limit=100 --log_slow_rate_type=query --log_slow_verbosity=full --log_slow_admin_statements=ON --log_slow_slave_statements=ON --slow_query_log_always_write_time=1 --slow_query_log_use_global_control=all --innodb_monitor_enable=all --userstat=1"
    elif [[ "${CLIENT_NAME}" == "mo" ]]; then
      get_basedir psmdb "percona-server-mongodb-${mo_version}*" "Percona Server Mongodb binary tar ball" ${mo_version}
    fi
    if [[ "${CLIENT_NAME}" != "md"  && "${CLIENT_NAME}" != "mo" && "${CLIENT_NAME}" != "pgsql" ]]; then
      VERSION="$(${BASEDIR}/bin/mysqld --version | grep -oe '[58]\.[5670]' | head -n1)"
    if [ "$VERSION" == "5.7" -o "$VERSION" == "8.0" ]; then
        MID="${BASEDIR}/bin/mysqld   --default-authentication-plugin=mysql_native_password --initialize-insecure --basedir=${BASEDIR}"
      else
        MID="${BASEDIR}/scripts/mysql_install_db --no-defaults --basedir=${BASEDIR}"
      fi
    else
      if [[ "${CLIENT_NAME}" != "mo" ]]; then
        MID="${BASEDIR}/scripts/mysql_install_db --no-defaults --basedir=${BASEDIR}"
      fi
    fi

    ADDCLIENTS_COUNT=$(echo "${i}" | sed 's|[^0-9]||g')
    if  [[ "${CLIENT_NAME}" == "mo" ]]; then
      rm -rf $BASEDIR/data
      for k in `seq 1  ${REPLCOUNT}`;do
        PSMDB_PORT=$(( (RANDOM%21 + 10) * 1001 ))
        PSMDB_PORTS+=($PSMDB_PORT)
          for j in `seq 1  ${ADDCLIENTS_COUNT}`;do
            PORT=$(( $PSMDB_PORT + $j - 1 ))
            mkdir -p ${BASEDIR}/data/rpldb${k}_${j}
            $BASEDIR/bin/mongod --profile 2 --slowms 1  $mongo_storage_engine  --replSet r${k} --dbpath=$BASEDIR/data/rpldb${k}_${j} --logpath=$BASEDIR/data/rpldb${k}_${j}/mongod.log --port=$PORT --logappend --fork &
            sleep 20
            if [ $disable_ssl -eq 1 ]; then
              sudo pmm-admin add mongodb --cluster mongodb_cluster  --uri localhost:$PORT mongodb_inst_rpl${k}_${j} --disable-ssl
              check_disable_ssl mongodb_inst_rpl${k}_${j}
            else
              sudo pmm-admin add mongodb --cluster mongodb_cluster  --uri localhost:$PORT mongodb_inst_rpl${k}_${j}
            fi
          done
      done
      create_replset_js()
      {
        REPLSET_COUNT=$(( ${ADDCLIENTS_COUNT} - 1 ))
        rm -rf /tmp/config_replset.js
        echo "port=parseInt(db.adminCommand(\"getCmdLineOpts\").parsed.net.port)" >> /tmp/config_replset.js
        for i in `seq 1  ${REPLSET_COUNT}`;do
          echo "port${i}=port+${i};" >> /tmp/config_replset.js
        done
        echo "conf = {" >> /tmp/config_replset.js
        echo "_id : replSet," >> /tmp/config_replset.js
        echo "members: [" >> /tmp/config_replset.js
        echo "  { _id:0 , host:\"localhost:\"+port,priority:10}," >> /tmp/config_replset.js
        for i in `seq 1  ${REPLSET_COUNT}`;do
          echo "  { _id:${i} , host:\"localhost:\"+port${i}}," >> /tmp/config_replset.js
        done
        echo "  ]" >> /tmp/config_replset.js
        echo "};" >> /tmp/config_replset.js

        echo "printjson(conf)" >> /tmp/config_replset.js
        echo "printjson(rs.initiate(conf));" >> /tmp/config_replset.js
      }
      create_replset_js
      if [[ "$with_replica" == "1" ]]; then
        for k in `seq 1  ${REPLCOUNT}`;do
	        n=$(( $k - 1 ))
		      echo "Configuring replicaset"
          sudo $BASEDIR/bin/mongo --quiet --port ${PSMDB_PORTS[$n]} --eval "var replSet='r${k}'" "/tmp/config_replset.js"
          sleep 20
	      done
	    fi
      if [ ! -z $PMM2 ]; then
        for p in `seq 1  ${REPLCOUNT}`;do
          n=$(( $p - 1 ))
          for r in `seq 1  ${ADDCLIENTS_COUNT}`;do
            PORT=$(( ${PSMDB_PORTS[$n]} + $r - 1 ))
            pmm-admin add mongodb --use-profiler --debug localhost:$PORT mongodb_inst_rpl${p}_${r}_$IP_ADDRESS --cluster mongodb_cluster
          done
        done
      fi
      if [[ "$with_sharding" == "1" ]]; then
        #config
        CONFIG_MONGOD_PORT=$(( (RANDOM%21 + 10) * 1001 ))
        CONFIG_MONGOS_PORT=$(( (RANDOM%21 + 10) * 1001 ))
        for m in `seq 1 ${ADDCLIENTS_COUNT}`;do
          PORT=$(( $CONFIG_MONGOD_PORT + $m - 1 ))
          mkdir -p $BASEDIR/data/confdb${m}
          $BASEDIR/bin/mongod --profile 2 --slowms 1 --fork --logpath $BASEDIR/data/confdb${m}/config_mongo.log --dbpath=$BASEDIR/data/confdb${m} --port $PORT --configsvr --replSet config &
          sleep 15
          if [ $disable_ssl -eq 1 ]; then
            sudo pmm-admin add mongodb --cluster mongodb_cluster  --uri localhost:$PORT mongodb_inst_config_rpl${m} --disable-ssl
            check_disable_ssl mongodb_inst_rpl${k}_${j}
          else
            if [ ! -z $PMM2 ]; then
              pmm-admin add mongodb --use-profiler --debug localhost:$PORT mongodb_inst_config_rpl${m}_$IP_ADDRESS
            else
              sudo pmm-admin add mongodb --cluster mongodb_cluster  --uri localhost:$PORT mongodb_inst_config_rpl${m}
            fi
          fi
          MONGOS_STARTUP_CMD="localhost:$PORT,$MONGOS_STARTUP_CMD"
        done

        echo "Configuring replicaset"
        $BASEDIR/bin/mongo --quiet --port ${CONFIG_MONGOD_PORT} --eval "var replSet='config'" "/tmp/config_replset.js"
        sleep 20

        MONGOS_STARTUP_CMD="${MONGOS_STARTUP_CMD::-1}"
        mkdir $BASEDIR/data/mongos
        #Removing default mongodb socket file
        sudo rm -rf /tmp/mongodb-27017.sock
        $BASEDIR/bin/mongos --fork --logpath $BASEDIR/data/mongos/mongos.log --configdb config/$MONGOS_STARTUP_CMD  &
        sleep 5
        if [ $disable_ssl -eq 1 ]; then
          sudo pmm-admin add mongodb --cluster mongodb_cluster --uri localhost:$CONFIG_MONGOD_PORT mongod_config_inst --disable-ssl
        else
          if [ ! -z $PMM2 ]; then
            pmm-admin add mongodb --cluster mongodb_cluster --debug localhost:$CONFIG_MONGOS_PORT mongos_config_inst_$IP_ADDRESS
          else
            sudo pmm-admin add mongodb --cluster mongodb_cluster --uri localhost:$CONFIG_MONGOS_PORT mongos_config_inst
          fi
        fi
        echo "Adding Shards"
		    sleep 20
        for k in `seq 1  ${REPLCOUNT}`;do
          n=$(( $k - 1 ))
          $BASEDIR/bin/mongo --quiet --eval "printjson(db.getSisterDB('admin').runCommand({addShard: 'r${k}/localhost:${PSMDB_PORTS[$n]}'}))"
        done
	    fi
    elif [[ -z $PMM2 && "${CLIENT_NAME}" == "pgsql" ]]; then
      if [ $create_pgsql_user -eq 1 ]; then
        PGSQL_USER=psql
        echo "Creating postgresql Dedicated User psql"
        if id psql >/dev/null 2>&1; then
          echo "yes the user psql exists"
        else
          echo "No, the user psql does not exist, Adding"
          sudo adduser --disabled-password --gecos "" psql
        fi
      else
        PGSQL_USER=nobody
      fi
      PGSQL_PORT=5431
      cd ${BASEDIR}/..
      result=pgsql
      sudo cp -u -R ${result} /home/
      BASEDIR=/home/pgsql
      cd ${BASEDIR}/bin
      sudo chmod +x .
      for j in `seq 1  ${ADDCLIENTS_COUNT}`;do
        PGSQL_PORT=$((PGSQL_PORT+j))
        echo "Current Path is $(pwd)"
        if [ -d ${BASEDIR}/${NODE_NAME}_${j}/data ]; then
          echo "PGSQL Data Directory Exist, Removing old Directory, Stopping already running Server and creating a new one"
          sudo -H -u ${PGSQL_USER} bash -c "./pg_ctl -D ${BASEDIR}/${NODE_NAME}_${j}/data -l ${BASEDIR}/${NODE_NAME}_${j}/data/logfile -o '-F -p ${PGSQL_PORT}' stop" > /dev/null 2>&1;
          sudo rm -r ${BASEDIR}/${NODE_NAME}_${j}
          sudo mkdir -p ${BASEDIR}/${NODE_NAME}_${j}/data
        else
          sudo mkdir -p ${BASEDIR}/${NODE_NAME}_${j}/data
        fi
        sudo_check ${PGSQL_USER}
        sudo chown -R ${PGSQL_USER} ${BASEDIR}/${NODE_NAME}_${j}/data
        echo "Starting PGSQL server at port ${PGSQL_PORT}"
        sudo -H -u ${PGSQL_USER} bash -c "./initdb -D ${BASEDIR}/${NODE_NAME}_${j}/data --username=postgres" > /dev/null 2>&1;
        sudo -H -u ${PGSQL_USER} bash -c "./pg_ctl -D ${BASEDIR}/${NODE_NAME}_${j}/data -l ${BASEDIR}/${NODE_NAME}_${j}/data/logfile -o '-F -p ${PGSQL_PORT}' start" > /dev/null 2>&1;
        sudo -H -u ${PGSQL_USER} bash -c "./createdb psql --username=postgres"
        if [ $disable_ssl -eq 1 ]; then
          sudo pmm-admin add postgresql --user postgres --host localhost --port ${PGSQL_PORT} --disable-ssl PGSQL-${NODE_NAME}-${j}
          check_disable_ssl PGSQL-${NODE_NAME}-${j}
        else
          sudo pmm-admin add postgresql --user postgres --host localhost --port ${PGSQL_PORT} PGSQL-${NODE_NAME}-${j}
        fi
      done
    elif [[ "${CLIENT_NAME}" == "pgsql" && ! -z $PMM2 ]]; then
      PGSQL_PORT=5432
      docker pull postgres:${pgsql_version}
      for j in `seq 1  ${ADDCLIENTS_COUNT}`;do
        check_port $PGSQL_PORT postgres
        docker run --name PGSQL_${pgsql_version}_${IP_ADDRESS}_$j -p $PGSQL_PORT:5432 -d postgres:${pgsql_version} -c shared_preload_libraries='pg_stat_statements' -c pg_stat_statements.max=10000 -c pg_stat_statements.track=all
        sleep 20
        docker exec PGSQL_${pgsql_version}_${IP_ADDRESS}_$j psql -h localhost -U postgres -c 'create extension pg_stat_statements'
        pmm-admin add postgresql localhost:$PGSQL_PORT PGSQL_${pgsql_version}_${IP_ADDRESS}_$j
        PGSQL_PORT=$((PGSQL_PORT+j))
      done
    elif [[ "${CLIENT_NAME}" == "ms" && ! -z $PMM2 ]]; then
      check_dbdeployer
      setup_db_tar mysql "mysql-${ms_version}*" "MySQL Server binary tar ball" ${ms_version}
      if [ -d "$WORKDIR/mysql" ]; then
        rm -Rf $WORKDIR/mysql;
      fi
      mkdir $WORKDIR/mysql
      dbdeployer unpack mysql-${ms_version}* --sandbox-binary $WORKDIR/mysql --overwrite
      rm -Rf mysql-${ms_version}*
      if [[ "${ADDCLIENTS_COUNT}" == "1" ]]; then
        dbdeployer deploy single $VERSION_ACCURATE --sandbox-binary $WORKDIR/mysql --force
        node_port=`dbdeployer sandboxes --header | grep $VERSION_ACCURATE | grep 'single' | awk -F'[' '{print $2}' | awk -F' ' '{print $1}'`
        pmm-admin add mysql --use-$query_source --username=msandbox --password=msandbox 127.0.0.1:$node_port mysql-single-$IP_ADDRESS
      else
        dbdeployer deploy multiple $VERSION_ACCURATE --sandbox-binary $WORKDIR/mysql --nodes $ADDCLIENTS_COUNT --force
        node_port=`dbdeployer sandboxes --header | grep $VERSION_ACCURATE | grep 'multiple' | awk -F'[' '{print $2}' | awk -F' ' '{print $1}'`
        for j in `seq 1  ${ADDCLIENTS_COUNT}`;do
          #node_port=`dbdeployer sandboxes --header | grep $VERSION_ACCURATE | grep 'multiple' | awk -F'[' '{print $2}' | awk -v var="$j" -F' ' '{print $var}'`
          pmm-admin add mysql --use-$query_source --username=msandbox --password=msandbox 127.0.0.1:$node_port mysql-multiple-node-$j-$IP_ADDRESS --debug
          node_port=$(($node_port + 1))
        done
      fi
    elif [[ "${CLIENT_NAME}" == "ps" && ! -z $PMM2 ]]; then
      PS_PORT=43306
      docker pull percona:${ps_version}
      for j in `seq 1  ${ADDCLIENTS_COUNT}`;do
        check_port $PS_PORT percona
        docker run --name ps_${ps_version}_${IP_ADDRESS}_$j -p $PS_PORT:3306 -e MYSQL_ROOT_PASSWORD=ps -d percona:${ps_version}
        sleep 20
        pmm-admin add mysql --use-$query_source --username=root --password=ps 127.0.0.1:$PS_PORT ps_${ps_version}_${IP_ADDRESS}_$j --debug
        PS_PORT=$((PS_PORT+j))
      done
    elif [[ "${CLIENT_NAME}" == "pxc" && ! -z $PMM2 ]]; then
      if [ -r ${BASEDIR}/lib/mysql/plugin/ha_tokudb.so ]; then
        TOKUDB_STARTUP="--plugin-load-add=tokudb=ha_tokudb.so --tokudb-check-jemalloc=0"
      else
        TOKUDB_STARTUP=""
      fi
      if [ -r ${BASEDIR}/lib/mysql/plugin/ha_rocksdb.so ]; then
        ROCKSDB_STARTUP="--plugin-load-add=rocksdb=ha_rocksdb.so"
      else
        ROCKSDB_STARTUP=""
      fi
      for j in `seq 1  ${ADDCLIENTS_COUNT}`;do
        RBASE1="$(( RBASE + ( $PORT_CHECK * $j ) ))"
        LADDR1="$ADDR:$(( RBASE1 + 8 ))"
        node="${BASEDIR}/node$j"
        if ${BASEDIR}/bin/mysqladmin -uroot -S/tmp/${NODE_NAME}_${j}.sock > /dev/null 2>&1; then
          echo "WARNING! Another mysqld process using Port -P${RBASE1}"
          if ! pmm-admin list | grep "${RBASE1}" > /dev/null ; then
            if [ $disable_ssl -eq 1 ]; then
              pmm-admin add mysql --username=root --use-$query_source --disable-ssl localhost:${RBASE1} ${NODE_NAME}-${j}
              check_disable_ssl ${NODE_NAME}-${j}
            else
              pmm-admin add mysql --username=root --use-$query_source localhost:${RBASE1} ${NODE_NAME}-${j}
            fi
          fi
          continue
        fi
        VERSION="$(${BASEDIR}/bin/mysqld --version | grep -oe '[58]\.[5670]' | head -n1)"
        if [ "$VERSION" == "5.7" -o "$VERSION" == "8.0" ]; then
          mkdir -p $node
          ${MID} --datadir=$node  > ${BASEDIR}/startup_node$j.err 2>&1
        else
          if [ ! -d $node ]; then
            ${MID} --datadir=$node  > ${BASEDIR}/startup_node$j.err 2>&1
          fi
        fi
        if  [[ "${CLIENT_NAME}" == "pxc" ]]; then
          WSREP_CLUSTER="${WSREP_CLUSTER}gcomm://$LADDR1,"
          if [ $j -eq 1 ]; then
            WSREP_CLUSTER_ADD="--wsrep_cluster_address=gcomm:// "
          else
            WSREP_CLUSTER_ADD="--wsrep_cluster_address=$WSREP_CLUSTER"
          fi
          MYEXTRA="--no-defaults --wsrep-provider=${BASEDIR}/lib/libgalera_smm.so $WSREP_CLUSTER_ADD --wsrep_provider_options=gmcast.listen_addr=tcp://$LADDR1 --wsrep_sst_method=rsync --wsrep_sst_auth=root: --max-connections=30000"
        else
          MYEXTRA="--no-defaults --max-connections=30000"
        fi
        if [[ "${CLIENT_NAME}" == "md" ]]; then
          MYEXTRA+=" --gtid-strict-mode=ON "
        else
          MYEXTRA+=" --gtid-mode=ON --enforce-gtid-consistency "
        fi
        ${BASEDIR}/bin/mysqld $MYEXTRA $MYSQL_CONFIG $TOKUDB_STARTUP $ROCKSDB_STARTUP $mysqld_startup_options --basedir=${BASEDIR} \
          --datadir=$node --log-error=$node/error.err --log-bin=mysql-bin \
          --socket=/tmp/${NODE_NAME}_${j}.sock --port=$RBASE1 --log-slave-updates \
          --server-id=10${j} > $node/error.err 2>&1 &
        function startup_chk(){
          for X in $(seq 0 ${SERVER_START_TIMEOUT}); do
            sleep 1
            if ${BASEDIR}/bin/mysqladmin -uroot -S/tmp/${NODE_NAME}_${j}.sock ping > /dev/null 2>&1; then
              ${BASEDIR}/bin/mysql  -uroot -S/tmp/${NODE_NAME}_${j}.sock -e "SET GLOBAL query_response_time_stats=ON;" > /dev/null 2>&1
              check_user=`${BASEDIR}/bin/mysql  -uroot -S/tmp/${NODE_NAME}_${j}.sock -e "SELECT user,host FROM mysql.user where user='$OUSER' and host='%';"`
              if [[ -z "$check_user" ]]; then
                ${BASEDIR}/bin/mysql  -uroot -S/tmp/${NODE_NAME}_${j}.sock -e "CREATE USER '$OUSER'@'%' IDENTIFIED BY '$OPASS';GRANT SUPER, PROCESS, REPLICATION SLAVE, RELOAD ON *.* TO '$OUSER'@'%'"
                (
                printf "%s\t%s\n" "Orchestrator username :" "admin"
                printf "%s\t%s\n" "Orchestrator password :" "passw0rd"
                ) | column -t -s $'\t'
              else
                echo "User '$OUSER' is already present in MySQL server. Please create Orchestrator user manually."
              fi
              break
            fi
          done
        }
        startup_chk
        if ! ${BASEDIR}/bin/mysqladmin -uroot -S/tmp/${NODE_NAME}_${j}.sock ping > /dev/null 2>&1; then
          if grep -q "TCP/IP port: Address already in use" $node/error.err; then
            echo "TCP/IP port: Address already in use, restarting ${NODE_NAME}_${j} mysqld daemon with different port"
            RBASE1="$(( RBASE1 - 1 ))"
            ${BASEDIR}/bin/mysqld $MYEXTRA $MYSQL_CONFIG $TOKUDB_STARTUP $ROCKSDB_STARTUP $mysqld_startup_options --basedir=${BASEDIR} \
               --datadir=$node --log-error=$node/error.err --log-bin=mysql-bin \
               --socket=/tmp/${NODE_NAME}_${j}.sock --port=$RBASE1 --log-slave-updates \
               --server-id=10${j} > $node/error.err 2>&1 &
            startup_chk
            if ! ${BASEDIR}/bin/mysqladmin -uroot -S/tmp/${NODE_NAME}_${j}.sock ping > /dev/null 2>&1; then
              echo "ERROR! ${NODE_NAME} startup failed. Please check error log $node/error.err"
              exit 1
            fi
          else
            echo "ERROR! ${NODE_NAME} startup failed. Please check error log $node/error.err"
            exit 1
          fi
        fi
        if [ $disable_ssl -eq 1 ]; then
          pmm-admin add mysql --username=root --use-$query_source --disable-ssl localhost:${RBASE1} ${NODE_NAME}-${j}
          check_disable_ssl ${NODE_NAME}-${j}
        else
          pmm-admin add mysql --username=root --use-$query_source localhost:${RBASE1} ${NODE_NAME}-${j}
        fi
      done
      pxc_proxysql_setup_pmm2(){
        if  [[ "${CLIENT_NAME}" == "pxc" ]]; then
          if [[ ! -e $(which proxysql 2> /dev/null) ]] ;then
            echo "The program 'proxysql' is currently not installed. Installing proxysql from percona repository"
            if grep -iq "ubuntu"  /etc/os-release ; then
              sudo apt install -y proxysql
            fi
            if grep -iq "centos"  /etc/os-release ; then
              sudo yum install -y proxysql
            fi
            if grep -iq "rhel"  /etc/os-release ; then
              sudo yum install -y proxysql
            fi
            if [[ ! -e $(which proxysql 2> /dev/null) ]] ;then
              echo "ERROR! Could not install proxysql on CentOS/Ubuntu machine. Terminating"
              exit 1
            fi
          fi
          sudo service proxysql start
          sleep 5
          PXC_PORT=$(pmm-admin list | grep "PXC_NODE-1" | awk -F":" '{print $2}' | awk -F" " '{print $1}')
          ${BASEDIR}/bin/mysql -uroot --socket=/tmp/PXC_NODE_1.sock -e"grant all on *.* to admin@'%' identified by 'admin'"
          sudo sed -i "s/3306/${PXC_PORT}/" /etc/proxysql-admin.cnf
          sudo proxysql-admin -e > $WORKDIR/logs/proxysql-admin.log
          if [ $disable_ssl -eq 1 ]; then
            sudo pmm-admin add proxysql --disable-ssl
          else
            sudo pmm-admin add proxysql
          fi
        else
          echo "Could not find PXC nodes. Skipping proxysql setup"
        fi
      }
    else
      if [ -r ${BASEDIR}/lib/mysql/plugin/ha_tokudb.so ]; then
        TOKUDB_STARTUP="--plugin-load-add=tokudb=ha_tokudb.so --tokudb-check-jemalloc=0"
      else
        TOKUDB_STARTUP=""
      fi
      if [ -r ${BASEDIR}/lib/mysql/plugin/ha_rocksdb.so ]; then
        ROCKSDB_STARTUP="--plugin-load-add=rocksdb=ha_rocksdb.so"
      else
        ROCKSDB_STARTUP=""
      fi
      for j in `seq 1  ${ADDCLIENTS_COUNT}`;do
        RBASE1="$(( RBASE + ( $PORT_CHECK * $j ) ))"
        LADDR1="$ADDR:$(( RBASE1 + 8 ))"
        node="${BASEDIR}/node$j"
        if ${BASEDIR}/bin/mysqladmin -uroot -S/tmp/${NODE_NAME}_${j}.sock ping > /dev/null 2>&1; then
          echo "WARNING! Another mysqld process using /tmp/${NODE_NAME}_${j}.sock"
          if ! sudo pmm-admin list | grep "/tmp/${NODE_NAME}_${j}.sock" > /dev/null ; then
            if [ $disable_ssl -eq 1 ]; then
              sudo pmm-admin add mysql ${NODE_NAME}-${j} --socket=/tmp/${NODE_NAME}_${j}.sock --user=root --query-source=$query_source --disable-ssl
              check_disable_ssl ${NODE_NAME}-${j}
            else
              sudo pmm-admin add mysql ${NODE_NAME}-${j} --socket=/tmp/${NODE_NAME}_${j}.sock --user=root --query-source=$query_source
            fi
          fi
          continue
        fi
        VERSION="$(${BASEDIR}/bin/mysqld --version | grep -oe '[58]\.[5670]' | head -n1)"
        if [ "$VERSION" == "5.7" -o "$VERSION" == "8.0" ]; then
          mkdir -p $node
          ${MID} --datadir=$node  > ${BASEDIR}/startup_node$j.err 2>&1
        else
          if [ ! -d $node ]; then
            ${MID} --datadir=$node  > ${BASEDIR}/startup_node$j.err 2>&1
          fi
        fi
        if  [[ "${CLIENT_NAME}" == "pxc" ]]; then
          WSREP_CLUSTER="${WSREP_CLUSTER}gcomm://$LADDR1,"
          if [ $j -eq 1 ]; then
            WSREP_CLUSTER_ADD="--wsrep_cluster_address=gcomm:// "
          else
            WSREP_CLUSTER_ADD="--wsrep_cluster_address=$WSREP_CLUSTER"
          fi
          MYEXTRA="--no-defaults --wsrep-provider=${BASEDIR}/lib/libgalera_smm.so $WSREP_CLUSTER_ADD --wsrep_provider_options=gmcast.listen_addr=tcp://$LADDR1 --wsrep_sst_method=rsync --wsrep_sst_auth=root: --max-connections=30000"
        else
          MYEXTRA="--no-defaults --max-connections=30000"
        fi
        if [[ "${CLIENT_NAME}" == "md" ]]; then
          MYEXTRA+=" --gtid-strict-mode=ON "
        else
          MYEXTRA+=" --gtid-mode=ON --enforce-gtid-consistency "
        fi
        ${BASEDIR}/bin/mysqld $MYEXTRA $MYSQL_CONFIG $TOKUDB_STARTUP $ROCKSDB_STARTUP $mysqld_startup_options --basedir=${BASEDIR} \
          --datadir=$node --log-error=$node/error.err --log-bin=mysql-bin \
          --socket=/tmp/${NODE_NAME}_${j}.sock --port=$RBASE1 --log-slave-updates \
          --server-id=10${j} > $node/error.err 2>&1 &
        function startup_chk(){
          for X in $(seq 0 ${SERVER_START_TIMEOUT}); do
            sleep 1
            if ${BASEDIR}/bin/mysqladmin -uroot -S/tmp/${NODE_NAME}_${j}.sock ping > /dev/null 2>&1; then
              ${BASEDIR}/bin/mysql  -uroot -S/tmp/${NODE_NAME}_${j}.sock -e "SET GLOBAL query_response_time_stats=ON;" > /dev/null 2>&1
              check_user=`${BASEDIR}/bin/mysql  -uroot -S/tmp/${NODE_NAME}_${j}.sock -e "SELECT user,host FROM mysql.user where user='$OUSER' and host='%';"`
              if [[ -z "$check_user" ]]; then
                ${BASEDIR}/bin/mysql  -uroot -S/tmp/${NODE_NAME}_${j}.sock -e "CREATE USER '$OUSER'@'%' IDENTIFIED BY '$OPASS';GRANT SUPER, PROCESS, REPLICATION SLAVE, RELOAD ON *.* TO '$OUSER'@'%'"
                (
                printf "%s\t%s\n" "Orchestrator username :" "admin"
                printf "%s\t%s\n" "Orchestrator password :" "passw0rd"
                ) | column -t -s $'\t'
              else
                echo "User '$OUSER' is already present in MySQL server. Please create Orchestrator user manually."
              fi
              break
            fi
          done
        }
        startup_chk
        if ! ${BASEDIR}/bin/mysqladmin -uroot -S/tmp/${NODE_NAME}_${j}.sock ping > /dev/null 2>&1; then
          if grep -q "TCP/IP port: Address already in use" $node/error.err; then
            echo "TCP/IP port: Address already in use, restarting ${NODE_NAME}_${j} mysqld daemon with different port"
            RBASE1="$(( RBASE1 - 1 ))"
            ${BASEDIR}/bin/mysqld $MYEXTRA $MYSQL_CONFIG $TOKUDB_STARTUP $ROCKSDB_STARTUP $mysqld_startup_options --basedir=${BASEDIR} \
               --datadir=$node --log-error=$node/error.err --log-bin=mysql-bin \
               --socket=/tmp/${NODE_NAME}_${j}.sock --port=$RBASE1 --log-slave-updates \
               --server-id=10${j} > $node/error.err 2>&1 &
            startup_chk
            if ! ${BASEDIR}/bin/mysqladmin -uroot -S/tmp/${NODE_NAME}_${j}.sock ping > /dev/null 2>&1; then
              echo "ERROR! ${NODE_NAME} startup failed. Please check error log $node/error.err"
              exit 1
            fi
          else
            echo "ERROR! ${NODE_NAME} startup failed. Please check error log $node/error.err"
            exit 1
          fi
        fi
        if [ $disable_ssl -eq 1 ]; then
          sudo pmm-admin add mysql ${NODE_NAME}-${j} --socket=/tmp/${NODE_NAME}_${j}.sock --user=root --query-source=$query_source --disable-ssl
          check_disable_ssl ${NODE_NAME}-${j}
        else
          sudo pmm-admin add mysql ${NODE_NAME}-${j} --socket=/tmp/${NODE_NAME}_${j}.sock --user=root --query-source=$query_source
        fi
      done
      pxc_proxysql_setup(){
        if  [[ "${CLIENT_NAME}" == "pxc" ]]; then
          if [[ ! -e $(which proxysql 2> /dev/null) ]] ;then
            echo "The program 'proxysql' is currently not installed. Installing proxysql from percona repository"
            if grep -iq "ubuntu"  /etc/os-release ; then
              sudo apt install -y proxysql
            fi
            if grep -iq "centos"  /etc/os-release ; then
              sudo yum install -y proxysql
            fi
            if grep -iq "rhel"  /etc/os-release ; then
              sudo yum install -y proxysql
            fi
            if [[ ! -e $(which proxysql 2> /dev/null) ]] ;then
              echo "ERROR! Could not install proxysql on CentOS/Ubuntu machine. Terminating"
              exit 1
            fi
          fi
          sleep 5
          sudo service proxysql start
          PXC_SOCKET=$(sudo pmm-admin list | grep "mysql:metrics[ \t]*PXC_NODE-1" | awk -F[\(\)] '{print $2}')
          PXC_BASE_PORT=$(${BASEDIR}/bin/mysql -uroot --socket=$PXC_SOCKET -Bse"select @@port")
          ${BASEDIR}/bin/mysql -uroot --socket=$PXC_SOCKET -e"grant all on *.* to admin@'%' identified by 'admin'"
          sudo sed -i "s/3306/${PXC_BASE_PORT}/" /etc/proxysql-admin.cnf
          sudo proxysql-admin -e > $WORKDIR/logs/proxysql-admin.log
          if [ $disable_ssl -eq 1 ]; then
            sudo pmm-admin add proxysql:metrics --disable-ssl
          else
            sudo pmm-admin add proxysql:metrics
          fi
        else
          echo "Could not find PXC nodes. Skipping proxysql setup"
        fi
      }
    fi
  done
  if [ ! -z $compare_query_count ]; then
    compare_query
  fi
}

check_port (){
  PORT=$1
  DB=$2
  if [[ $(sudo docker ps | grep $DB | grep 0.0.0.0:$PORT) ]]; then
    if [[ $DB == "postgres" ]]; then
      PGSQL_PORT=$((PGSQL_PORT+j))
      check_port $PGSQL_PORT postgres
    fi
    if [[ $DB == "percona" ]]; then
      PS_PORT=$((PS_PORT+j))
      check_port $PS_PORT percona
    fi
  fi
}

pmm_docker_client_startup(){
  centos_docker_client(){
    rm -rf Dockerfile docker-compose.yml
    echo "FROM centos:centos6" >> Dockerfile
    echo "RUN yum install -y http://www.percona.com/downloads/percona-release/redhat/0.1-4/percona-release-0.1-4.noarch.rpm" >> Dockerfile
    echo "RUN yum install -y yum install Percona-Server-server-57 pmm-client" >> Dockerfile
    echo "RUN echo \"UNINSTALL PLUGIN validate_password;\" > init.sql " >> Dockerfile
    echo "RUN echo \"ALTER USER  root@localhost IDENTIFIED BY '';\" >> init.sql " >> Dockerfile
    echo "RUN echo \"CREATE USER root@'%';\" >> init.sql " >> Dockerfile
    echo "RUN echo \"GRANT ALL ON *.* TO root@'%';\" >> init.sql" >> Dockerfile
    echo "RUN service mysql start" >> Dockerfile
    echo "EXPOSE 3306 42000 42002 42003 42004" >> Dockerfile
    echo "centos_ps:" >> docker-compose.yml
    echo "   build: ." >> docker-compose.yml
    echo "   hostname: centos_ps1" >> docker-compose.yml
    echo "   command: sh -c \"mysqld --init-file=/init.sql --user=root\"" >> docker-compose.yml
    echo "   ports:" >> docker-compose.yml
    echo "      - \"3306\"" >> docker-compose.yml
    echo "      - \"42000\"" >> docker-compose.yml
    echo "      - \"42002\"" >> docker-compose.yml
    echo "      - \"42003\"" >> docker-compose.yml
    echo "      - \"42004\"" >> docker-compose.yml
    docker-compose up >/dev/null 2>&1 &
    BASE_DIR=$(basename "$PWD")
    BASE_DIR=${BASE_DIR//[^[:alnum:]]/}
    while ! docker ps | grep ${BASE_DIR}_centos_ps_1 > /dev/null; do
      sleep 5 ;
    done
    DOCKER_CONTAINER_NAME=$(docker ps | grep ${BASE_DIR}_centos_ps | awk '{print $NF}')
    IP_ADD=$(ip route get 8.8.8.8 | awk -F"src " 'NR==1{split($2,a," ");print a[1]}')
    if [ ! -z $DOCKER_CONTAINER_NAME ]; then
      echo -e "\nAdding pmm-client instance from CentOS docker container to the currently live PMM server"
      IP_DOCKER_ADD=$(docker exec -it $DOCKER_CONTAINER_NAME ip route get 8.8.8.8 | awk -F"src " 'NR==1{split($2,a," ");print a[1]}')
      docker exec -it $DOCKER_CONTAINER_NAME pmm-admin config --server $IP_ADD --bind-address $IP_DOCKER_ADD
      docker exec -it $DOCKER_CONTAINER_NAME pmm-admin add mysql
    fi
  }

  ubuntu_docker_client(){
    rm -rf Dockerfile docker-compose.yml
    echo "FROM ubuntu:16.04" >> Dockerfile
    echo "RUN apt-get update" >> Dockerfile
    echo "RUN apt-get install -y wget lsb-release net-tools vim iproute" >> Dockerfile
    echo "RUN wget http://repo.percona.com/apt/percona-release_0.1-4.\$(lsb_release -sc)_all.deb" >> Dockerfile
    echo "RUN dpkg -i percona-release_0.1-4.\$(lsb_release -sc)_all.deb" >> Dockerfile
    echo "RUN apt-get update" >> Dockerfile
    echo "RUN apt-get install -y percona-server-server-5.7 pmm-client" >> Dockerfile
    echo "RUN echo \"CREATE USER root@'%';\" > init.sql " >> Dockerfile
    echo "RUN echo \"GRANT ALL ON *.* TO root@'%';\" >> init.sql" >> Dockerfile
    echo "RUN service mysql start" >> Dockerfile
    echo "EXPOSE 3306 42000 42002 42003 42004" >> Dockerfile
    echo "ubuntu_ps:" >> docker-compose.yml
    echo "   build: ." >> docker-compose.yml
    echo "   hostname: ubuntu_ps1" >> docker-compose.yml
    echo "   command: sh -c \"mysqld --init-file=/init.sql\"" >> docker-compose.yml
    echo "   ports:" >> docker-compose.yml
    echo "      - 3306:3306" >> docker-compose.yml
    echo "      - 42000:42000" >> docker-compose.yml
    echo "      - 42002:42002" >> docker-compose.yml
    echo "      - 42003:42003" >> docker-compose.yml
    echo "      - 42004:42004" >> docker-compose.yml
    docker-compose up >/dev/null 2>&1 &
    BASE_DIR=$(basename "$PWD")
    BASE_DIR=${BASE_DIR//[^[:alnum:]]/}
    while ! docker ps | grep ${BASE_DIR}_ubuntu_ps_1 > /dev/null; do
      sleep 5 ;
    done
    DOCKER_CONTAINER_NAME=$(docker ps | grep ${BASE_DIR}_ubuntu_ps | awk '{print $NF}')
    IP_ADD=$(ip route get 8.8.8.8 | awk -F"src " 'NR==1{split($2,a," ");print a[1]}')
    if [ ! -z $DOCKER_CONTAINER_NAME ]; then
      echo -e "\nAdding pmm-client instance from Ubuntu docker container to the currently live PMM server"
      IP_DOCKER_ADD=$(docker exec -it $DOCKER_CONTAINER_NAME ip route get 8.8.8.8 | awk -F"src " 'NR==1{split($2,a," ");print a[1]}')
      docker exec -it $DOCKER_CONTAINER_NAME pmm-admin config --server $IP_ADD --bind-address $IP_DOCKER_ADD
      docker exec -it $DOCKER_CONTAINER_NAME pmm-admin add mysql
    fi
  }

  centos_docker_client
  ubuntu_docker_client
}

clean_clients(){
  if [[ ! -e $(which mysqladmin 2> /dev/null) ]] ;then
    MYSQLADMIN_CLIENT=$(find . -name mysqladmin | head -n1)
  else
    MYSQLADMIN_CLIENT=$(which mysqladmin)
  fi
  if [[ -z "$MYSQLADMIN_CLIENT" ]];then
   echo "ERROR! 'mysqladmin' is currently not installed. Please install mysqladmin. Terminating."
   exit 1
  fi
  #Shutdown all mysql client instances
  if [[ -z $PMM2 ]]; then
    for i in $(sudo pmm-admin list | grep "mysql:metrics[ \t].*_NODE-" | awk -F[\(\)] '{print $2}'  | sort -r) ; do
      echo -e "Shutting down mysql instance (--socket=${i})"
      ${MYSQLADMIN_CLIENT} -uroot --socket=${i} shutdown
     sleep 2
    done
    if sudo pmm-admin list | grep -q 'No services under monitoring' ; then
      echo -e "No services under pmm monitoring"
    else
    #Remove all client instances
      echo -e "Removing all local pmm client instances"
      sudo pmm-admin remove --all 2&>/dev/null
    fi
 else 
    for i in $(pmm-admin list | grep -E "MySQL" | awk -F " " '{print $2}'  | sort -r) ; do
      pmm-admin remove mysql $i
    
    done
    for i in $(pmm-admin list | grep -E "MongoDB" | awk -F " " '{print $2}'  | sort -r) ; do
      pmm-admin remove mongodb $i
    done
     
    for i in $(pmm-admin list | grep -E "PostgreSQL" | awk -F " " '{print $2}'  | sort -r) ; do
      pmm-admin remove postgresql $i
    done 
   #Remove PS and PostgreSQL  docker containers
    for i in $(docker ps -f name=ps -f name=PGS -q) ; do
      docker rm -f $i
    done
    dbdeployer delete all --skip-confirm 
 fi
   #Kill mongodb processes
    sudo killall mongod 2> /dev/null
    sudo killall mongos 2> /dev/null
    sleep 5
}

clean_docker_clients(){
  #Remove docker pmm-clients
  BASE_DIR=$(basename "$PWD")
  BASE_DIR=${BASE_DIR//[^[:alnum:]]/}
  echo -e "Removing pmm-client instances from docker containers"
  sudo docker exec -it ${BASE_DIR}_centos_ps_1  pmm-admin remove --all 2&> /dev/null
  sudo docker exec -it ${BASE_DIR}_ubuntu_ps_1  pmm-admin remove --all  2&> /dev/null
  echo -e "Removing pmm-client docker containers"
  sudo docker stop ${BASE_DIR}_ubuntu_ps_1 ${BASE_DIR}_centos_ps_1  2&> /dev/null
  sudo docker rm ${BASE_DIR}_ubuntu_ps_1 ${BASE_DIR}_centos_ps_1  2&> /dev/null
}

clean_server(){
  #Stop/Remove pmm-server docker/ami/ova instances
  if [[ "$pmm_server" == "docker" ]] ; then
    echo -e "Removing pmm-server docker containers"
    sudo docker stop pmm-server  2&> /dev/null
    sudo docker rm pmm-server pmm-data  2&> /dev/null
  elif [[ "$pmm_server" == "ova" ]] ; then
	VMBOX=$(vboxmanage list runningvms | grep "PMM-Server" | awk -F[\"\"] '{print $2}')
	echo "Shutting down ova instance"
	VBoxManage controlvm $VMBOX poweroff
	echo "Unregistering ova instance"
	VBoxManage unregistervm $VMBOX --delete
	 VM_DISKS=($(vboxmanage list hdds | grep -B4 $VMBOX | grep UUID | grep -v 'Parent UUID:' | awk '{ print $2}'))
	for i in ${VM_DISKS[@]}; do
	  VBoxManage closemedium disk $i --delete ;
	done
  elif [[ "$pmm_server" == "ami" ]] ; then
    if [ -f $WORKDIR/aws_instance_config.txt ]; then
      INSTANCE_ID=$(cat $WORKDIR/aws_instance_config.txt | grep "InstanceId"  | awk -F[\"\"] '{print $4}')
	else
	  echo "ERROR! Could not read aws instance id. $WORKDIR/aws_instance_config.txt does not exist. Terminating"
	  exit 1
	fi
    aws ec2 terminate-instances --instance-ids $INSTANCE_ID > $WORKDIR/aws_remove_instance.log
  fi

}

upgrade_server(){
  #Stop/Remove pmm-server
  if [[ "$pmm_server" == "docker" ]] ; then
    SERVER_USER=$(sudo pmm-admin show-passwords| grep 'User'|awk '{print $3}')
    SERVER_PASSWORD=$(sudo pmm-admin show-passwords| grep 'Password'|awk '{print $3}')
    IS_SSL=$(sudo pmm-admin info |grep 'SSL')
    echo -e "Removing pmm-server docker containers"
    sudo docker stop pmm-server  2&> /dev/null
    sudo docker rm pmm-server 2&> /dev/null
    if [ -z $dev ]; then
      if [ "$IS_SSL" == "Yes" ];then
        sudo docker run -d -p $PMM_PORT:443 -p 8500:8500 -e METRICS_MEMORY=$MEMORY  -e SERVER_USER="$pmm_server_username" -e SERVER_PASSWORD="$pmm_server_password" -e ORCHESTRATOR_USER=$OUSER -e ORCHESTRATOR_PASSWORD=$OPASS --volumes-from pmm-data --name pmm-server --restart always percona/pmm-server:$PMM_VERSION 2>/dev/null
      else
        sudo docker run -d -p $PMM_PORT:80 -p 8500:8500 -e METRICS_MEMORY=$MEMORY -e SERVER_USER="$pmm_server_username" -e SERVER_PASSWORD="$pmm_server_password" -e ORCHESTRATOR_USER=$OUSER -e ORCHESTRATOR_PASSWORD=$OPASS --volumes-from pmm-data --name pmm-server --restart always percona/pmm-server:$PMM_VERSION 2>/dev/null
      fi
    else
      if [ "$IS_SSL" == "Yes" ];then
        sudo docker run -d -p $PMM_PORT:443 -p 8500:8500 -e METRICS_MEMORY=$MEMORY -e SERVER_USER="$pmm_server_username" -e SERVER_PASSWORD="$pmm_server_password" -e ORCHESTRATOR_USER=$OUSER -e ORCHESTRATOR_PASSWORD=$OPASS --volumes-from pmm-data --name pmm-server --restart always perconalab/pmm-server:$PMM_VERSION 2>/dev/null
      else
        sudo docker run -d -p $PMM_PORT:80 -p 8500:8500 -e METRICS_MEMORY=$MEMORY -e SERVER_USER="$pmm_server_username" -e SERVER_PASSWORD="$pmm_server_password" -e ORCHESTRATOR_USER=$OUSER -e ORCHESTRATOR_PASSWORD=$OPASS --volumes-from pmm-data --name pmm-server --restart always perconalab/pmm-server:$PMM_VERSION 2>/dev/null
      fi
    fi

  else
    echo "AMI/OVA images upgrade is not implemented yet"
    exit 1
  fi

}

upgrade_client(){
  #Install new pmm-client
  echo "Installing new pmm-client tarball from TESTING directory..."
  PMM_CLIENT_TARBALL_URL=$(lynx --listonly --dump https://www.percona.com/downloads/TESTING/pmm/ | grep  "pmm-client" |awk '{print $2}'| grep "tar.gz" | head -n1)
  echo "PMM client tarball $PMM_CLIENT_TARBALL_URL"
  wget $PMM_CLIENT_TARBALL_URL
  PMM_CLIENT_TAR=$(echo $PMM_CLIENT_TARBALL_URL | grep -o '[^/]*$')
  tar -xzf $PMM_CLIENT_TAR
  PMM_CLIENT_BASEDIR=$(ls -1td pmm-client-* 2>/dev/null | grep -v ".tar" | head -n1)
  pushd $PMM_CLIENT_BASEDIR > /dev/null
  sudo ./install
  popd > /dev/null
  if [[ $(sudo pmm-admin list |grep metrics) ]]; then
    echo "Upgrade client has been finished successfully"
  else
    echo "There is no any instances, please check pmm-admin list output"
  fi
}

wipe_pmm2_clients () {

  if [[ $(pmm-admin list | grep "MySQL" | awk -F" " '{print $2}') ]]; then
    IFS=$'\n'
    for i in $(pmm-admin list | grep "MySQL" | awk -F" " '{print $2}') ; do
        echo "$i"
        MYSQL_SERVICE_ID=${i}
        pmm-admin remove mysql ${MYSQL_SERVICE_ID}
    done
  fi
  if [[ $(pmm-admin list | grep "PostgreSQL" | awk -F" " '{print $2}') ]]; then
    IFS=$'\n'
    for i in $(pmm-admin list | grep "PostgreSQL" | awk -F" " '{print $2}') ; do
        echo "$i"
        PGSQL_SERVICE_ID=${i}
        pmm-admin remove postgresql ${PGSQL_SERVICE_ID}
    done
  fi
  if [[ $(pmm-admin list | grep "MongoDB" | awk -F" " '{print $2}') ]]; then
    IFS=$'\n'
    for i in $(pmm-admin list | grep "MongoDB" | awk -F" " '{print $2}') ; do
        echo "$i"
        MONGODB_SERVICE_ID=${i}
        pmm-admin remove mongodb ${MONGODB_SERVICE_ID}
    done
  fi
}

sysbench_prepare(){
  if [[ ! -e $(which mysql 2> /dev/null) ]] ;then
    MYSQL_CLIENT=$(find . -type f -name mysql | head -n1)
  else
    MYSQL_CLIENT=$(which mysql)
  fi
  if [[ -z "$MYSQL_CLIENT" ]];then
   echo "ERROR! 'mysql' is currently not installed. Please install mysql. Terminating."
   exit 1
  fi
  #Initiate sysbench data load on all mysql client instances
  for i in $(sudo pmm-admin list | grep "mysql:metrics[ \t].*_NODE-" | awk -F[\(\)] '{print $2}'  | sort -r) ; do
    DB_NAME=$(echo ${i}  | awk -F[\/\.] '{print $3}')
	DB_NAME="${DB_NAME}_${storage_engine}"
    $MYSQL_CLIENT --user=root --socket=${i} -e "drop database if exists ${DB_NAME};create database ${DB_NAME};"
    sysbench /usr/share/sysbench/oltp_insert.lua --table-size=10000 --tables=16 --mysql-db=${DB_NAME} --mysql-user=root --mysql-storage-engine=$storage_engine  --threads=16 --db-driver=mysql --mysql-socket=${i} prepare  > $WORKDIR/logs/sysbench_prepare_${DB_NAME}.txt 2>&1
    check_script $? "Failed to run sysbench dataload"
  done
}

sysbench_run(){
  #Initiate sysbench oltp run on all mysql client instances
  for i in $(sudo pmm-admin list | grep "mysql:metrics[ \t].*_NODE-" | awk -F[\(\)] '{print $2}'  | sort -r) ; do
    DB_NAME=$(echo ${i}  | awk -F[\/\.] '{print $3}')
	DB_NAME="${DB_NAME}_${storage_engine}"
    sysbench /usr/share/sysbench/oltp_read_write.lua --table-size=10000 --tables=16 --mysql-db=${DB_NAME} --mysql-user=root  --mysql-storage-engine=$storage_engine --threads=16 --time=3600 --events=1870000000 --db-driver=mysql --db-ps-mode=disable --mysql-socket=${i} run  > $WORKDIR/logs/sysbench_run_${DB_NAME}.txt 2>&1 &
    check_script $? "Failed to run sysbench oltp"
  done
}

check_dbdeployer(){
  if ! dbdeployer --version | grep 'dbdeployer version 1.' > /dev/null ; then
      echo "ERROR! dbdeployer not installed attempting to install"
      install_dbdeployer
  fi
  dbdeployer delete all --skip-confirm
}

install_dbdeployer(){
  wget https://github.com/datacharmer/dbdeployer/releases/download/v1.28.1/dbdeployer-1.28.1.linux.tar.gz
  tar -xzf dbdeployer-1.28.1.linux.tar.gz
  chmod +x dbdeployer-1.28.1.linux
  sudo mv dbdeployer-1.28.1.linux /usr/local/bin/dbdeployer
}

if [ ! -z $wipe_clients ]; then
  clean_clients
fi

if [ ! -z $wipe_pmm2_clients ]; then
  wipe_pmm2_clients
fi

if [ ! -z $delete_package ]; then
  remove_packages
fi

if [ ! -z $wipe_docker_clients ]; then
  clean_docker_clients
fi

if [ ! -z $wipe_server ]; then
  clean_server
fi

if [ ! -z $wipe ]; then
  clean_clients
  clean_docker_clients
  clean_server
fi

if [ ! -z $list ]; then
  sudo pmm-admin list
fi

if [ ! -z $setup ]; then
  setup
fi

#if [ ! -z $PMM2 ]; then
#  configure_client;
#fi

if [ ! -z $upgrade_server ]; then
  upgrade_server
fi

if [ ! -z $upgrade_client ]; then
  upgrade_client
fi

if [ ${#ADDCLIENT[@]} -ne 0 ]; then
  if [[ "$pmm_server" == "custom" ]];then
    if ! sudo pmm-admin ping | grep -q "OK, PMM server is alive"; then
      echo "ERROR! PMM Server is not running. Please check PMM server status. Terminating"
      exit 1
    fi
  else
    sanity_check
  fi
  add_clients
fi

if [ ! -z $with_proxysql ]; then
  if [ ! -z $PMM2 ]; then
    pxc_proxysql_setup_pmm2
  else
    pxc_proxysql_setup
  fi
fi

if [ ! -z $sysbench_data_load ]; then
  sysbench_prepare
fi

if [ ! -z $sysbench_oltp_run ]; then
  sysbench_run
fi

if [ ! -z $mongo_sysbench ]; then
  mongo_sysbench
fi
if [ ! -z $add_docker_client ]; then
  sanity_check
  pmm_docker_client_startup
fi

exit 0
