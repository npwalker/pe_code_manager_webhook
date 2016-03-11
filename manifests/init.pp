class pe_code_manager_webhook (
  $force_zack_r10k_webhook    = false,
  $force_code_manager_webhook = false,
) {

  #Determine if code manager is enabled
  #Querying the NC requires the puppetclassify gem and this seems like undue setup burden for a small check at this time
  #$code_manager_auto_configure_nc_value    = node_groups('PE Master')['PE Master']['classes']['puppet_enterprise::profile::master']['code_manager_auto_configure']
  $code_manager_auto_configure_hiera_value = hiera('puppet_enterprise::profile::master::code_manager_auto_configure', false)
  #The NC value will take precedence over the hiera value, if neither is set then it defaults to false
  $code_manager_auto_configure             = pick($code_manager_auto_configure_nc_value, $code_manager_auto_configure_hiera_value, $force_code_manager_webhook)

  if versioncmp( $::pe_server_version, '2015.2.99' ) <= 0 or $force_zack_r10k_webhook {
    include pe_code_manager_webhook::zack_r10k_webhook
  } elsif versioncmp( $::pe_server_version, '2015.2.99' ) > 0 and $code_manager_auto_configure == false {
    notify { 'Please Enable Code Manager via hiera with this parameter `puppet_enterprise::profile::master::code_manager_auto_configure`.  If you enabled code manager via the PE Console you may set $force_code_manager_webhook to true.' : }
  } else {
    include pe_code_manager_webhook::code_manager
    include pe_code_manager_webhook::zack_r10k_webhook_disable
  }

}
