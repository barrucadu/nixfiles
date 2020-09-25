{ jobName }:

let
  singlestatJSON = { title, colour, expr, format ? "none" }: ''
      "colorBackground": true,
      "colors": [
        "${colour}",
        "${colour}",
        "${colour}"
      ],
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
      "thresholds": "1,1",
      "title": "${title}",
      "transparent": true,
      "type": "singlestat",
      "valueFontSize": "80%",
      "valueName": "current"
'';

  tableJSON = { title, metricAlias, currentAlias }: ''
      "columns": [
        {
          "text": "Current",
          "value": "current"
        }
      ],
      "datasource": "prometheus",
      "pageSize": 14,
      "showHeader": true,
      "sort": {
        "col": 1,
        "desc": true
      },
      "styles": [
        {
          "alias": "${metricAlias}",
          "align": "right",
          "mappingType": 1,
          "pattern": "Metric",
          "thresholds": [],
          "type": "string"
        },
        {
          "alias": "${currentAlias}",
          "align": "left",
          "decimals": 0,
          "mappingType": 1,
          "pattern": "Current",
          "thresholds": [],
          "type": "number",
          "unit": "none"
        }
      ],
      "title": "${title}",
      "transform": "timeseries_aggregations",
      "transparent": true,
      "type": "table"
'';

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
  "id": null,
  "links": [],
  "panels": [
    {
      "collapsed": false,
      "datasource": null,
      "gridPos": {
        "h": 1,
        "w": 24,
        "x": 0,
        "y": 0
      },
      "id": 2,
      "panels": [],
      "title": "DNS",
      "type": "row"
    },
    {
      "gridPos": {
        "h": 3,
        "w": 4,
        "x": 0,
        "y": 1
      },
      "id": 4,
      "mappingType": 1,
      "mappingTypes": [
        {
          "name": "value to text",
          "value": 1
        }
      ],
      "valueMaps": [
        {
          "op": "=",
          "text": "Disabled",
          "value": "0"
        },
        {
          "op": "=",
          "text": "Enabled",
          "value": "1"
        }
      ],
      ${singlestatJSON { title = "Status"; colour = "#299c46"; expr = "pihole_status{job=\\\"${jobName}\\\"}"; }}
    },
    {
      "gridPos": {
        "h": 3,
        "w": 4,
        "x": 4,
        "y": 1
      },
      "id": 5,
      ${singlestatJSON { title = "Domains on blocklist"; colour = "#d44a3a"; expr = "pihole_domains_being_blocked{job=\\\"${jobName}\\\"}"; }}
    },
    {
      "gridPos": {
        "h": 15,
        "w": 5,
        "x": 9,
        "y": 1
      },
      "id": 11,
      "targets": [
        {
          "expr": "pihole_top_queries{job=\"${jobName}\"}",
          "interval": "",
          "legendFormat": "{{domain}}",
          "refId": "A"
        }
      ],
      ${tableJSON { title = "Top permitted domains"; metricAlias = "Domain"; currentAlias = "Hits"; }}
    },
    {
      "gridPos": {
        "h": 15,
        "w": 5,
        "x": 14,
        "y": 1
      },
      "id": 12,
      "targets": [
        {
          "expr": "pihole_top_ads{job=\"${jobName}\"}",
          "interval": "",
          "legendFormat": "{{domain}}",
          "refId": "A"
        }
      ],
      ${tableJSON { title = "Top blocked domains"; metricAlias = "Domain"; currentAlias = "Hits"; }}
    },
    {
      "gridPos": {
        "h": 15,
        "w": 5,
        "x": 19,
        "y": 1
      },
      "id": 10,
      "targets": [
        {
          "expr": "pihole_top_sources{job=\"${jobName}\"}",
          "interval": "",
          "legendFormat": "{{source}}",
          "refId": "A"
        }
      ],
      ${tableJSON { title = "Top query sources"; metricAlias = "Source"; currentAlias = "Requests"; }}
    },
    {
      "gridPos": {
        "h": 3,
        "w": 3,
        "x": 0,
        "y": 4
      },
      "id": 14,
      ${singlestatJSON { title = "Total queries today"; colour = "#299c46"; expr = "pihole_dns_queries_all_types{job=\\\"${jobName}\\\"}"; }}
    },
    {
      "gridPos": {
        "h": 3,
        "w": 2,
        "x": 3,
        "y": 4
      },
      "id": 6,
      ${singlestatJSON { title = "Unique domains today"; colour = "#8F3BB8"; expr = "pihole_unique_domains{job=\\\"${jobName}\\\"}"; }}
    },
    {
      "gridPos": {
        "h": 3,
        "w": 3,
        "x": 5,
        "y": 4
      },
      "id": 13,
      ${singlestatJSON { title = "Queries blocked today"; colour = "#d44a3a"; format = "percent"; expr = "pihole_ads_percentage_today{job=\\\"${jobName}\\\"}"; }}
    },
    {
      "datasource": "prometheus",
      "gridPos": {
        "h": 9,
        "w": 9,
        "x": 0,
        "y": 7
      },
      "id": 17,
      "options": {
        "displayMode": "lcd",
        "fieldOptions": {
          "calcs": [
            "last"
          ],
          "defaults": {
            "mappings": [],
            "thresholds": {
              "mode": "absolute",
              "steps": [
                {
                  "color": "green",
                  "value": null
                }
              ]
            },
            "unit": "percent"
          },
          "overrides": [],
          "values": false
        },
        "orientation": "horizontal",
        "showUnfilled": true
      },
      "pluginVersion": "6.7.4",
      "targets": [
        {
          "expr": "pihole_forward_destinations{job=\"${jobName}\"}",
          "format": "time_series",
          "instant": false,
          "interval": "",
          "intervalFactor": 1,
          "legendFormat": "{{destination}}",
          "refId": "A"
        }
      ],
      "timeFrom": null,
      "timeShift": null,
      "title": "Queries answered by",
      "transparent": true,
      "type": "bargauge"
    }
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
  "title": "Network",
  "uid": "HUjzsIFGk",
  "variables": {
    "list": []
  },
  "version": 0
}
''
