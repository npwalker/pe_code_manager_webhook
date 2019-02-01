# Configures Code Manager in PE
#
# @summary Configures Code Manager in PE
#
# @example
#   include pe_code_manager_webhook::code_manager
class pe_code_manager_webhook::code_manager (
  Boolean $authenticate_webhook             = hiera('puppet_enterprise::master::code_manager::authenticate_webhook', true),
  String  $code_manager_service_user        = 'code_manager_service_user',
  String  $token_directory                  = '/etc/puppetlabs/puppetserver/.puppetlabs',
  Optional[String] $gms_api_token           = hiera('gms_api_token', undef),
  String  $git_management_system            = hiera('git_management_system', 'github'),
  String  $code_manager_ssh_key_directory   = '/etc/puppetlabs/puppetserver/ssh',
  String  $code_manager_ssh_key_file_name   = 'id-control_repo.rsa',
  String  $code_manager_role_name           = versioncmp($::pe_server_version, '2016.5.0') ? {
                                                -1      => 'Deploy Environments',
                                                default => 'Code Deployers',
                                              },
  Boolean $create_and_manage_git_deploy_key = true,
  Boolean $manage_git_webhook               = true,
  String  $control_repo_project_name        = 'puppet/control-repo',
  ){

  $token_filename                     = "${token_directory}/${code_manager_service_user}_token"
  $code_manager_service_user_password = fqdn_rand_string(40, '', "${code_manager_service_user}_password")

  #master_classifier_settings is a custom function
  #2016.5.0 makes classifer.yaml an array of hashes
  #instead of just a hash
  if versioncmp($::pe_server_version, '2016.5.0') >= 0 {
    $classifier_settings = master_classifer_settings()[0]
  } else {
    $classifier_settings = master_classifer_settings()
    $create_role_creates_file = "${token_directory}/deploy_environments_created"
  }

  $classifier_hostname   = $classifier_settings['server']
  $classifier_port       = $classifier_settings['port']

  if $create_and_manage_git_deploy_key {
    file { $code_manager_ssh_key_directory :
      ensure => directory,
      owner  => 'pe-puppet',
      group  => 'pe-puppet',
    }

    #backwards compatibility - move the ssh key from the previously suggested location
    $old_code_manager_ssh_key_file = '/etc/puppetlabs/puppetserver/code_manager.key'
    $code_manager_ssh_key_file = "${code_manager_ssh_key_directory}/${code_manager_ssh_key_file_name}"

    exec { 'create code manager ssh key' :
      command => "/usr/bin/ssh-keygen -t rsa -b 2048 -C 'code_manager' -f ${code_manager_ssh_key_file} -q -N ''",
      creates => $code_manager_ssh_key_file,
      require => File[$code_manager_ssh_key_directory],
    }

    file { [ $code_manager_ssh_key_file, "${code_manager_ssh_key_file}.pub" ] :
      ensure  => file,
      owner   => 'pe-puppet',
      group   => 'pe-puppet',
      require => Exec['create code manager ssh key'],
    }
  }

  #If files exist in the codedir code manager can't manage them unless pe-puppet can read them
  exec { 'pe_code_manager_webhook chown all environments to pe-puppet' :
    command => "/bin/chown -R pe-puppet:pe-puppet ${::settings::codedir}",
    unless  => "/usr/bin/test \$(stat -c %U ${::settings::codedir}/environments/production) = 'pe-puppet'",
  }

  #Do not create the role in 2016.5 we can use the existing role
  #and the token override_lifetime permission no longer exists
  if versioncmp($::pe_server_version, '2016.5.0') < 0 {
    $create_role_curl = @(EOT)
      /opt/puppetlabs/puppet/bin/curl -k -X POST -H 'Content-Type: application/json' \
      https://<%= $classifier_hostname %>:4433/rbac-api/v1/roles \
      -d '{"permissions": [{"object_type": "environment", "action": "deploy_code", "instance": "*"},
      {"object_type": "tokens", "action": "override_lifetime", "instance": "*"}],"user_ids": [], "group_ids": [], "display_name": "<%= $code_manager_role_name  %>", "description": ""}' \
      --cert <%= $::settings::certdir %>/<%= $::trusted['certname'] %>.pem  \
      --key <%= $::settings::privatekeydir %>/<%= $::trusted['certname'] %>.pem  \
      --cacert <%= $::settings::certdir %>/ca.pem;
      touch <%= $create_role_creates_file %>
      | EOT

    exec { 'create deploy environments role' :
      command   => inline_epp( $create_role_curl ),
      creates   => $create_role_creates_file,
      logoutput => true,
      path      => $::path,
      require   => File[$token_directory],
      before    => Rbac_user[$code_manager_service_user],
    }
  }

  rbac_user { $code_manager_service_user :
    ensure       => 'present',
    name         => $code_manager_service_user,
    email        => "${code_manager_service_user}@example.com",
    display_name => 'Code Manager Service Account',
    password     => $code_manager_service_user_password,
    roles        => [ $code_manager_role_name ],
  }

  file { $token_directory :
    ensure => directory,
    owner  => 'pe-puppet',
    group  => 'pe-puppet',
  }

  exec { "Generate Token for ${code_manager_service_user}" :
    command => epp('pe_code_manager_webhook/code_manager/create_rbac_token.epp',
                  { 'code_manager_service_user'          => $code_manager_service_user,
                    'code_manager_service_user_password' => $code_manager_service_user_password,
                    'classifier_hostname'                => $classifier_hostname,
                    'classifier_port'                    => $classifier_port,
                    'token_filename'                     => $token_filename
                  }),
    creates => $token_filename,
    require => [ Rbac_user[$code_manager_service_user], File[$token_directory] ],
  }

  #this file cannont be read until the next run after the above exec
  #because the file function runs on the master not on the agent
  #so the file doesn't exist at the time the function is run
  $rbac_token_file_contents = file($token_filename, '/dev/null')

  #Only mv code if this is at least the 2nd run of puppet
  #Code manager needs to be enabled and puppet server restarted
  #before this exec can complete.  Gating on the token file
  #ensures at least one run has completed
  if $::code_manager_mv_old_code and !empty($rbac_token_file_contents) {

    $timestamp = chomp(generate('/bin/date', '+%Y%d%m_%H:%M:%S'))

    exec { 'mv files out of $environmentpath' :
      command   => "mkdir /etc/puppetlabs/env_back_${timestamp};
                    mv ${::settings::codedir}/environments/* /etc/puppetlabs/env_back_${timestamp}/;
                    rm /opt/puppetlabs/facter/facts.d/code_manager_mv_old_code.txt;
                    TOKEN=`/opt/puppetlabs/puppet/bin/ruby -e \"require 'json'; puts JSON.parse(File.read('${token_filename}'))['token']\"`;
                    /opt/puppetlabs/puppet/bin/curl -k -X POST -H 'Content-Type: application/json' \"https://${::trusted['certname']}:8170/code-manager/v1/deploys?token=\$TOKEN\" -d '{\"environments\": [\"${::environment}\"], \"wait\": true}';
                    /opt/puppetlabs/puppet/bin/curl -k -X POST -H 'Content-Type: application/json' \"https://${::trusted['certname']}:8170/code-manager/v1/deploys?token=\$TOKEN\" -d '{\"deploy-all\": true, \"wait\": true}';
                    sleep 15",
      path      => $::path,
      logoutput => true,
      require   => Exec["Generate Token for ${code_manager_service_user}"],
    }
  }


  if $authenticate_webhook and !empty($rbac_token_file_contents) {

    $rbac_token = parsejson($rbac_token_file_contents)['token']
    $token_info = "&token=${rbac_token}"
  }
  else {
    $token_info = ''
  }

  $code_manager_webhook_type = $git_management_system ? {
                                 'gitlab' => 'github',               # lint:ignore:2sp_soft_tabs
                                 default  => $git_management_system, # lint:ignore:2sp_soft_tabs
  }

  $webhook_url = "https://${::fqdn}:8170/code-manager/v1/webhook?type=${code_manager_webhook_type}${token_info}"

  file { "${token_directory}/webhook_url.txt" :
    ensure  => file,
    content => $webhook_url,
  }

  if !empty($gms_api_token) {
    if $create_and_manage_git_deploy_key {
      git_deploy_key { "add_deploy_key_to_puppet_control-${::fqdn}":
        ensure       => present,
        name         => "code manager-${::fqdn}",
        path         => "${code_manager_ssh_key_file}.pub",
        token        => $gms_api_token,
        project_name => $control_repo_project_name,
        server_url   => hiera('gms_server_url'),
        provider     => $git_management_system,
      }
    }

    if $manage_git_webhook {
      git_webhook { "code_manager_post_receive_webhook-${::fqdn}" :
        ensure             => present,
        webhook_url        => $webhook_url,
        token              => $gms_api_token,
        project_name       => $control_repo_project_name,
        server_url         => hiera('gms_server_url'),
        provider           => $git_management_system,
        disable_ssl_verify => true,
      }
    }
  }
}
