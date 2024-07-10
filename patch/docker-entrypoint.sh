#!/bin/sh
# Usage: docker-entrypoint.sh [cmd [arg0 [arg1 ...]]]

echo ">>>>> Entering Ubuntu 24.04 development container..."

# Exit on failure
set -e

# Pull Docker ENV variables, using defaults if not set
user="${LINUX_USER:-"user"}"
uid="${LINUX_UID:-"1000"}"
group="${LINUX_GROUP:-"user"}"
gid="${LINUX_GID:-"1000"}"
dir="${LINUX_DIR:-"/home/$user"}"

echo "Setting up container for user:$user($uid) group:$group($gid)..."

# Make new user and group if it doesn't exist already
if [ "$uid" = 1000 ]; then
  UNAME=$(getent passwd "$uid" | cut -d: -f1)
  userdel "$UNAME"
  groupadd -f -g "$gid" "$group"
  useradd -u "$uid" -g "$gid" -m "$user"
else
  groupadd -f -g "$gid" "$group"
  useradd -u "$uid" -g "$gid" -m "$user"
fi

# Start here
cd "$dir"

# Run cmd as new user
gosu "$user" "$@"

echo "<<<<< Leaving Ubuntu 24.04 development container..."
