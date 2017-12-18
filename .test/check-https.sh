#!/bin/sh

# Ensure that URLs with the specified host must use HTTPS without a username and/or password.
host=$1

cd $(dirname $0)/..  # `git diff` needs run to in the correct directory

# Look only at URL additions which contain the hostname
urls=($(git diff origin/invenia HEAD -G $host -- "*/url" | grep -E '^\+' | grep $host | sed -e 's/^\+//'))

for url in "${urls[@]}"; do
    if echo $url | grep -qv https://$host; then
        echo "Registered package URLs to \"$host\" must use HTTPS. Invalid URL: \"$url\""
        exit 1
    fi

    if echo $url | grep -qvE '\.git$'; then
        echo "Registered package URLs using HTTP must end with \".git\". Invalid URL: \"$url\""
        exit 1
    fi
done

exit 0
