#!/bin/sh
CUR_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
echo "CUR_DIR : $CUR_DIR"

echo "check env var"
if [ ${GAUSSHOME} ] && [ -d ${GAUSSHOME}/bin ];then
    echo "GAUSSHOME: ${GAUSSHOME}"
else
    echo "GAUSSHOME NOT EXIST"
    exit 1;
fi

SUPER_PASSWORD=Gauss_234

clean_database_env()
{
    SS_DATA=$1
    if [ -d ${SS_DATA} ]; then
        echo "${SS_DATA} exists, so need to clean and recreate"
        rm -rf ${SS_DATA}
    else
        echo "${SS_DATA} not exists, so need to recreate"
    fi
    mkdir ${SS_DATA}
}

clear_shm()
{
    ipcs -m | grep $USER | awk '{print $2}' | while read shm; do
        if [ -n ${shm} ]; then
            ipcrm -m ${shm}
        fi
    done
    ipcs -s | grep $USER | awk '{print $2}' | while read shm; do
        if [ -n ${shm} ]; then
            ipcrm -s ${shm}
        fi
    done
}

kill_gaussdb()
{
    ps ux | grep gaussdb | grep -v grep | awk '{print $2}' | xargs kill -9 > /dev/null 2>&1
    ps ux | grep gsql | grep -v grep | awk '{print $2}' | xargs kill -9 > /dev/null 2>&1
    ps ux | grep dssserver | grep -v grep | awk '{print $2}' | xargs kill -9 > /dev/null 2>&1
    clear_shm
    sleep 2
}

kill_dss()
{
    ps ux | grep dssserver | grep -v grep | awk '{print $2}' | xargs kill -9 > /dev/null 2>&1
}

assign_hatest_parameter()
{
    for node in $@
    do
        echo -e "\nss_enable_reform = on" >> ${node}/postgresql.conf
        echo -e "\nlog_min_messages = log" >> ${node}/postgresql.conf
        echo -e "\nlogging_module = 'on(ALL)'" >> ${node}/postgresql.conf
        echo "${node}:"
        cat ${node}/postgresql.conf | grep ss_enable_dms
    done
}

init_gaussdb()
{
    inst_id=$1
    dss_home=$2
    SS_DATA=$3
    nodedata_cfg=$4
    echo "${GAUSSHOME}/bin/gs_initdb -D ${SS_DATA}/dn${inst_id} --nodename=single_node -w ${SUPER_PASSWORD} --vgname=\"+data,+log${inst_id}\" --enable-dss --dms_url=\"${nodedata_cfg}\" -I ${inst_id} --socketpath=\"UDS:${dss_home}/.dss_unix_d_socket\""

    ${GAUSSHOME}/bin/gs_initdb -D ${SS_DATA}/dn${inst_id} --nodename=single_node -w ${SUPER_PASSWORD} --vgname="+data,+log${inst_id}" --enable-dss --dms_url="${nodedata_cfg}" -I ${inst_id} --socketpath="UDS:${dss_home}/.dss_unix_d_socket"
}

set_gaussdb_port()
{
    data_node=$1
    pg_port=$2
    echo "" >> ${data_node}/postgresql.conf
    echo "port = ${pg_port}" >> ${data_node}/postgresql.conf
}

start_gaussdb()
{
    data_node=$1
    echo "> starting ${data_node}" && nohup ${GAUSSHOME}/bin/gaussdb -D ${data_node} &
    sleep 10
}

stop_gaussdb()
{
    data_node=$1
    echo "> stop ${data_node}" && ${GAUSSHOME}/bin/gs_ctl stop -D ${data_node}
    sleep 5
}