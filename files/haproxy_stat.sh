#!/bin/bash

### https://superuser.com/questions/1193917/how-to-view-haproxy-status-on-the-command-line-using-a-socket

echo "show stat" \
    | nc -U /var/lib/haproxy/stats \
    | cut -d "," -f 1,2,5-11,18,24,27,30,36,50,37,56,57,62 \
    | column -s, -t 
#\
#    | grep 'BACKEND'

# If you want to know what the column numbers are for this cut command will help.
# echo "show stat" | nc -U /var/lib/haproxy/stats | grep "#" | tr ',' '\n' | nl

