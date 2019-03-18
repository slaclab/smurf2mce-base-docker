# Docker image with smurf2mce for the SMuRF project

## Description

This docker image, named **smurf2mce-base** contains smurf2mce and additional tools used by the SMuRF project.

It is based on the **smurf-rogue** docker image and contains smurf2mce.

The purpose of this image is to be use to test new firmware images. Once the firmware is stable, an stable docker image based on this one and including the stable firmware files is generated and named **smurf2mce**. The code to generate that stable docker image is kept in a independent github repository https://github.com/slaclab/smurf2mce-docker.

## Source code

Rogue source code is checked out for the SLAC's github repository https://github.com/slaclab/smurf2mce.

## Building the image

When a tag is pushed to this github repository, a new Docker image is automatically built and push to its [Dockerhub repository](https://hub.docker.com/r/tidair/smurf2mce-base) using travis.

The resulting docker image is tagged with the same git tag string (as returned by `git describe --tags --always`).

## How to get the container

To get the docker image, first you will need to install the docker engine in you host OS. Then you can pull a copy by running:

```
docker pull tidair/smurf2mce-base:<TAG>
```

Where **<TAG>** represents the specific tagged version you want to use.


## Running the container


This image contains a startup script called `start_server.sh` which can be called to start the smurf2mce server. It accepts the following parameters:

```
usage: start_server.sh [-S|--shelfmanager <shelfmanager_name> -N|--slot <slot_number>]
                       [-a|--addr <FPGA_IP>] [-D|--no-check-fw] [-g|--gui] <pyrogue_server-args>

    -S|--shelfmanager <shelfmanager_name> : ATCA shelfmanager node name or IP address. Must be used with -N.
    -N|--slot         <slot_number>       : ATCA crate slot number. Must be used with -S.
    -a|--addr         <FPGA_IP>           : FPGA IP address. If defined, -S and -N are ignored.
    -D|--no-check-fw                      : Disabled FPGA version checking.
    -g|--gui                              : Start the server with a GUI.
    -h|--help                             : Show this message.
    <pyrogue_server_args> are passed to the SMuRF pyrogue server.
```

You can address the target FPGA either using the card's ATCA shelfmanager'name and slot number, ob by directly giving its IP address. If you use the shelfmanager name and slot number, the script will automatically detect the FPGA's IP address by reading the crate's ID and using the slot number, following the SLAC's convention: `IP address = 10.<crate's ID higher byte>.<crate's ID lower byte>.<100 + slot number>`.

The script looks a pyrogue taraball to be present in `/tmp/fw/`. The tarball must has a extension `pyrogue.tar.gz` or `python.tar.gz`. If found, the server will be start using it. So, when starting the server you must have a local copy of this pyrogue tarball in the host CPU, and mount that directory inside the container as `/tmp/fw/`.

On the other hand, the scripts also looks for a MCS file in `/tmp/fw/`. The file name must include the short githash version of the firmware and an extension `mcs` or `mcs.gz`, following this expression: `*-<short-githash>.mcs[.gz]`. The script will also read the firmware short githash from the specified FPGA. If the version from the MCS file and the FPGA don't match, then the script will automatically load the MCS file into the FPGA. So, when starting the server you must have a local copy of this mcs file in the host CPU, and mount that directory inside the container as `/tmp/fw/`. All this automatic version checking can be disabled ither by passing the argument `-D|--no-check-fw`, or by addressing the FPGA by IP address instead of ATCA's shelfmanager_name/slot_number.

The server by default start without a GUI. You can however start the server with a GUI using the argument `-g|--gui`.

The smurf2mce server needs a location to write data, as well as to read its configuration files. Those locations inside the container are `/data/smurf_data` and `/data/smurf2mce_config`. So, you need to have those directories in the host CPU and mount then inside the container.

Finally, additional arguments added to the script will be passed verbatim to the smurf2mce server. With this argument you can, for example, set the EPICS PV name's prefix, select the type of communication, etc.

With all that in mind, the command to run the container looks something like this:

```
docker run -ti --rm \
    -v <local_data_dir>:/data \
    -v <local_fw_files_dir>:/tmp/fw/ \
    tidair/smurf2mce-base:<TAG> \
    start_server.sh <server_arguments>
```

Where:
- **<local_data_dir>**: is a local directory in the host CPU which contains the directories `smurf_data` where the data is going to be written to, and `smurf2mce_config` with the smuirf2mce configuration files,
- **<local_fw_files_dir>**: is a local directory in the host CPU with the firmware's MCS and pyrogue tarball files,
- **<TAG>**: is the tagged version of the container your want to run,
- **<server_arguments>**: are the arguments passed to start_server.sh.


## Using the container as a base image

The image is intended to be the base image for the **smurf2mce** docker images. In order to do so, start the new docker image Dockerfile with this line:

```
ROM tidair/smurf2mce-base:<TAG>
```

Where:
- **<TAG>**: is the tagged version of the container your want to run.