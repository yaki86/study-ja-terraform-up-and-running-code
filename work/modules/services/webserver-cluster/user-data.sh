#!/bin/bash
cat > index.html <<EOF
<h1>${server_text}</h1>
<p>This is a web server instance launched by Terraform.</p>
<p>Database Endpoint: ${db_address}</p>
<p>Database Port: ${db_port}</p>
EOF

nohup busybox httpd -f -p ${server_port} &