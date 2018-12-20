{% from "influxdb/defaults.yaml" import rawmap with context %}
{%- set influxdb = salt['grains.filter_by'](rawmap, grain='os', merge=salt['pillar.get']('influxdb')) %}

{% if "database" in influxdb %}
{% for config in influxdb["database"] %}
influxdb_database_{{ config['name'] }}:
  influxdb_database.present:
    - name: {{ config['name'] }}

{% if 'retention_policies' in config %}
{% for rp_config in config['retention_policies'] %}
influxdb_database_{{ config['name'] }}_retention_policy_{{ rp_config['name'] }}:
  influxdb_retention_policy.present:
    - name: {{ rp_config['name'] }}
    - database: {{ config['name'] }}
    - duration: {{ rp_config['duration'] }}
    - require:
      - influxdb_database: influxdb_database_{{ config['name'] }}
{% endfor %}
{% endif %}
{% endfor %}
{% endif %}
