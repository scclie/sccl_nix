local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v13.0.0/main.libsonnet';
local ds = '${DS_PROMETHEUS}';
local node = '{job="node",instance=~"$instance"}';
local selected(extra) = '{job="node",instance=~"$instance",' + extra + '}';
local disks = selected('device=~"$disk"');
local nets = selected('device=~"$interface"');
local fs = selected('mountpoint=~"$mountpoint",fstype!~"tmpfs|ramfs|overlay|squashfs|nsfs|autofs"');
local backend = '{job="prometheus"}';
local rate(metric, selector=node) = 'rate(' + metric + selector + '[$__rate_interval])';

local target(expr, legend='') =
  g.query.prometheus.new(ds, expr)
  + g.query.prometheus.withLegendFormat(legend)
  + g.query.prometheus.withRefId('A');

local ts(id, title, expr, unit, legend, x, y, w=12, description='') =
  g.panel.timeSeries.new(title)
  + g.panel.timeSeries.queryOptions.withTargets([target(expr, legend)])
  + g.panel.timeSeries.standardOptions.withUnit(unit)
  + g.panel.timeSeries.gridPos.withX(x)
  + g.panel.timeSeries.gridPos.withY(y)
  + g.panel.timeSeries.gridPos.withW(w)
  + g.panel.timeSeries.gridPos.withH(8)
  + { id: id, description: description };

local stat(id, title, expr, unit, x, w=4, legend='') =
  g.panel.stat.new(title)
  + g.panel.stat.queryOptions.withTargets([target(expr, legend) + { instant: true }])
  + g.panel.stat.standardOptions.withUnit(unit)
  + g.panel.stat.gridPos.withX(x)
  + g.panel.stat.gridPos.withY(0)
  + g.panel.stat.gridPos.withW(w)
  + g.panel.stat.gridPos.withH(4)
  + { id: id };

local variable(name, label, query, all=false) = {
  name: name,
  label: label,
  type: 'query',
  datasource: { type: 'prometheus', uid: ds },
  query: { query: query, refId: 'variable-' + name },
  definition: query,
  refresh: 1,
  sort: 1,
  multi: all,
  includeAll: all,
} + if all then { allValue: '.+', current: { text: 'all', value: '$__all' } } else {};

g.dashboard.new('host overview')
+ g.dashboard.withUid('sccl-host')
+ g.dashboard.withTags(['infrastructure', 'node-exporter'])
+ g.dashboard.withRefresh('30s')
+ g.dashboard.withTimezone('browser')
+ { time: { from: 'now-6h', to: 'now' } }
+ g.dashboard.graphTooltip.withSharedCrosshair()
+ g.dashboard.withVariables([
  {
    name: 'DS_PROMETHEUS', label: 'datasource', type: 'datasource', query: 'prometheus',
    current: { text: 'Prometheus', value: 'Prometheus' },
  },
  variable('instance', 'host', 'label_values(node_uname_info{job="node"}, instance)'),
  variable('disk', 'disk', 'label_values(node_disk_read_bytes_total' + selected('device!~"loop.*|ram.*|zd.*"') + ', device)', true),
  variable('interface', 'interface', 'label_values(node_network_receive_bytes_total' + selected('device!~"lo|veth.*|docker.*|br-.*"') + ', device)', true),
  variable('mountpoint', 'filesystem', 'label_values(node_filesystem_size_bytes' + selected('fstype!~"tmpfs|ramfs|overlay|squashfs|nsfs|autofs",mountpoint!~"/nix/store|/run(/.*)?|/dev(/.*)?|/sys(/.*)?|/proc(/.*)?"') + ', mountpoint)', true),
])
+ g.dashboard.withPanels([
  stat(1, 'host', 'node_uname_info' + node, 'none', 0, legend='{{nodename}}') + { options+: { textMode: 'name' } },
  stat(2, 'exporter up', 'up' + node, 'none', 4)
    + { fieldConfig+: { defaults+: { min: 0, max: 1, thresholds: { mode: 'absolute', steps: [{ color: 'red', value: null }, { color: 'green', value: 1 }] } } } },
  stat(3, 'uptime', 'time() - node_boot_time_seconds' + node, 's', 8),
  stat(4, 'cpu cores', 'count(node_cpu_seconds_total' + selected('mode="idle"') + ')', 'short', 12),
  stat(5, 'memory', 'node_memory_MemTotal_bytes' + node, 'bytes', 16),
  stat(6, 'failed services', 'sum(node_systemd_unit_state' + selected('state="failed"') + ')', 'short', 20),

  ts(10, 'cpu utilization by mode', 'sum by(mode) (' + rate('node_cpu_seconds_total', selected('mode!~"idle|guest|guest_nice"')) + ') / scalar(count(node_cpu_seconds_total' + selected('mode="idle"') + '))', 'percentunit', '{{mode}}', 0, 4, w=8),
  ts(11, 'cpu utilization per core', '1 - ' + rate('node_cpu_seconds_total', selected('mode="idle"')), 'percentunit', 'cpu {{cpu}}', 8, 4, w=8),
  ts(16, 'normalized load', 'node_load1' + node + ' / scalar(count(node_cpu_seconds_total' + selected('mode="idle"') + '))', 'short', '1m load / cores', 16, 4, w=8,
     description='host load divided by cpu count'),
  ts(12, 'memory used', '1 - node_memory_MemAvailable_bytes' + node + ' / node_memory_MemTotal_bytes' + node, 'percentunit', 'used', 0, 12,
     description='based on memavailable; arc is shown separately'),
  ts(13, 'zfs arc', 'node_zfs_arc_size' + node, 'bytes', 'arc size', 12, 12,
     description='reclaimable zfs cache, not pool health'),
  ts(14, 'swap used', 'node_memory_SwapTotal_bytes' + node + ' - node_memory_SwapFree_bytes' + node, 'bytes', 'used', 0, 20),
  ts(15, 'swap activity', rate('node_vmstat_pswpin'), 'ops', 'pages in/s', 12, 20)
    + { targets: [target(rate('node_vmstat_pswpin'), 'pages in/s'), target(rate('node_vmstat_pswpout'), 'pages out/s') + { refId: 'B' }] },

  ts(20, 'filesystem utilization', '1 - node_filesystem_avail_bytes' + fs + ' / node_filesystem_size_bytes' + fs, 'percentunit', '{{mountpoint}}', 0, 28),
  ts(21, 'filesystem free space', 'node_filesystem_avail_bytes' + fs, 'bytes', '{{mountpoint}}', 12, 28),
  ts(22, 'disk throughput', rate('node_disk_read_bytes_total', disks), 'Bps', '{{device}} read', 0, 36)
    + { targets: [target(rate('node_disk_read_bytes_total', disks), '{{device}} read'), target(rate('node_disk_written_bytes_total', disks), '{{device}} write') + { refId: 'B' }] },
  ts(23, 'disk iops', rate('node_disk_reads_completed_total', disks), 'iops', '{{device}} read', 12, 36)
    + { targets: [target(rate('node_disk_reads_completed_total', disks), '{{device}} read'), target(rate('node_disk_writes_completed_total', disks), '{{device}} write') + { refId: 'B' }] },
  ts(24, 'disk latency', rate('node_disk_read_time_seconds_total', disks) + ' / (' + rate('node_disk_reads_completed_total', disks) + ' > 0)', 's', '{{device}} read', 0, 44)
    + { targets: [
      target(rate('node_disk_read_time_seconds_total', disks) + ' / (' + rate('node_disk_reads_completed_total', disks) + ' > 0)', '{{device}} read'),
      target(rate('node_disk_write_time_seconds_total', disks) + ' / (' + rate('node_disk_writes_completed_total', disks) + ' > 0)', '{{device}} write') + { refId: 'B' },
    ] },
  ts(25, 'disk busy time', rate('node_disk_io_time_seconds_total', disks), 'percentunit', '{{device}}', 12, 44),

  ts(30, 'network throughput', rate('node_network_receive_bytes_total', nets), 'Bps', '{{device}} receive', 0, 52)
    + { targets: [target(rate('node_network_receive_bytes_total', nets), '{{device}} receive'), target(rate('node_network_transmit_bytes_total', nets), '{{device}} transmit') + { refId: 'B' }] },
  ts(31, 'network errors and drops', rate('node_network_receive_errs_total', nets), 'ops', '{{device}} receive errors', 12, 52)
    + { targets: [
      target(rate('node_network_receive_errs_total', nets), '{{device}} receive errors'),
      target(rate('node_network_transmit_errs_total', nets), '{{device}} transmit errors') + { refId: 'B' },
      target(rate('node_network_receive_drop_total', nets), '{{device}} receive drops') + { refId: 'C' },
      target(rate('node_network_transmit_drop_total', nets), '{{device}} transmit drops') + { refId: 'D' },
    ] },
  ts(32, 'temperatures', 'node_hwmon_temp_celsius' + node, 'celsius', '{{chip}} / {{sensor}}', 0, 60),
  ts(33, 'resource pressure', rate('node_pressure_cpu_waiting_seconds_total'), 'percentunit', 'cpu', 12, 60)
    + { targets: [
      target(rate('node_pressure_cpu_waiting_seconds_total'), 'cpu'),
      target(rate('node_pressure_memory_waiting_seconds_total'), 'memory') + { refId: 'B' },
      target(rate('node_pressure_io_waiting_seconds_total'), 'i/o') + { refId: 'C' },
    ] },
  ts(34, 'failed systemd services', 'node_systemd_unit_state' + selected('state="failed"') + ' == 1', 'short', '{{name}}', 0, 68,
     description='persistent services only; empty when none have failed'),
  ts(35, 'zfs arc hit ratio', rate('node_zfs_arc_hits') + ' / (' + rate('node_zfs_arc_hits') + ' + ' + rate('node_zfs_arc_misses') + ' > 0)', 'percentunit', 'hit ratio', 12, 68),

  ts(40, 'prom++ resident memory', 'process_resident_memory_bytes' + backend, 'bytes', 'rss', 0, 76,
     description='backend total, independent of selected host'),
  ts(41, 'prom++ active series', 'prometheus_tsdb_head_series' + backend, 'short', 'series', 12, 76),
  ts(42, 'ingestion samples per second', rate('prometheus_tsdb_head_samples_appended_total', backend), 'ops', 'samples/s', 0, 84),
  ts(43, 'historical tsdb blocks', 'prometheus_tsdb_storage_blocks_bytes' + backend, 'bytes', 'blocks', 12, 84,
     description='blocks only; excludes wal, head and snapshots'),
  ts(44, 'uptime', 'time() - node_boot_time_seconds' + node, 's', 'uptime', 0, 92, w=24),
], setPanelIDs=false)
