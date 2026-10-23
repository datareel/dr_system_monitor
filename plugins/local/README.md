# Site plugins

Put plugins written for your own site here, for example a check for
a custom application. DRSM updates never overwrite this directory.

Create one with:

    utils/new_plugin.sh local/myapp
    utils/new_plugin.sh local/myapp_url probe

then add `local/myapp` to `PLUGINS` (or `PROBES`) in a host file under
`etc/hosts`. See PLUGINS.md for the plugin contract.
