import React from 'react'

/**
 * Server Telemetry - Server diagnostics and monitoring
 * Styles in CSS: .server-telemetry__*
 *
 * Displays real-time server information including:
 * - Cron subsystem health (leader + per-job state)
 * - Starman app-worker processes (the PSGI app server)
 * - Task memory analysis (cgroup-authoritative)
 * - Cloud health check results
 */
const ServerTelemetry = ({ data }) => {
  const {
    app_workers = '',
    worker_count = 0,
    apache_count = 0,
    health_check = '',
    memory_analysis = '',
    cron_status = ''
  } = data

  return (
    <div className="server-telemetry">
      <h2 className="server-telemetry__heading">Server Telemetry</h2>

      <section className="server-telemetry__section">
        <h3 className="server-telemetry__subheading">Cron Subsystem</h3>
        <pre className="server-telemetry__pre">{cron_status || 'No cron status available'}</pre>
      </section>

      <section className="server-telemetry__section">
        <h3 className="server-telemetry__subheading">App Workers ({worker_count} Starman · {apache_count} apache front)</h3>
        <pre className="server-telemetry__pre">{app_workers || 'No Starman workers found'}</pre>
      </section>

      <section className="server-telemetry__section">
        <h3 className="server-telemetry__subheading">Memory Analysis</h3>
        <pre className="server-telemetry__pre">{memory_analysis || 'No memory analysis available'}</pre>
      </section>

      <section className="server-telemetry__section">
        <h3 className="server-telemetry__subheading">Cloud Health Check</h3>
        <pre className="server-telemetry__pre">{health_check || 'No health check data available'}</pre>
      </section>
    </div>
  )
}

export default ServerTelemetry
