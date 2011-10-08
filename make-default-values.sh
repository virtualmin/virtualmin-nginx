#!/bin/sh
wget -O - -q http://nginx.org/en/docs/http/ngx_http_core_module.html | grep -A 1 "<strong>default</strong>" | grep -v "<strong>default</strong>" | grep "<code>" | sed -e 's/<code>//' | sed -e 's/<.code>.*//' | sed -e 's/^ *//'
