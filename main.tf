module "stalwart_mail" {
  source  = "krestomatio/fcos/libvirt"
  version = "0.0.24"

  # custom
  butane_snippets_additional = compact(
    concat(
      [
        try(module.butane_snippet_install_certbot[0].config, ""),
        data.template_file.butane_snippet_install_stalwart_mail.rendered
      ],
      var.butane_snippets_additional
    )
  )

  # butane common
  fqdn               = var.fqdn
  cidr_ip_address    = var.cidr_ip_address
  mac                = var.mac
  ssh_authorized_key = var.ssh_authorized_key
  nameservers        = var.nameservers
  timezone           = var.timezone
  rollout_wariness   = var.rollout_wariness
  periodic_updates   = var.periodic_updates
  keymap             = var.keymap
  autostart          = var.autostart
  etc_hosts_extra    = var.etc_hosts_extra
  # libvirt
  vcpu                  = var.vcpu
  memory                = var.memory
  root_base_volume_name = var.root_base_volume_name
  root_base_volume_pool = var.root_base_volume_pool
  data_volume_pool      = var.data_volume_pool
  data_volume_size      = var.data_volume_size
  data_volume_path      = local.data_volume_path
  backup_volume_pool    = var.backup_volume_pool
  ignition_pool         = var.ignition_pool
  network_bridge        = var.network_bridge
}
