{% from "influxdb/defaults.yaml" import rawmap with context %}
{%- set influxdb = salt['grains.filter_by'](rawmap, grain='os', merge=salt['pillar.get']('influxdb')) %}

{% if "user" in influxdb %}
{% for name,config in influxdb["user"].items() %}
influxdb_user_{{ loop.index0 }}:
  influxdb_user.present:
    - name: {{ name }}
    - passwd: {{ config["password"] }}
{% if "admin" in config %}
    - admin: {{ config["admin"] }}
{% endif %}
{% if "grants" in config %}
    - grants: {{ config["grants"] }}
{% endif %}
{% endfor %}
{% endif %}
