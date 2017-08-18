#!/bin/sh

# Ensure that URLs with the specified host must use HTTPS without a username and/or password.
host=$1

cd $(dirname $0)/..  # `git diff` and `xargs` need to in the correct directory
if git diff --name-only origin/HEAD HEAD -- "*/url" | xargs grep $host | grep -qv https://$host; then
    echo "Registered package URLs to $host must use HTTPS"
    exit 1
else
    exit 0
fi
