# Monitoring

To monitor the status of the home lab, the automated provisioning and configuration
process deploy a monitoring agent on each home lab node, and a backend to collect
data coming from the monitoring agents.

## Import Grafana dashsboards

In its current state, Grafana doesn't support automatic import of dashboards that
a datasource ships, so you need to import those dashboards manually. To import
Grafana dashboards that ship with a datasource, do the following:

1. Open Grafana.
2. Open the datasource settings
3. Select a datasource.
4. Open the `Dashboards` panel.
5. Import the dashboards.
