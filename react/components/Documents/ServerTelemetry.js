import React from 'react'

/**
 * Server Telemetry - Server diagnostics and monitoring
 * Styles in CSS: .server-telemetry__*
 *
 * Displays real-time server information including:
 * - Apache process information
 * - VM statistics
 * - System uptime
 * - Health check results
 * - Apache configuration
 */
const ServerTelemetry = ({ data }) => {
  const {
    apache_processes = '',
    apache_count = 0,
    vmstat = '',
    uptime = '',
    health_check = '',
    apache_config = '',
    memory_analysis = ''
  } = data

  return (
    <div className="server-telemetry">
      <h2 className="server-telemetry__heading">Server Telemetry</h2>

      <section className="server-telemetry__section">
        <h3 className="server-telemetry__subheading">Apache Processes ({apache_count} total)</h3>
        <pre className="server-telemetry__pre">{apache_processes || 'No Apache processes found'}</pre>
      </section>

      <section className="server-telemetry__section">
        <h3 className="server-telemetry__subheading">Memory Analysis (PSS/USS)</h3>
        <pre className="server-telemetry__pre">{memory_analysis || 'No memory analysis available (smem not installed?)'}</pre>
      </section>

      <section className="server-telemetry__section">
        <h3 className="server-telemetry__subheading">VM Statistics</h3>
        <pre className="server-telemetry__pre">{vmstat || 'No VM statistics available'}</pre>
      </section>

      <section className="server-telemetry__section">
        <h3 className="server-telemetry__subheading">System Uptime</h3>
        <pre className="server-telemetry__pre">{uptime || 'No uptime information available'}</pre>
      </section>

      <section className="server-telemetry__section">
        <h3 className="server-telemetry__subheading">Cloud Health Check</h3>
        <pre className="server-telemetry__pre">{health_check || 'No health check data available'}</pre>
      </section>

      <section className="server-telemetry__section">
        <h3 className="server-telemetry__subheading">Apache Configuration</h3>
        <pre className="server-telemetry__pre">{apache_config || 'No Apache configuration available'}</pre>
      </section>
    </div>
  )
}

export default ServerTelemetry
