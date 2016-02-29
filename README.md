Table of Contents
=================

  * [Overview](#overview)
  * [How To Set It All Up](#how-to-set-it-all-up)
    * [Enable Code Manager](#enable-code-manager)
    * [Disable Webhook Auth If Using Gitlab](#disable-webhook-auth-if-using-gitlab)
  * [Connecting Code Manager / r10k to Your Git Server](#connecting-code-manager--r10k-to-your-git-server)
    * [Steps for Configuring SSH Access to your control\-repo via this module](#steps-for-configuring-ssh-access-to-your-control-repo-via-this-module)
    * [Exact Timing and Order of Events](#exact-timing-and-order-of-events)
  * [Relation to the puppetlabs/control\-repo](#relation-to-the-puppetlabscontrol-repo)

Created by [gh-md-toc](https://github.com/ekalinin/github-markdown-toc.go)

# Overview

This module allow for easy setup and configuration of PE code manager in PE2015.3 and above.  If you are using PE 2015.2 then the module will default to installing the zack/r10k webhook.  

Upon upgrading to 2015.3 the module will uninstall zack/r10k and attempt to use code manager but this requires that you've set the correct parameters in the puppet_enterprise module for it to work.  

This module was originally a very prescriptive profile in the puppetlabs/control-repo but is now here as its own module to make it more widely available.  As a result, you may find that some items are not configurable but we're working on that.  

# How To Set It All Up

## Enable Code Manager

In order to use code manager ( and thus this module ) you must set the following parameter to true via hiera or the PE console UI.  

```
puppet_enterprise::profile::master::code_manager_auto_configure: true
```

## Disable Webhook Auth If Using Gitlab

If you are using Gitlab as your git UI then you will also need to set the following hiera key to disable authentication to the code manager webhook.  This is because gitlab currently does not allow for webhook urls that are longer than 255 characters while the RBAC token you need to place in the URL is, on its own, longer than 255 characters.  

If you are using an older version of gitlab ( before version 8 ) then you will not have the ability to disable ssl verification either and would need to disable the webhook authentication on code manager. 
```
puppet_enterprise::master::code_manager::authenticate_webhook: false
```

http://docs.puppetlabs.com/pe/2015.3/release_notes_known_issues_codemgmt.html#turn-off-webhook-authentication-for-gitlab

# Connecting Code Manager / r10k to Your Git Server

Code Manager or r10k ( which Code Manager is based on ) require ssh authentication to your git repo.  The basic steps are:

1.  Create a ssh key
2.  Make said ssh key a deploy key on your control-repo
3.  Configure r10k / Code Manager to use this ssh key

## Steps for Configuring SSH Access to your control-repo via this module

1. `/usr/bin/ssh-keygen -t rsa -b 2048 -C 'code_manager' -f /etc/puppetlabs/puppetserver/ssh/id-control_repo.rsa -q -N ''`
 - http://doc.gitlab.com/ce/ssh/README.html
 - https://help.github.com/articles/generating-ssh-keys/
2.  Create a deploy key on the control-repo project in your git server
 - Paste in the public key from above
 - `cat /etc/puppetlabs/puppetserver/ssh/id-control_repo.rsa.pub`
3. Login to the PE console
4. Navigate to the Classification page
 - Click on the PE Master group
 - Click the Classes tab
   - Add the puppet_enterprise::profile::master
     - Set the r10k_remote to the ssh url of your git repo
     - Set the r10k_private_key parameter to /etc/puppetlabs/puppetserver/ssh/id-control_repo.rsa.key
   - Commit your changes

## Exact Timing and Order of Events

In order to enable code manager using this module you need to complete a very specific set of steps in the right order.  

1.  Make sure the code from this module is on your master
 - You could either use a `puppet module install` or maybe an `r10k deploy environmnt -pv`
2. Enable code manager
 - Set the parameter and run `puppet agent -t`
3. In order to allow file sync ( a companion to code manager) to deploy code it needs a clean $codedir ( meaning nothing in it )
 - This problem is solved in the puppet code via an exec statement that only runs if you set the following custom fact
   - `echo 'code_manager_mv_old_code=true' > /opt/puppetlabs/facter/facts.d/code_manager_mv_old_code.txt`
4. Finally run `puppet agent -t` 2-3 times to make sure all of the configuration completes 

# Relation to the puppetlabs/control-repo

This module was created as a part of the puppetlabs/control-repo and for the time being the documentation in that control-repo may also serve as a useful supplement to this module.  

In fact if you are a new user of PE then you may consider using the puppetabs/control repo instead of trying to implement this module on its own.  
