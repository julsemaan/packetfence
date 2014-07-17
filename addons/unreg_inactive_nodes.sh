#!/bin/sh

if [ -z "$1" ]; then
    echo "No timeout date supplied. Exiting."
    exit 1
else
    timeout_date=$1
fi

if [ -z "$2" ]; then
    echo "No category supplied. Exiting."
    exit 1
else
    category=$1
fi

query="UPDATE node SET status='unreg' WHERE mac IN (select Node.mac from (select * from node) as Node join (select mac, MAX(start_time) as start_time from iplog GROUP BY mac) as Last_ip_log on Node.mac=Last_ip_log.mac JOIN (select * from node_category) as Category ON Node.category_id=Category.category_id WHERE Last_ip_log.start_time < DATE('$timeout_date') AND Last_ip_log.start_time != DATE('0000-00-00') AND status='reg' AND Category.name='$2');"

echo "Executing"
echo "$query"

mysql -u pf -p$(cat /root/pf_passwd) pf_42 -e "$query"
