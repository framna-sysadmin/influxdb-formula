influxdb_install:
  pkg.installed:
    - name: influxdb

influxdb_python_bindings_install:
  pkg.installed:
    - name: python-influxdb

influxdb_python3_bindings_install:
  pkg.installed:
    - name: python36-influxdb
