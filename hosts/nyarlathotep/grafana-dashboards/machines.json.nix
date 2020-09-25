{ lib,  hostDetails, ... }:

with lib;

let
  summaryRowHeight = 7;
  detailRowHeight = 17;
  summaryRowPanels = 9;
  detailRowPanels = 5;

  gaugeJSON = { title, expr }: ''
      "datasource": "prometheus",
      "options": {
        "fieldOptions": {
          "calcs": [
            "last"
          ],
          "defaults": {
            "decimals": 1,
            "mappings": [],
            "max": 1,
            "min": 0,
            "thresholds": {
              "mode": "absolute",
              "steps": [
                {
                  "color": "green",
                  "value": null
                },
                {
                  "color": "orange",
                  "value": 0.75
                },
                {
                  "color": "red",
                  "value": 0.9
                }
              ]
            },
            "unit": "percentunit"
          },
          "overrides": [],
          "values": false
        },
        "orientation": "auto",
        "showThresholdLabels": false,
        "showThresholdMarkers": true
      },
      "pluginVersion": "6.7.4",
      "targets": [
        {
          "expr": "${expr}",
          "interval": "",
          "legendFormat": "",
          "refId": "A"
        }
      ],
      "timeFrom": null,
      "timeShift": null,
      "title": "${title}",
      "transparent": true,
      "type": "gauge"
'';

  singlestatJSON = { title, expr, format ? "none" }: ''
      "datasource": "prometheus",
      "decimals": 1,
      "format": "${format}",
      "pluginVersion": "6.7.4",
      "targets": [
        {
          "expr": "${expr}",
          "interval": "",
          "legendFormat": "",
          "refId": "A"
        }
      ],
      "title": "${title}",
      "type": "singlestat",
      "valueFontSize": "80%",
      "valueName": "current"
'';

  summaryRow = idx: { rowTitle, jobName, ... }:
    let rowID = idx * summaryRowPanels; rowY = idx * summaryRowHeight; in ''
    {
      "collapsed": false,
      "datasource": null,
      "gridPos": {
        "h": 1,
        "w": 24,
        "x": 0,
        "y": ${toString rowY}
      },
      "id": ${toString rowID},
      "title": "Summary: ${rowTitle}",
      "type": "row",
      "panels": []
    },
    {
      "gridPos": {
        "h": 6,
        "w": 4,
        "x": 0,
        "y": ${toString (1+rowY)}
      },
      "id": ${toString (1+rowID)},
      ${gaugeJSON { title = "CPU Busy"; expr = "sum(rate(node_cpu_seconds_total{job=\\\"${jobName}\\\",mode!=\\\"idle\\\"}[1m])) / count(count by (cpu) (node_cpu_seconds_total{job=\\\"${jobName}\\\"}))"; }}
    },
    {
      "gridPos": {
        "h": 6,
        "w": 4,
        "x": 4,
        "y": ${toString (1+rowY)}
      },
      "id": ${toString (2+rowID)},
      ${gaugeJSON { title = "Load (1m avg)"; expr = "avg(node_load1{job=\\\"${jobName}\\\"}) / count(count by (cpu) (node_cpu_seconds_total{job=\\\"${jobName}\\\"}))"; }}
    },
    {
      "gridPos": {
        "h": 6,
        "w": 4,
        "x": 8,
        "y": ${toString (1+rowY)}
      },
      "id": ${toString (3+rowID)},
      ${gaugeJSON { title = "Load (5m avg)"; expr = "avg(node_load5{job=\\\"${jobName}\\\"}) / count(count by (cpu) (node_cpu_seconds_total{job=\\\"${jobName}\\\"}))"; }}
    },
    {
      "gridPos": {
        "h": 6,
        "w": 4,
        "x": 12,
        "y": ${toString (1+rowY)}
      },
      "id": ${toString (4+rowID)},
      ${gaugeJSON { title = "Load (15m avg)"; expr = "avg(node_load15{job=\\\"${jobName}\\\"}) / count(count by (cpu) (node_cpu_seconds_total{job=\\\"${jobName}\\\"}))"; }}
    },
    {
      "gridPos": {
        "h": 6,
        "w": 4,
        "x": 16,
        "y": ${toString (1+rowY)}
      },
      "id": ${toString (5+rowID)},
      ${gaugeJSON { title = "RAM Used"; expr = "1 - (node_memory_MemAvailable_bytes{job=\\\"${jobName}\\\"} / node_memory_MemTotal_bytes{job=\\\"${jobName}\\\"})"; }}
    },
    {
      "gridPos": {
        "h": 3,
        "w": 4,
        "x": 20,
        "y": ${toString (1+rowY)}
      },
      "id": ${toString (6+rowID)},
      ${singlestatJSON { title = "Uptime"; format = "s"; expr = "node_time_seconds{job=\\\"${jobName}\\\"} - node_boot_time_seconds{job=\\\"${jobName}\\\"}"; }}
    },
    {
      "gridPos": {
        "h": 3,
        "w": 2,
        "x": 20,
        "y": ${toString (4+rowY)}
      },
      "id": ${toString (7+rowID)},
      ${singlestatJSON { title = "CPU Cores"; expr = "count(count by (cpu) (node_cpu_seconds_total{job=\\\"${jobName}\\\"}))"; }}
    },
    {
      "gridPos": {
        "h": 3,
        "w": 2,
        "x": 22,
        "y": ${toString (4+rowY)}
      },
      "id": ${toString (8+rowID)},
      ${singlestatJSON { title = "RAM Total"; format = "bytes"; expr = "node_memory_MemTotal_bytes{job=\\\"${jobName}\\\"}"; }}
    }
'';

  graphJSON = { title, stack ? "false", yFormat ? "percentunit", yMax ? "\"1\"", yMin ? "\"0\"" }: ''
      "aliasColors": {},
      "bars": false,
      "cacheTimeout": null,
      "dashLength": 10,
      "dashes": false,
      "datasource": "prometheus",
      "fill": 1,
      "fillGradient": 0,
      "hiddenSeries": false,
      "legend": {
        "alignAsTable": true,
        "avg": true,
        "current": true,
        "max": true,
        "min": true,
        "rightSide": true,
        "show": true,
        "total": false,
        "values": true
      },
      "lines": true,
      "linewidth": 1,
      "links": [],
      "nullPointMode": "null",
      "options": {
        "dataLinks": []
      },
      "percentage": false,
      "pluginVersion": "6.7.4",
      "pointradius": 2,
      "points": false,
      "renderer": "flot",
      "seriesOverrides": [],
      "spaceLength": 10,
      "stack": ${stack},
      "steppedLine": false,
      "thresholds": [],
      "timeFrom": null,
      "timeRegions": [],
      "timeShift": null,
      "title": "${title}",
      "tooltip": {
        "shared": true,
        "sort": 0,
        "value_type": "individual"
      },
      "transparent": true,
      "type": "graph",
      "xaxis": {
        "buckets": null,
        "mode": "time",
        "name": null,
        "show": true,
        "values": []
      },
      "yaxes": [
        {
          "format": "${yFormat}",
          "label": null,
          "logBase": 1,
          "max": ${yMax},
          "min": ${yMin},
          "show": true
        },
        {
          "format": "short",
          "label": null,
          "logBase": 1,
          "max": null,
          "min": null,
          "show": true
        }
      ],
      "yaxis": {
        "align": false,
        "alignLevel": null
      },
  '';

  detailRow = idx: { rowTitle, jobName, iface, mountpoints, ... }:
    let rowID = (length hostDetails) * summaryRowPanels + idx * detailRowPanels; rowY = (length hostDetails) * summaryRowHeight + idx * detailRowHeight; in ''
    {
      "collapsed": true,
      "datasource": null,
      "gridPos": {
        "h": 1,
        "w": 24,
        "x": 0,
        "y": ${toString rowY}
      },
      "id": ${toString rowID},
      "title": "Details: ${rowTitle}",
      "type": "row",
      "panels": [
        {
          "gridPos": {
            "h": 8,
            "w": 12,
            "x": 0,
            "y": ${toString (1+rowY)}
          },
          "id": ${toString (1+rowID)},
          ${graphJSON { title = "CPU"; }}
          "targets": [
            {
              "expr": "sum(rate(node_cpu_seconds_total{job=\"${jobName}\",mode!=\"idle\"}[1m])) by (cpu)",
              "instant": false,
              "interval": "",
              "legendFormat": "core {{cpu}}",
              "refId": "A"
            }
          ]
        },
        {
          "gridPos": {
            "h": 8,
            "w": 12,
            "x": 12,
            "y": ${toString (1+rowY)}
          },
          "id": ${toString (2+rowID)},
          ${graphJSON { title = "Memory"; stack = "true"; }}
          "targets": [
            {
              "expr": "node_memory_Buffers_bytes{job=\"${jobName}\"} / node_memory_MemTotal_bytes{job=\"${jobName}\"}",
              "instant": false,
              "interval": "",
              "legendFormat": "buffered",
              "refId": "A"
            },
            {
              "expr": "node_memory_Cached_bytes{job=\"${jobName}\"} / node_memory_MemTotal_bytes{job=\"${jobName}\"}",
              "instant": false,
              "interval": "",
              "legendFormat": "cached",
              "refId": "B"
            },
            {
              "expr": "(node_memory_MemTotal_bytes{job=\"${jobName}\"} - node_memory_MemFree_bytes{job=\"${jobName}\"} - node_memory_Buffers_bytes{job=\"${jobName}\"} - node_memory_Cached_bytes{job=\"${jobName}\"}) / node_memory_MemTotal_bytes{job=\"${jobName}\"}",
              "instant": false,
              "interval": "",
              "legendFormat": "used",
              "refId": "C"
            }
          ]
        },
        {
          "gridPos": {
            "h": 8,
            "w": 12,
            "x": 0,
            "y": ${toString (9+rowY)}
          },
          "id": ${toString (3+rowID)},
          ${graphJSON { title = "Network"; yFormat = "Bps"; yMax = "null"; yMin = "null"; }}
          "targets": [
            {
              "expr": "rate(node_network_transmit_bytes_total{job=\"${jobName}\",device=\"${iface}\"}[1m])",
              "interval": "",
              "legendFormat": "upload",
              "refId": "B"
            },
            {
              "expr": "rate(node_network_receive_bytes_total{job=\"${jobName}\",device=\"${iface}\"}[1m])",
              "instant": false,
              "interval": "",
              "legendFormat": "download",
              "refId": "A"
            },
            {
              "expr": "rate(node_network_transmit_bytes_total{job=\"${jobName}\",device=\"lo\"}[1m])",
              "interval": "",
              "legendFormat": "loopback",
              "refId": "C"
            }
          ]
        },
        {
          "gridPos": {
            "h": 8,
            "w": 12,
            "x": 12,
            "y": ${toString (9+rowY)}
          },
          "id": ${toString (4+rowID)},
          ${graphJSON { title = "Disk"; }}
          "targets": [
            {
              "expr": "1 - (node_filesystem_avail_bytes{job=\"${jobName}\",mountpoint=~\"${concatStringsSep "|" mountpoints}\"} / node_filesystem_size_bytes{job=\"${jobName}\",mountpoint=~\"${concatStringsSep "|" mountpoints}\"})",
              "instant": false,
              "interval": "",
              "legendFormat": "{{mountpoint}}",
              "refId": "A"
            }
          ]
        }
      ]
    }
'';

  summaryRows = concatStringsSep "," (imap0 (i: d: summaryRow i d) hostDetails);
  detailRows = concatStringsSep "," (imap0 (i: d: detailRow i d) hostDetails);

in ''
{
  "annotations": {
    "list": [
      {
        "builtIn": 1,
        "datasource": "-- Grafana --",
        "enable": true,
        "hide": true,
        "iconColor": "rgba(0, 211, 255, 1)",
        "name": "Annotations & Alerts",
        "type": "dashboard"
      }
    ]
  },
  "editable": true,
  "gnetId": null,
  "graphTooltip": 0,
  "id": 1,
  "links": [],
  "panels": [
    ${summaryRows},
    ${detailRows}
  ],
  "refresh": "10s",
  "schemaVersion": 22,
  "style": "dark",
  "tags": [],
  "templating": {
    "list": []
  },
  "time": {
    "from": "now-6h",
    "to": "now"
  },
  "timepicker": {
    "refresh_intervals": [
      "5s",
      "10s",
      "30s",
      "1m",
      "5m",
      "15m",
      "30m",
      "1h",
      "2h",
      "1d"
    ]
  },
  "timezone": "",
  "title": "Machines",
  "uid": "4nQ1MVFGz",
  "variables": {
    "list": []
  },
  "version": 1
}
''
