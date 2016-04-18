Table of Contents
=================

* [Overview](#overview)
* [What Does This Module Provide You?](#what-does-this-module-provide-you)
* [Easy Button Setup](#easy-button-setup)
* [Other Notes:](#other-notes)
  * [Disable Webhook Auth If Using Gitlab Version &lt; 8\.5](#disable-webhook-auth-if-using-gitlab-version--85)
  * [Relation to the puppetlabs\-rampupprogram/control\-repo](#relation-to-the-puppetlabs-rampupprogramcontrol-repo)
  * [The Zack/r10k functionality of the Module is Undocumented](#the-zackr10k-functionality-of-the-module-is-undocumented)

# Overview

This module allows for easy setup and configuration of PE code manager in PE2015.3 and above.  If you are using PE 2015.2 then the module will default to installing the zack/r10k webhook.

Upon upgrading to 2015.3 the module will uninstall zack/r10k and attempt to use code manager but this requires that you've set the correct parameters in the puppet_enterprise module for it to work.  

This module was originally a very prescriptive profile in the [puppetlabs-rampupprogram/control-repo](https://github.com/PuppetLabs-RampUpProgram/control-repo) but is now here as its own module to make it more widely available.

# What Does This Module Provide You?

1. A new RBAC role for deploying code ( Deploy Environments )
2. A new RBAC user for deploying code ( code_manager_service_user )
3. An infinite liftetime token from the RBAC user for use in a webhook
4. A newly generated SSH key with the correct permissions to be used by code manager
 - And for you to setup in your Git server of choice as a deploy key
5. Correctly chowns the $codedir so that code manager can deploy to it
6. A file containing the webhook url to paste into your Git UI
 - Located at `/etc/puppetlabs/puppetserver/.puppetlabs/webhook_url.txt` by default

# Easy Button Setup

1. Login to the PE console
2. Navigate to the Classification page
 - Click on the PE Master group
 - Click the Classes tab
   - Find the `puppet_enterprise::profile::master` class
      - Set the `code_manager_auto_configure` to `true`
      - Set the `r10k_remote` to the SSH url of your git repo
      - Set the `r10k_private_key` parameter to `/etc/puppetlabs/puppetserver/ssh/id-control_repo.rsa.key`
   - Commit your changes

3. Enable code mananger then install and run this module:

   ~~~
   puppet agent -t
   puppet module install npwalker-pe_code_manager_webhook
   chown -R pe-puppet:pe-puppet /etc/puppetlabs/code/
   puppet apply -e "include pe_code_manager_webhook::code_manager"
   ~~~

4. Configure a deploy key in your Git server using the SSH key created by the module
 - You'll paste `cat /etc/puppetlabs/puppetserver/ssh/id-control_repo.rsa.pub`
7. Create a webhook on the control-repo repository in your Git server UI
 - The URL to connect to code manager is found at `/etc/puppetlabs/puppetserver/.puppetlabs/webhook_url.txt`
8. Assuming this was a new install with no previous code in the code directory then everything worked.
If not, try clearing all of the code and redeploying it with code manager
 - `echo 'code_manager_mv_old_code=true' > /opt/puppetlabs/facter/facts.d/code_manager_mv_old_code.txt; puppet agent -t`



# Other Notes:

## Disable Webhook Auth If Using Gitlab Version < 8.5

If you are using [Gitlab < 8.5](https://gitlab.com/gitlab-org/gitlab-ce/commit/e80113593c120b71af428ea1b00f11fcdeae58b8) as your git UI then you will also need to set the following hiera key to disable authentication to the code manager webhook.  This is because gitlab currently does not allow for webhook urls that are longer than 255 characters while the RBAC token you need to place in the URL is, on its own, longer than 255 characters.

If you are using an older version of gitlab ( before version 8 ) then you will not have the ability to disable ssl verification either and would need to disable the webhook authentication on code manager.
```
puppet_enterprise::master::code_manager::authenticate_webhook: false
```

http://docs.puppetlabs.com/pe/2015.3/release_notes_known_issues_codemgmt.html#turn-off-webhook-authentication-for-gitlab

## Relation to the puppetlabs-rampupprogram/control-repo

This module was created as a part of the [puppetlabs-rampupprogram/control-repo](https://github.com/PuppetLabs-RampUpProgram/control-repo) and for the time being the documentation in that control-repo may also serve as a useful supplement to this module.

In fact if you are a new user of PE then you may consider using the puppetabs/control repo instead of trying to implement this module on its own.

## The Zack/r10k functionality of the Module is Undocumented

The purpose of this module is mostly for configuring code manager but the zack/r10k functionality is left in place undocumented.
