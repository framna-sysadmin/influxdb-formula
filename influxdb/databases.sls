{% from "influxdb/defaults.yaml" import rawmap with context %}
{%- set influxdb = salt['grains.filter_by'](rawmap, grain='os', merge=salt['pillar.get']('influxdb')) %}

{% if "database" in influxdb %}
{% for name in influxdb["database"] %}
influxdb_database_{{ name }}:
  influxdb_database.present:
    - name: {{ name }}
{% endfor %}
{% endif %}
