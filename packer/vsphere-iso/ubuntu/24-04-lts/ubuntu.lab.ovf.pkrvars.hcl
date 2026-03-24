# Lab-specific OVF export settings for Ubuntu 24.04 LTS.
# This keeps the build as a powered-off golden VM and also exports OVF artifacts
# that can be imported by govc in standalone ESXi lab environments.

common_template_conversion = false
common_ovf_export_enabled  = true
common_ovf_export_overwrite = true
