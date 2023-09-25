data "template_file" "butane_snippet_install_stalwart_mail" {
  template = <<TEMPLATE
---
variant: fcos
version: 1.4.0
storage:
  files:
    # pkg dependencies to be installed by additional-rpms.service
    - path: /var/lib/additional-rpms.list
      overwrite: false
      append:
        - inline: |
            firewalld
    - path: /usr/local/bin/stalwart-mail-installer.sh
      mode: 0754
      overwrite: true
      contents:
        inline: |
          #!/bin/bash -e
          # vars

          ## firewalld rules
          if ! systemctl is-active firewalld &> /dev/null
          then
            echo "Enabling firewalld..."
            systemctl restart dbus.service
            restorecon -rv /etc/firewalld
            systemctl enable --now firewalld
            echo "Firewalld enabled..."
          fi
          # Add firewalld rules
          echo "Adding firewalld rules..."
          firewall-cmd --zone=public --permanent --add-port=25/tcp
          firewall-cmd --zone=public --permanent --add-port=465/tcp
          firewall-cmd --zone=public --permanent --add-port=587/tcp
          firewall-cmd --zone=public --permanent --add-port=143/tcp
          firewall-cmd --zone=public --permanent --add-port=993/tcp
          firewall-cmd --zone=public --permanent --add-port=4190/tcp
          firewall-cmd --zone=public --permanent --add-port=443/tcp
          # firewall-cmd --zone=public --add-masquerade
          firewall-cmd --reload
          echo "Firewalld rules added..."

          # selinux context to data dir
          chcon -Rt svirt_sandbox_file_t ${local.data_volume_path}

          # install
          echo "Installing stalwart-mail service..."
          podman kill stalwart-mail 2>/dev/null || echo
          podman rm stalwart-mail 2>/dev/null || echo
          podman create --pull never --rm --restart on-failure --stop-timeout ${local.systemd_stop_timeout} \
            %{~if var.cpus_limit > 0~}
            --cpus ${var.cpus_limit} \
            %{~endif~}
            %{~if var.memory_limit != ""~}
            --memory ${var.memory_limit} \
            %{~endif~}
            -p 25:25 \
            -p 143:143 \
            -p 587:587 \
            -p 993:993 \
            -p 4190:4190 \
            -p 8080:8080 \
            --volume /etc/localtime:/etc/localtime:ro \
            --volume "${local.data_volume_path}:/opt/stalwart-mail" \
            --name stalwart-mail ${local.stalwart_mail_image}
          podman generate systemd --new \
            --restart-sec 15 \
            --start-timeout 180 \
            --stop-timeout ${local.systemd_stop_timeout} \
            --after stalwart-mail-image-pull.service \
            --name stalwart-mail > /etc/systemd/system/stalwart-mail.service
          systemctl daemon-reload
          systemctl enable --now stalwart-mail.service
          echo "stalwart-mail service installed..."
systemd:
  units:
    - name: stalwart-mail-image-pull.service
      enabled: true
      contents: |
        [Unit]
        Description="Pull stalwart-mail image"
        Wants=network-online.target
        After=network-online.target
        Before=install-stalwart-mail.service
        Before=stalwart-mail.service

        [Service]
        Type=oneshot
        RemainAfterExit=yes
        Restart=on-failure
        RestartSec=10
        TimeoutStartSec=180
        ExecStart=/usr/bin/podman pull ${local.stalwart_mail_image}

        [Install]
        WantedBy=multi-user.target
    - name: install-stalwart-mail.service
      enabled: true
      contents: |
        [Unit]
        Description=Install stalwart-mail
        # We run before `zincati.service` to avoid conflicting rpm-ostree
        # transactions.
        Before=zincati.service
        Wants=network-online.target
        After=network-online.target
        After=additional-rpms.service
        After=install-certbot.service
        After=stalwart-mail-image-pull.service
        OnSuccess=stalwart-mail.service
        ConditionPathExists=/usr/local/bin/stalwart-mail-installer.sh
        ConditionPathExists=!/var/lib/%N.done
        StartLimitInterval=500
        StartLimitBurst=3

        [Service]
        Type=oneshot
        RemainAfterExit=yes
        Restart=on-failure
        RestartSec=60
        TimeoutStartSec=300
        ExecStart=/usr/local/bin/stalwart-mail-installer.sh
        ExecStart=/bin/touch /var/lib/%N.done

        [Install]
        WantedBy=multi-user.target
TEMPLATE
}

module "butane_snippet_install_certbot" {
  count = var.certbot != null ? 1 : 0

  source  = "krestomatio/butane-snippets/ct//modules/certbot"
  version = "0.0.12"

  domain       = var.external_fqdn
  http_01_port = var.certbot.http_01_port
  post_hook    = local.post_hook
  agree_tos    = var.certbot.agree_tos
  staging      = var.certbot.staging
  email        = var.certbot.email
}
