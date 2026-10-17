// Deploy independently from main.bicep. Only manages low-cost metric alert rules.
// Existing Log Analytics alert is disabled after these rules are verified.
targetScope = 'resourceGroup'

resource functionApp 'Microsoft.Web/sites@2023-12-01' existing = {
  name: 'func-github-webhook-bridge'
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: 'appi-github-webhook-bridge'
}

resource notifications 'Microsoft.Insights/actionGroups@2023-01-01' existing = {
  name: 'ag-github-webhook-bridge'
}

// A burst of HTTP 5xx signals an app/platform failure. Avoid single transient failures.
resource http5xx 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'metric-gwb-http-5xx-burst'
  location: 'global'
  properties: {
    description: 'GitHub webhook bridge: >=3 HTTP 5xx in 15m. Investigate failed webhook delivery and app/platform availability.'
    severity: 2
    enabled: true
    scopes: [functionApp.id]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    autoMitigate: true
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [{
        name: 'Http5xxBurst'
        criterionType: 'StaticThresholdCriterion'
        metricName: 'Http5xx'
        metricNamespace: 'Microsoft.Web/sites'
        operator: 'GreaterThanOrEqual'
        timeAggregation: 'Total'
        threshold: 3
      }]
    }
    actions: [{ actionGroupId: notifications.id }]
  }
}

// Repeated Application Insights exceptions; a single host gRPC SocketException
// has historically been noisy and should not generate a page.
resource exceptions 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'metric-gwb-exception-burst'
  location: 'global'
  properties: {
    description: 'GitHub webhook bridge: >=3 Application Insights exceptions in 15m. Single host gRPC exception is ignored.'
    severity: 2
    enabled: true
    scopes: [appInsights.id]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    autoMitigate: true
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [{
        name: 'ExceptionBurst'
        criterionType: 'StaticThresholdCriterion'
        metricName: 'exceptions/count'
        metricNamespace: 'Microsoft.Insights/components'
        operator: 'GreaterThanOrEqual'
        timeAggregation: 'Count'
        threshold: 3
      }]
    }
    actions: [{ actionGroupId: notifications.id }]
  }
}
