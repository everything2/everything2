import React, { useState, useEffect } from 'react';

// Display copy for each report driver, keyed on the driver id (#4511). The server ships only the
// driver id + backend-derived data (counts, resolved nodes); React owns the labels/descriptions.
const REPORT_LABELS = {
  editing_invalid_authors: {
    title: 'Invalid Authors on nodes',
    extended_title: 'These nodes do not have authors. Either the users were deleted or the records were damaged. Includes all types'
  },
  editing_null_node_titles: {
    title: 'Null titles on nodes',
    extended_title: 'These nodes have null or empty-string titles. Not necessarily writeups.'
  },
  editing_writeups_bad_types: {
    title: 'Writeup types that are invalid',
    extended_title: 'These are writeup types, such as (thing), (idea), (definition), etc that are not valid'
  },
  editing_writeups_broken_titles: {
    title: "Writeup titles that aren't the right pattern",
    extended_title: "These are writeup titles that don't have a left parenthesis in them, which means that it doesn't follow the 'parent_title (type)' pattern."
  },
  editing_writeups_invalid_parents: {
    title: "Writeups that don't have valid e2node parents",
    extended_title: 'These nodes need to be reparented'
  },
  editing_writeups_under_20_characters: {
    title: 'Writeups under 20 characters',
    extended_title: 'Writeups that are under 20 characters'
  },
  editing_writeups_without_formatting: {
    title: 'Writeups without any HTML tags',
    extended_title: "Writeups that don't have any HTML tags in them, limited to 200, ignores E1 writeups."
  },
  editing_writeups_linkless: {
    title: 'Writeups without links',
    extended_title: "Writeups post-2001 that don't have any links in them"
  },
  editing_e2nodes_with_duplicate_titles: {
    title: 'Writeups with titles that only differ by case',
    extended_title: 'Writeups that only differ by case'
  }
};
const LIST_DESCRIPTION = 'These jobs are run on a 24 hour basis and cached in the database. They show user-submitted content that is in need of repair.';

/**
 * ContentReports - Admin content validation reports.
 * Styles in CSS: .content-reports__*
 *
 * Fully client-resolved (#4511): the Page is a pure gate. This reads the `driver` selector off the
 * URL and fetches GET /api/content_reports (list) or /api/content_reports/:driver (detail), which
 * enforces the editor gate and returns backend-derived data only. Labels/descriptions are owned here.
 */
const ContentReports = () => {
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [denied, setDenied] = useState(false);

  useEffect(() => {
    const driverParam = new URLSearchParams(window.location.search).get('driver') || '';
    const url = driverParam
      ? `/api/content_reports/${encodeURIComponent(driverParam)}`
      : '/api/content_reports';

    let cancelled = false;
    (async () => {
      try {
        const res = await fetch(url, { credentials: 'same-origin' });
        const j = await res.json();
        if (cancelled) return;
        if (j.success) setData(j);
        else setDenied(true);
      } catch (err) {
        if (!cancelled) setDenied(true);
      } finally {
        if (!cancelled) setLoading(false);
      }
    })();

    return () => { cancelled = true; };
  }, []);

  if (loading) {
    return (
      <div className="content-reports">
        <p className="content-reports__description">Loading reports...</p>
      </div>
    );
  }

  if (denied || !data) {
    return (
      <div className="content-reports">
        <p className="content-reports__error">This tool is available to editors and administrators.</p>
      </div>
    );
  }

  const { view, reports, driver, nodes, error } = data;

  // List view - show all reports
  if (view === 'list') {
    return (
      <div className="content-reports">
        <p className="content-reports__description">{LIST_DESCRIPTION}</p>

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
                    {REPORT_LABELS[report.driver]?.title || report.driver}
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
          <p className="content-reports__error">Could not access driver: {driver}</p>
          <p>
            <a href="?node=Content+Reports">Back to Content Reports</a>
          </p>
        </div>
      );
    }

    return (
      <div className="content-reports">
        <h2 className="content-reports__heading">{REPORT_LABELS[driver]?.title || driver}</h2>
        <p className="content-reports__description">{REPORT_LABELS[driver]?.extended_title}</p>

        {nodes.length === 0 ? (
          <p>Driver <em>{driver}</em> has no failures</p>
        ) : (
          <ul className="content-reports__node-list">
            {nodes.map((node, index) => (
              <li key={node.node_id || index} className="content-reports__node-item">
                {node.error ? (
                  <span className="content-reports__error">Could not assemble node reference for id: {node.node_id}</span>
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
