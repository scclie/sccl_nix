local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v13.0.0/main.libsonnet';
local ds = '${DS_LOKI}';
local journals = 'job=~"loki[.]source[.]journal[.].+"';
local host = journals + ',host=~`${host:regex}`';
local source = host + ',source=~`${source:regex}`';
local container = source + ',container=~`${container:regex}`';
local unit = container + ',unit=~`${unit:regex}`';
local logs = '{' + unit + ',level=~`${level:regex}`} |= ${search:doublequote}';

local variable(name, stream) = {
  name: name,
  label: name,
  type: 'query',
  datasource: { type: 'loki', uid: ds },
  query: { type: 1, label: name, stream: '{' + stream + '}' },
  refresh: 2,
  sort: 1,
  multi: true,
  includeAll: true,
  allValue: '.*',
  current: { text: 'all', value: '$__all' },
};

local target(expr) =
  g.query.loki.new(ds, expr)
  + g.query.loki.withRefId('A')
  + g.query.loki.withQueryType('range');

g.dashboard.new('logs')
+ g.dashboard.withUid('sccl-logs')
+ g.dashboard.withTags(['logs', 'loki'])
+ g.dashboard.withRefresh('10s')
+ g.dashboard.withTimezone('browser')
+ { time: { from: 'now-1h', to: 'now' } }
+ g.dashboard.graphTooltip.withSharedCrosshair()
+ g.dashboard.withVariables([
  {
    name: 'DS_LOKI', label: 'datasource', type: 'datasource', query: 'loki',
    current: { text: 'Loki', value: 'Loki' },
  },
  variable('host', journals),
  variable('source', host),
  variable('container', source),
  variable('unit', container),
  variable('level', unit),
  { name: 'search', label: 'search', type: 'textbox', current: { text: '', value: '' } },
])
+ g.dashboard.withPanels([
  g.panel.timeSeries.new('messages per second')
  + g.panel.timeSeries.queryOptions.withTargets([
    target('sum by (source) (rate(' + logs + '[$__auto]))')
    + g.query.loki.withLegendFormat('{{source}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('ops')
  + g.panel.timeSeries.gridPos.withX(0)
  + g.panel.timeSeries.gridPos.withY(0)
  + g.panel.timeSeries.gridPos.withW(24)
  + g.panel.timeSeries.gridPos.withH(6)
  + { id: 1 },

  g.panel.logs.new('logs')
  + g.panel.logs.queryOptions.withTargets([
    target(logs)
    + g.query.loki.withDirection('backward')
    + g.query.loki.withMaxLines(1000),
  ])
  + g.panel.logs.options.withShowTime()
  + g.panel.logs.options.withShowLabels()
  + g.panel.logs.options.withShowControls()
  + g.panel.logs.options.withShowLogContextToggle()
  + g.panel.logs.options.withWrapLogMessage()
  + g.panel.logs.options.withEnableLogDetails()
  + g.panel.logs.options.withPrettifyLogMessage()
  + g.panel.logs.options.withSortOrder('Descending')
  + g.panel.logs.gridPos.withX(0)
  + g.panel.logs.gridPos.withY(6)
  + g.panel.logs.gridPos.withW(24)
  + g.panel.logs.gridPos.withH(24)
  + { id: 2 },
], setPanelIDs=false)
