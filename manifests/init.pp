class pe_git_webhook (
  $force_zack_r10k_webhook = false
) {

  #Determine if code manager is enabled
  $code_manager_auto_configure_nc_value    = node_groups('PE Master')['PE Master']['classes']['puppet_enterprise::profile::master']['code_manager_auto_configure']
  $code_manager_auto_configure_hiera_value = hiera('puppet_enterprise::profile::master::code_manager_auto_configure')
  #The NC value will take precedence over the hiera value, if neither is set then it defaults to false
  $code_manager_auto_configure             = pick($code_manager_auto_configure_nc_value, $code_manager_auto_configure_hiera_value, false)

  if versioncmp( $::pe_server_version, '2015.2.99' ) <= 0 or $force_zack_r10k_webhook {
    include pe_git_webhook::zack_r10k_webhook
  } elsif versioncmp( $::pe_server_version, '2015.2.99' ) > 0 and $code_manager_auto_configure == false {
    notify { "Please Enable Code Manager via the PE Console UI or hiera with this parameter `puppet_enterprise::profile::master::code_manager_auto_configure`"}
  } else {
    include pe_git_webhook::code_manager
    include pe_git_webhook::zack_r10k_webhook_disable
  }

}
