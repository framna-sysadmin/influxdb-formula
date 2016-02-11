influxdata-pkgrepo:
  pkgrepo.managed:
    - name: influxdata
    - humanname: InfluxData repo for RHEL/CentOS $releasever
    - baseurl: https://repos.influxdata.com/rhel/$releasever/$basearch/stable
    - enabled: 1
    - gpgcheck: 1
    - gpgkey: https://repos.influxdata.com/influxdb.key
