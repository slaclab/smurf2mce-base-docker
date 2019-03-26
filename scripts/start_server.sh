#!/usr/bin/env bash

###############
# Definitions #
###############
# Shell PID
top_pid=$$

# This script name
script_name=$(basename $0)

# Firmware file location
fw_top_dir="/tmp/fw"

########################
# Function definitions #
########################

# Trap TERM signals and exit
trap "echo 'An ERROR was found. Aborting...'; exit 1" TERM

# Usage message
usage()
{
    echo "Start the SMuRF server on a specific board."
    echo ""
    echo "usage: ${script_name} [-S|--shelfmanager <shelfmanager_name> -N|--slot <slot_number>]"
    echo "                      [-a|--addr <FPGA_IP>] [-D|--no-check-fw] [-g|--gui] <pyrogue_server-args>"
    echo "    -S|--shelfmanager <shelfmanager_name> : ATCA shelfmanager node name or IP address. Must be used with -N."
    echo "    -N|--slot         <slot_number>       : ATCA crate slot number. Must be used with -S."
    echo "    -a|--addr         <FPGA_IP>           : FPGA IP address. If defined, -S and -N are ignored."
    echo "    -D|--no-check-fw                      : Disabled FPGA version checking."
    echo "    -g|--gui                              : Start the server with a GUI."
    echo "    -h|--help                             : Show this message."
    echo "    <pyrogue_server_args> are passed to the SMuRF pyrogue server. "
    echo ""
    echo "If -a if not defined, then -S and -N must both be defined, and the FPGA IP address will be automatically calculated from the crate ID and slot number."
    echo "If -a if defined, -S and -N are ignored."
    echo
    echo "The script will bu default check if the firmware githash read from the FPGA via IPMI is the same of the found in the MCS file name."
    echo "This checking can be disabled with -D. The checking will also be disabled if -a is used instead of -S and -N."
    echo
    echo "By default, the SMuRF server is tarted without a GUI (server mode). Use -g to start the server with a GUI. -s|--server option is ignored as that is the default."
    echo
    echo "All other arguments are passed verbatim to the SMuRF server."
    echo ""
    exit 1
}

getGitHashFW()
{
    local gh_inv
    local gh

    # Long githash (inverted)
    #gh_inv=$(ipmitool -I lan -H $SHELFMANAGER -t $IPMB -b 0 -A NONE raw 0x34 0x04 0xd0 0x14  2> /dev/null)
    # Short githash (inverted)
    gh_inv=$(ipmitool -I lan -H $shelfmanager -t $ipmb -b 0 -A NONE raw 0x34 0x04 0xe0 0x04  2> /dev/null)

    if [ "$?" -ne 0 ]; then
        kill -s TERM ${top_pid}
    fi

    # Invert the string
    for c in ${gh_inv} ; do gh=${c}${gh} ; done

    # Return the short hash (7 bytes)
    echo ${gh} | cut -c 1-7
}

getGitHashMcs()
{
    local filename=$(basename $mcs_file_name)
    local gh=$(echo $filename | sed  -r 's/.+-+(.+).mcs.*/\1/')

    # Return the short hash (7 bytes)
    echo ${gh} | cut -c 1-7
}

getCrateId()
{
    local crate_id_str

    crate_id_str=$(ipmitool -I lan -H $shelfmanager -t $ipmb -b 0 -A NONE raw 0x34 0x04 0xFD 0x02 2> /dev/null)

    if [ "$?" -ne 0 ]; then
        kill -s TERM ${top_pid}
    fi

    local crate_id=`printf %04X  $((0x$(echo $crate_id_str | awk '{ print $2$1 }')))`

    if [ -z ${crate_id} ]; then
        kill -s TERM ${top_pid}
    fi

    echo ${crate_id}
}

getFpgaIp()
{

    # Calculate FPGA IP subnet from the crate ID
    local subnet="10.$((0x${crate_id:0:2})).$((0x${crate_id:2:2}))"

    # Calculate FPGA IP last octect from the slot number
    local fpga_ip="${subnet}.$(expr 100 + $slot)"

    echo ${fpga_ip}
}

#############
# Main body #
#############

# Verify inputs arguments
while [[ $# -gt 0 ]]
do
key="$1"

case ${key} in
    -S|--shelfmanager)
    shelfmanager="$2"
    shift
    ;;
    -N|--slot)
    slot="$2"
    shift
    ;;
    -D|--no-check-fw)
    no_check_fw=1
    ;;
    -a|--addr)
    fpga_ip="$2"
    shift
    ;;
    -g|--gui)
    use_gui=1
    ;;
    -s|--server)
    ;;
    -h|--help)
    usage
    ;;
    *)
    args="${args} $key"
    ;;
esac
shift
done

echo

# Verify mandatory parameters

# Check IP address or shelfmanager/slot number
if [ -z ${fpga_ip+x} ]; then
    # If the IP address is not defined, shelfmanager and slot numebr must be defined

    if [ -z ${shelfmanager+x} ]; then
        echo "Shelfmanager not defined!"
        usage
    fi

    if [ -z ${slot+x} ]; then
        echo "Slot number not defined!"
        usage
    fi

    echo "IP address was not defined. It will be calculated automatically from the crate ID and slot number..."

    ipmb=$(expr 0128 + 2 \* $slot)

    echo "Reading Crate ID via IPMI..."
    crate_id=$(getCrateId)
    echo "Create ID: ${crate_id}"

    echo "Calculating FPGA IP address..."
    fpga_ip=$(getFpgaIp)
    echo "FPGA IP: ${fpga_ip}"

else
    echo "IP address was defined. Ignoring shelfmanager and slot number. FW version checking disabled."
    no_check_fw=1
fi

# Add the IP address to the SMuRF arguments
args="${args} -a ${fpga_ip}"

# Extract the pyrogue tarball and update PYTHONPATH
echo "Looking for pyrogue tarball..."
pyrogue_file=$(find ${fw_top_dir} -maxdepth 1 -name *pyrogue.tar.gz)
if [ ! -f "$pyrogue_file" ]; then
    pyrogue_file=$(find ${fw_top_dir} -maxdepth 1 -name *python.tar.gz)
    if [ ! -f "$pyrogue_file" ]; then
        echo "Pyrogue tarball file not found!"
        exit 1
    fi
fi
echo "Pyrogue file found: ${pyrogue_file}"

echo "Extracting the pyrogue tarball into ${fw_top_dir}/pyrogue..."
rm -rf ${fw_top_dir}/pyrogue
mkdir ${fw_top_dir}/pyrogue
tar -zxf ${pyrogue_file} -C ${fw_top_dir}/pyrogue
proj=$(ls ${fw_top_dir}/pyrogue)
export PYTHONPATH=${fw_top_dir}/pyrogue/${proj}/python:${PYTHONPATH}
echo "Done. Pyrogue extracted to ${fw_top_dir}/pyrogue/${proj}."

# Firmware version checking
if [ -z ${no_check_fw+x} ]; then

    mcs_file=$(find ${fw_top_dir} -maxdepth 1 -name *mcs*)
    if [ ! -f "${mcs_file}" ]; then
        echo "MCS file not found!"
        exit 1
    fi

    mcs_file_name=$(basename ${mcs_file})
    echo ${mcs_file_name}

    echo "Reading FW Git Hash via IPMI..."
    fw_gh=$(getGitHashFW)
    echo "Firmware githash: '$fw_gh'"

    echo "Reading MCS file Git Hash..."
    mcs_gh=$(getGitHashMcs)
    echo "MCS file githash: '$mcs_gh'"

    if [ "${fw_gh}" == "${mcs_gh}" ]; then
        echo "They match..."
    else
        echo "They don't match. Loading image..."
        ProgramFPGA.bash -s $shelfmanager -n $slot -m $mcs_file
    fi

else
    echo "Check firmware disabled."
fi

# Check if the server GUI was requested
if [ -z ${use_gui+x} ]; then
    args="${args} -s"
else
    echo "Server GUI enabled."
fi

# MCE library location
MCE_LIB_PATH=/usr/local/src/smurf2mce/mcetransmit/lib/
export PYTHONPATH=$MCE_LIB_PATH:${PYTHONPATH}

echo "Starting server..."
cd /data/smurf2mce_config/
#/usr/local/src/smurf2mce/mcetransmit/scripts/control-server/start_server.sh -a ${fpga_ip} -c eth-rssi-interleaved -t ${pyrogue_file} -d ${fw_top_dir}/config/default.yaml  -f Int16 -b 524288 ${args}
# /usr/local/src/smurf2mce/mcetransmit/scripts/control-server/python/pyrogue_server.py -a ${fpga_ip} -c eth-rssi-interleaved -d ${fw_top_dir}/defaults.yml  -f Int16 -b 524288 ${args}
/usr/local/src/smurf2mce/mcetransmit/scripts/control-server/python/pyrogue_server.py  ${args}
