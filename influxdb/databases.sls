{% from "influxdb/defaults.yaml" import rawmap with context %}
{%- set influxdb = salt['grains.filter_by'](rawmap, grain='os', merge=salt['pillar.get']('influxdb')) %}

{% if "database" in influxdb %}
{% for config in influxdb["database"] %}
influxdb_database_{{ config['name'] }}:
  influxdb_database.present:
    - name: {{ config['name'] }}
{% endfor %}
{% endif %}
