locals {
  data_volume_path     = "/var/opt/stalwart-mail"
  systemd_stop_timeout = 30
  stalwart_mail_image  = "${var.image.name}:${var.image.version}"
  post_hook = {
    path    = "/usr/local/bin/stalwart-mail-certbot-renew-hook"
    content = <<-TEMPLATE
      #!/bin/bash

      # vars
      stalwart_mail_cert_folder_path="${local.data_volume_path}/etc/certs/${var.external_fqdn}"
      stalwart_mail_cert_path="$$${stalwart_mail_cert_folder_path}/fullchain.pem"
      stalwart_mail_key_path="$$${stalwart_mail_cert_folder_path}/privkey.pem"
      stalwart_mail_proxy_uid="0"
      stalwart_mail_proxy_gid="0"
      source_cert_folder_path="/etc/letsencrypt/live/${var.external_fqdn}"
      source_cert_path="$$${source_cert_folder_path}/fullchain.pem"
      source_key_path="$$${source_cert_folder_path}/privkey.pem"

      # handle cert correct placement
      # dir
      mkdir -p $$${stalwart_mail_cert_folder_path}
      # cert
      cp -f "$$${source_cert_path}" "$$${stalwart_mail_cert_path}"
      # key
      cp -f "$$${source_key_path}" "$$${stalwart_mail_key_path}"
      # owner
      chown $$${stalwart_mail_proxy_uid}:$$${stalwart_mail_proxy_gid} "$$${stalwart_mail_cert_folder_path}" "$$${stalwart_mail_cert_path}" "$$${stalwart_mail_key_path}"
      # permissions
      chmod 0660 "$$${stalwart_mail_cert_path}" "$$${stalwart_mail_key_path}"

      # restart container
      if podman ps stalwart-mail &> /dev/null
      then
        podman restart stalwart-mail
      else
        echo "stalwart-mail container not running"
      fi
    TEMPLATE
  }
}
