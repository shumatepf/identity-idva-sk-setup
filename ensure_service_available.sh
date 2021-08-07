#!/bin/bash

usage() {
    cat << EOF
Usage
        $0 [-c] SERVICE PLAN SERVICE_INSTANCE_NAME

Description
        This script checks for the existance of the specified service and optionally creates it if it does not exist.

        NOTE - this script will only create services if they do not exist.
        It will NOT update services to match the provided plan type.

Options
        -c
            Check for service only. Do NOT create service if it does not exist.

Examples
        ensure_service_available aws-rds micro-psql my-app-db
EOF
}

should_create=true

while getopts "c" option; do
    case ${option} in
        c )
            should_create=false
            ;;
        * )
            usage
            exit 1
            ;;
    esac
done

shift $((OPTIND-1))

if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ] || [ -n "$4" ]; then
    usage
    exit 1
fi

cf_service="$1"
cf_service_plan="$2"
cf_service_name="$3"

success_status_regex="(create|update) succeeded"

# Waits for the cf service status to become create/update succeeded
wait_for_service_creation() {
    time_limit=600 # 10 minutes

    while [ $time_limit -ne 0 ] && [[ ! "$service_status" =~ $success_status_regex ]]; do
        echo "Waiting for service to become available. Seconds before timeout: $time_limit"
        sleep 30
        time_limit=$((time_limit - 30))
        service_status="$(cf service "$cf_service_name" | grep "status:")"
    done

    # Check for timeout
    if [[ ! "$service_status" =~ $success_status_regex ]]; then
        echo "Service failed to become ready within the time limit."
        exit 1
    fi

    echo "Service creation finalized"
}

create_service() {
    # Documentation: https://cli.cloudfoundry.org/en-US/v7/create-service.html
    cf create-service "$cf_service" "$cf_service_plan" "$cf_service_name"
}

# Test if cf service exists at all
if ! cf services | grep --silent "^$cf_service_name "; then
    echo "Unable to find service: $cf_service_name." 
    if [ "$should_create" = false ] ; then
        exit 1
    fi
    echo "Creating..."
    create_service
    wait_for_service_creation
    exit 0
fi

# The service existed, but the service status is not yet known
echo "Found service $cf_service_name. Checking service status..."

cf_service_status="$(cf service "$cf_service_name" | grep "status:")"

if [[ "$cf_service_status" =~ $success_status_regex ]]; then
    echo "Service $cf_service_name already available"
elif [[ "$cf_service_status" == *"in progress"* ]]; then
    echo "$cf_service_name creation was 'in progress'."
    wait_for_service_creation
else
    # Status was neither "in progress" nor "create|update succeeded". There's likely
    # a problem with the service that can't be resolved without human interaction
    echo "Found cf service: $cf_service_name but status was: $cf_service_status"
    exit 1
fi
