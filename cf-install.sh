#
# cf Installer
# 
# Copyright (c) 1984-2024 Jose Garcia
# Released under the MIT license
# https://raw.githubusercontent.com/coronadofactory/hexagonal/refs/heads/main/LICENSE.txt
#
# Date: 2024-10-03
#

echo "cf installer"
curl -s https://raw.githubusercontent.com/coronadofactory/devops/refs/heads/main/cf-launch.sh -o /usr/local/bin/cf
chmod 750 /usr/local/bin/cf