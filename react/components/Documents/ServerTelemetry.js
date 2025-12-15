import React from 'react'

/**
 * Server Telemetry - Server diagnostics and monitoring
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
    <div style={styles.container}>
      <h2 style={styles.heading}>Server Telemetry</h2>

      <section style={styles.section}>
        <h3 style={styles.subheading}>Apache Processes ({apache_count} total)</h3>
        <pre style={styles.pre}>{apache_processes || 'No Apache processes found'}</pre>
      </section>

      <section style={styles.section}>
        <h3 style={styles.subheading}>Memory Analysis (PSS/USS)</h3>
        <pre style={styles.pre}>{memory_analysis || 'No memory analysis available (smem not installed?)'}</pre>
      </section>

      <section style={styles.section}>
        <h3 style={styles.subheading}>VM Statistics</h3>
        <pre style={styles.pre}>{vmstat || 'No VM statistics available'}</pre>
      </section>

      <section style={styles.section}>
        <h3 style={styles.subheading}>System Uptime</h3>
        <pre style={styles.pre}>{uptime || 'No uptime information available'}</pre>
      </section>

      <section style={styles.section}>
        <h3 style={styles.subheading}>Cloud Health Check</h3>
        <pre style={styles.pre}>{health_check || 'No health check data available'}</pre>
      </section>

      <section style={styles.section}>
        <h3 style={styles.subheading}>Apache Configuration</h3>
        <pre style={styles.pre}>{apache_config || 'No Apache configuration available'}</pre>
      </section>
    </div>
  )
}

const styles = {
  container: {
    fontSize: '13px',
    lineHeight: '1.6',
    color: '#111'
  },
  heading: {
    fontSize: '18px',
    fontWeight: 'bold',
    color: '#38495e',
    marginBottom: '20px',
    borderBottom: '2px solid #38495e',
    paddingBottom: '8px'
  },
  section: {
    marginBottom: '25px'
  },
  subheading: {
    fontSize: '15px',
    fontWeight: 'bold',
    color: '#4060b0',
    marginBottom: '10px'
  },
  pre: {
    backgroundColor: '#f8f9f9',
    border: '1px solid #dee2e6',
    borderRadius: '4px',
    padding: '12px',
    fontSize: '12px',
    fontFamily: 'monospace',
    overflowX: 'auto',
    whiteSpace: 'pre-wrap',
    wordWrap: 'break-word',
    lineHeight: '1.4'
  }
}

export default ServerTelemetry
