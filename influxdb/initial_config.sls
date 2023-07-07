{% from "influxdb/defaults.yaml" import rawmap with context %}
{%- set influxdb = salt['grains.filter_by'](rawmap, grain='os_family', merge=salt['pillar.get']('influxdb')) %}

{% if "config" in influxdb %}
influxdb_initial_config:
  file.managed:
    - name: {{ influxdb.config_file }}
    - template: jinja
    - source: salt://influxdb/files/influxdb.conf
    - user: root
    - group: root
    - mode: '0644'
    - context:
        initialConfig: True
{% endif %}
