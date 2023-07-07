influxdb_install:
  pkg.installed:
    - name: influxdb2

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
