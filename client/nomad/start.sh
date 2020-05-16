#!/usr/local/bin/dumb-init /bin/sh
# Script created following Hashicorp's model for Consul: 
# https://github.com/hashicorp/docker-consul/blob/master/0.X/docker-entrypoint.sh
# Comments in this file originate from the project above, simply replacing 'Consul' with 'Nomad'.
set -e

# Note above that we run dumb-init as PID 1 in order to reap zombie processes
# as well as forward signals to all processes in its session. Normally, sh
# wouldn't do either of these functions so we'd leak zombies as well as do
# unclean termination of all our sub-processes.

# NOMAD_DATA_DIR is exposed as a volume for possible persistent storage. The
# NOMAD_CONFIG_DIR isn't exposed as a volume but you can compose additional
# config files in there if you use this image as a base, or use NOMAD_LOCAL_CONFIG
# below.
NOMAD_DATA_DIR=${NOMAD_DATA_DIR:-"/nomad/data"}
NOMAD_CONFIG_DIR=${NOMAD_CONFIG_DIR:-"/etc/nomad"}

echo $NOMAD_LOCAL_CONFIG
# You can also set the NOMAD_LOCAL_CONFIG environemnt variable to pass some
# Nomad configuration JSON without having to bind any volumes.
if [ -n "$NOMAD_LOCAL_CONFIG" ]; then
	echo "$NOMAD_LOCAL_CONFIG" > "$NOMAD_CONFIG_DIR/local.json"
fi

# If NOMAD_RUN_ROOT is selected, then run as root. This will be necessary to
# run pretty much any job on the host, so it needs to be set for client and
# development mode.
if [ -n "${NOMAD_RUN_ROOT}" ]; then
  echo "==> NOMAD_RUN_ROOT specified, running Nomad as root."
  NOMAD_RUN_USER="root"
else
  echo "==> Running Nomad as unprivileged \"nomad\" user"
  echo "==> Set NOMAD_RUN_ROOT if job execution is required"
  NOMAD_RUN_USER="nomad"
fi

# If the user is trying to run Nomad directly with some arguments, then
# pass them to Nomad.
if [ "${1:0:1}" = '-' ]; then
    set -- nomad "$@"
fi

# Look for Nomad subcommands.
if [ "$1" = 'agent' ]; then
    shift
    set -- nomad agent \
        -data-dir="$NOMAD_DATA_DIR" \
        -config="$NOMAD_CONFIG_DIR" \
        "$@"
elif [ "$1" = 'version' ]; then
    # This needs a special case because there's no help output.
    set -- nomad "$@"
elif nomad --help "$1" 2>&1 | grep -q "nomad $1"; then
    # We can't use the return code to check for the existence of a subcommand, so
    # we have to use grep to look for a pattern in the help output.
    set -- nomad "$@"
fi

# Look for Nomad subcommands.
if [ "$1" = 'agent' ]; then
    shift
    set -- nomad agent \
        -data-dir="$NOMAD_DATA_DIR" \
        -config="$NOMAD_CONFIG_DIR" \
        $NOMAD_BIND \
        $NOMAD_CLIENT \
        "$@"
elif [ "$1" = 'version' ]; then
    # This needs a special case because there's no help output.
    set -- nomad "$@"
elif nomad --help "$1" 2>&1 | grep -q "nomad $1"; then
    # We can't use the return code to check for the existence of a subcommand, so
    # we have to use grep to look for a pattern in the help output.
    set -- nomad "$@"
fi

# If we are running Nomad, make sure it executes as the proper user.
if [ "$1" = 'nomad' ]; then
    # If the data or config dirs are bind mounted then chown them.
    # Note: This checks for root ownership as that's the most common case.
    if [ "$(stat -c %u "${NOMAD_DATA_DIR}")" != "$(id -u ${NOMAD_RUN_USER})" ]; then
        chown "${NOMAD_RUN_USER}":nomad "${NOMAD_DATA_DIR}"
    fi
    if [ "$(stat -c %u "${NOMAD_CONFIG_DIR}")" != "$(id -u ${NOMAD_RUN_USER})" ]; then
        chown "${NOMAD_RUN_USER}":nomad "${NOMAD_CONFIG_DIR}"
    fi

    set -- gosu "${NOMAD_RUN_USER}":nomad "$@"
fi

exec "$@"
