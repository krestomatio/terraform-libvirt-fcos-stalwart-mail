locals {
  data_volume_path     = "/var/opt/stalwart-mail"
  systemd_stop_timeout = 30
  stalwart_mail_image  = "${var.image.name}:${var.image.version}"
  ssl_path             = "/etc/certs/${var.external_fqdn}"
  post_hook = {
    path    = "/usr/local/bin/stalwart-mail-certbot-renew-hook"
    content = <<-TEMPLATE
      #!/bin/bash

      # vars
      container_name=stalwart-mail
      cert_folder_path="${local.data_volume_path}/${local.ssl_path}"
      cert_path="$$${cert_folder_path}/fullchain.pem"
      key_path="$$${cert_folder_path}/privkey.pem"
      proxy_uid="0"
      proxy_gid="0"
      source_cert_folder_path="/etc/letsencrypt/live/${var.external_fqdn}"
      source_cert_path="$$${source_cert_folder_path}/fullchain.pem"
      source_key_path="$$${source_cert_folder_path}/privkey.pem"

      # handle cert correct placement
      # dir
      mkdir -p $$${cert_folder_path}
      # cert
      cp -f "$$${source_cert_path}" "$$${cert_path}"
      # key
      cp -f "$$${source_key_path}" "$$${key_path}"
      # owner
      chown $$${proxy_uid}:$$${proxy_gid} "$$${cert_folder_path}" "$$${cert_path}" "$$${key_path}"
      # permissions
      chmod 0600 "$$${cert_path}" "$$${key_path}"

      # restart container
      if podman ps --format "{{.Names}}" 2> /dev/null | grep -q -w $container_name
      then
        echo "restarting $container_name container..."
        podman restart $container_name
      else
        echo "$container_name container not running"
      fi
    TEMPLATE
  }
}
