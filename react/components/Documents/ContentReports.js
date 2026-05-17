import React from 'react';

/**
 * ContentReports - Admin content validation reports
 * Styles in CSS: .content-reports__*
 */
const ContentReports = ({ data }) => {
  const { view, description, reports, driver, driver_title, driver_description, nodes, error } = data;

  // List view - show all reports
  if (view === 'list') {
    return (
      <div className="content-reports">
        <p className="content-reports__description">{description}</p>

        <table className="content-reports__table">
          <thead>
            <tr>
              <th className="content-reports__th">Driver name</th>
              <th className="content-reports__th content-reports__th--center">Failure count</th>
            </tr>
          </thead>
          <tbody>
            {reports.map((report, index) => (
              <tr key={report.driver} className={index % 2 === 0 ? 'content-reports__row--even' : 'content-reports__row--odd'}>
                <td className="content-reports__td">
                  <a href={`?node=Content+Reports&driver=${encodeURIComponent(report.driver)}`}>
                    {report.title}
                  </a>
                </td>
                <td className="content-reports__td content-reports__td--center">
                  {report.count}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    );
  }

  // Driver view - show specific report details
  if (view === 'driver') {
    if (error) {
      return (
        <div className="content-reports">
          <p className="content-reports__error">{error}</p>
          <p>
            <a href="?node=Content+Reports">Back to Content Reports</a>
          </p>
        </div>
      );
    }

    return (
      <div className="content-reports">
        <h2 className="content-reports__heading">{driver_title}</h2>
        <p className="content-reports__description">{driver_description}</p>

        {nodes.length === 0 ? (
          <p>Driver <em>{driver}</em> has no failures</p>
        ) : (
          <ul className="content-reports__node-list">
            {nodes.map((node, index) => (
              <li key={node.node_id || index} className="content-reports__node-item">
                {node.error ? (
                  <span className="content-reports__error">{node.error} for id: {node.node_id}</span>
                ) : (
                  <a href={`/?node_id=${node.node_id}`}>
                    node_id: {node.node_id} title: {node.title} type: {node.type}
                  </a>
                )}
              </li>
            ))}
          </ul>
        )}

        <p>
          <a href="?node=Content+Reports">Back to Content Reports</a>
        </p>
      </div>
    );
  }

  return null;
};

export default ContentReports;
