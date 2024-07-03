{% from "influxdb/defaults.yaml" import rawmap with context %}
{%- set influxdb = salt['grains.filter_by'](rawmap, grain='os_family', merge=salt['pillar.get']('influxdb')) %}

influxdb_install:
  pkg.installed:
{%- if influxdb.version | default(1) > 1 %}
    - name: influxdb{{ influxdb.version }}
{%- else %}
    - name: influxdb
{%- endif %}

{%- if salt['grains.get']('os_family') == 'RedHat' and salt['grains.get']('osmajorrelease') < 8 %}
influxdb_python_bindings_install:
  pkg.installed:
    - name: python-influxdb
{%- endif %}

influxdb_python3_bindings_install:
  pkg.installed:
{%- if salt['grains.get']('os_family') == 'RedHat' and salt['grains.get']('osmajorrelease') < 8 %}
    - name: python36-influxdb
{%- else %}
    - name: python3-influxdb
{%- endif %}
