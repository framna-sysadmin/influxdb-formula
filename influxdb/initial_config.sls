{% from "influxdb/defaults.yaml.jinja2" import rawmap with context %}
{%- set influxdb = salt['grains.filter_by'](rawmap, grain='os_family', merge=salt['pillar.get']('influxdb')) %}

{% if "config" in influxdb %}
influxdb_initial_config:
  file.managed:
    - name: {{ influxdb.config_file }}
    - template: jinja
    - source: salt://influxdb/files/influxdb.conf.jinja2
    - user: root
    - group: root
    - mode: '0644'
    - context:
        initialConfig: True
{% endif %}
