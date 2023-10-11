%{ for key, value in environments ~}
[${key}]
${value.subdomain}.${domain}

[${key}:vars]
ansible_ssh_common_args='-o UserKnownHostsFile=${key}.known_hosts -o ServerAliveInterval=60 -o ServerAliveCountMax=5'
ansible_ssh_private_key_file=${abspath(value.instance_key_pvt)}
deploy_key_pvt=${abspath(value.deploy_key_pvt)}
override=${value.override}
traefik_basicauth=${value.traefik_basicauth}
acme_email=${value.acme_email}
postgres_password_superuser=${value.postgres_password_superuser}
postgres_password_app=${value.postgres_password_app}
postgres_password_app_admin=${value.postgres_password_app_admin}
postgres_user_app_power=${value.postgres_user_app_power}
azure_tenant_id=${value.azure_tenant_id}
azure_client_id=${value.azure_client_id}

%{ endfor ~}
