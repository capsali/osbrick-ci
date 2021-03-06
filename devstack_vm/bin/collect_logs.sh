#!/bin/bash

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
. $DIR/config.sh

TAR=$(which tar)
GZIP=$(which gzip)

function emit_error() {
    echo "ERROR: $1"
    exit 1
}

function emit_warning() {
    echo "WARNING: $1"
    return 0
}

function archive_devstack_logs() {
    if [ ! -d "$LOG_DST_DEVSTACK" ]
    then
        mkdir -p "$LOG_DST_DEVSTACK" || emit_error "L30: Failed to create $LOG_DST_DEVSTACK"
    fi

    for i in `ls -A $DEVSTACK_LOGS`
    do
        if [ -h "$DEVSTACK_LOGS/$i" ]
        then
                REAL=$(readlink "$DEVSTACK_LOGS/$i")
                $GZIP -c "$REAL" > "$LOG_DST_DEVSTACK/$i.gz" || emit_warning "L38: Failed to archive devstack logs"
        fi
    done
    $GZIP -c /var/log/mysql/error.log > "$LOG_DST_DEVSTACK/mysql_error.log.gz"
    $GZIP -c /var/log/cloud-init.log > "$LOG_DST_DEVSTACK/cloud-init.log.gz"
    $GZIP -c /var/log/cloud-init-output.log > "$LOG_DST_DEVSTACK/cloud-init-output.log.gz"
    $GZIP -c /var/log/dmesg > "$LOG_DST_DEVSTACK/dmesg.log.gz"
    $GZIP -c /var/log/kern.log > "$LOG_DST_DEVSTACK/kern.log.gz"
    $GZIP -c /var/log/syslog > "$LOG_DST_DEVSTACK/syslog.log.gz"
    for stack_log in `ls -A $DEVSTACK_LOG_DIR | grep "stack.sh[.0-5]*.txt" | grep -v "gz"`
    do
        $GZIP -c "$DEVSTACK_LOG_DIR/$stack_log" > "$LOG_DST_DEVSTACK/$stack_log.gz"
    done

    mkdir -p "$LOG_DST_DEVSTACK/rabbitmq"
    cp /var/log/rabbitmq/* "$LOG_DST_DEVSTACK/rabbitmq"
    sudo rabbitmqctl status > "$LOG_DST_DEVSTACK/rabbitmq/status.txt" 2>&1
    $GZIP $LOG_DST_DEVSTACK/rabbitmq/*
    mkdir -p "$LOG_DST_DEVSTACK/openvswitch"
    cp /var/log/openvswitch/* "$LOG_DST_DEVSTACK/openvswitch"
    $GZIP $LOG_DST_DEVSTACK/openvswitch/*
}

function archive_devstack_configs() {

    if [ ! -d "$CONFIG_DST_DEVSTACK" ]
    then
        mkdir -p "$CONFIG_DST_DEVSTACK" || emit_warning "L38: Failed to archive devstack configs"
    fi
    
    for i in cinder glance keystone neutron nova openvswitch
    do
        cp -r -L "/etc/$i" "$CONFIG_DST_DEVSTACK/$i"
    done
    for file in `find "$CONFIG_DST_DEVSTACK/$i" -type f`
    do 
        $GZIP $file
    done
    
    $GZIP -c /home/ubuntu/devstack/local.conf > "$CONFIG_DST_DEVSTACK/local.conf.gz"
    $GZIP -c /opt/stack/tempest/etc/tempest.conf > "$CONFIG_DST_DEVSTACK/tempest.conf.gz"
    df -h > "$CONFIG_DST_DEVSTACK/df.txt" 2>&1 && $GZIP "$CONFIG_DST_DEVSTACK/df.txt"
    cp /home/ubuntu/bin/excluded-tests.txt "$CONFIG_DST_DEVSTACK/excluded-tests.txt"
    cp /home/ubuntu/bin/isolated-tests.txt "$CONFIG_DST_DEVSTACK/isolated-tests.txt"
    iptables-save > "$CONFIG_DST_DEVSTACK/iptables.txt" 2>&1 && $GZIP "$CONFIG_DST_DEVSTACK/iptables.txt"
    dpkg-query -l > "$CONFIG_DST_DEVSTACK/dpkg-l.txt" 2>&1 && $GZIP "$CONFIG_DST_DEVSTACK/dpkg-l.txt"
    pip freeze > "$CONFIG_DST_DEVSTACK/pip-freeze.txt" 2>&1 && $GZIP "$CONFIG_DST_DEVSTACK/pip-freeze.txt"
    ps axwu > "$CONFIG_DST_DEVSTACK/pidstat.txt" 2>&1 && $GZIP "$CONFIG_DST_DEVSTACK/pidstat.txt"
    ifconfig -a -v > "$CONFIG_DST_DEVSTACK/ifconfig.txt" 2>&1 && $GZIP "$CONFIG_DST_DEVSTACK/ifconfig.txt"
    sudo ovs-vsctl -v show > "$CONFIG_DST_DEVSTACK/ovs_bridges.txt" 2>&1 && $GZIP "$CONFIG_DST_DEVSTACK/ovs_bridges.txt"
}

function archive_hyperv_configs() {
    if [ ! -d "$CONFIG_DST_HV" ]
    then
        mkdir -p "$CONFIG_DST_HV"
    fi
    # COUNT=1
    cp -r -L "$HYPERV_CONFIGS" "$CONFIG_DST_HV"
    for file in `find "$CONFIG_DST_HV" -type f`
    do 
        $GZIP $file
    done
}

function archive_hyperv_logs() {
    if [ ! -d "$LOG_DST_HV" ]
    then
        mkdir -p "$LOG_DST_HV"
    fi
    cp -r -L $HYPERV_LOGS/* $LOG_DST_HV
    for file in `find "$LOG_DST_HV" -type f`
    do
        $GZIP $file
    done
}


function archive_tempest_files() {
    for i in `ls $TEMPEST_LOGS`
    do
        $GZIP "$TEMPEST_LOGS/$i" -c > "$LOG_DST/$i.gz" || emit_warning "L133: Failed to archive tempest logs"
    done
}

# Clean
[ -d "$LOG_DST" ] && rm -rf "$LOG_DST"
mkdir -p "$LOG_DST"

archive_devstack_logs
archive_devstack_configs
archive_hyperv_configs
archive_hyperv_logs
archive_tempest_files

pushd "$LOG_DST"
$TAR -czf "$LOG_DST.tar.gz" . || emit_error "L147: Failed to archive aggregate logs"
popd

exit 0
