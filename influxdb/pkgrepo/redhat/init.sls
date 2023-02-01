influxdata-pkgrepo:
  pkgrepo.managed:
    - name: influxdata
    - humanname: InfluxData Repository - Stable
    - baseurl: https://repos.influxdata.com/stable/$basearch/main
    - enabled: 1
    - gpgcheck: 1
    - gpgkey: https://repos.influxdata.com/influxdata-archive_compat.key