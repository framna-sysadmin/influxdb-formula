drop-influxdata-pkgrepo:
  pkgrepo.absent:
    - name: deb http://debian.saltstack.com/debian {{ grains['oscodename'] }} stable
    - file: /etc/apt/sources.list.d/influxdata.list
    - key_url: https://repos.influxdata.com/influxdb.key
