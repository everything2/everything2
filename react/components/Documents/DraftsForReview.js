import React from 'react';
import { formatDateTime } from '../../utils/dateFormat';

/**
 * DraftsForReview - Editor drafts pending review
 * Styles in CSS: .drafts-for-review__*
 */
const DraftsForReview = ({ data }) => {
  const { drafts = [], is_editor = false, error, message } = data;

  // Handle errors
  if (error === 'guest') {
    return (
      <div className="drafts-for-review">
        <p>Only <a href="/?node=Sign+Up">logged-in users</a> can see drafts.</p>
      </div>
    );
  }

  if (error === 'config') {
    return (
      <div className="drafts-for-review">
        <p className="drafts-for-review__error">{message}</p>
      </div>
    );
  }

  // Format timestamp to readable date
  const formatDate = (timestamp) => formatDateTime(timestamp) ?? '';

  // Format latest note for tooltip
  const formatNote = (noteText) => {
    if (!noteText) return '';
    return noteText;
  };

  return (
    <div className="drafts-for-review">
      {drafts.length === 0 ? (
        <p>No drafts are currently awaiting review.</p>
      ) : (
        <table className="drafts-for-review__table">
          <thead>
            <tr>
              <th className="drafts-for-review__th">Draft</th>
              <th className="drafts-for-review__th drafts-for-review__th--date">For review since</th>
              {is_editor && (
                <th className="drafts-for-review__th drafts-for-review__th--notes">Notes</th>
              )}
            </tr>
          </thead>
          <tbody>
            {drafts.map((draft, index) => (
              <tr key={index} className={index % 2 === 0 ? 'drafts-for-review__row--even' : 'drafts-for-review__row--odd'}>
                <td className="drafts-for-review__td">
                  <a href={`/?node=${encodeURIComponent(draft.title)}`}>
                    {draft.title}
                  </a>
                  {' by '}
                  <a href={`/?node_id=${draft.author_id}`}>
                    {draft.author}
                  </a>
                </td>
                <td className="drafts-for-review__td drafts-for-review__td--date">
                  {formatDate(draft.publishtime)}
                </td>
                {is_editor && (
                  <td className="drafts-for-review__td drafts-for-review__td--notes">
                    {draft.notecount > 0 ? (
                      <a
                        href={`/?node=${encodeURIComponent(draft.title)}#nodenotes`}
                        title={`${draft.notecount} notes; latest: ${formatNote(draft.latestnote)}`}
                      >
                        {draft.notecount}
                      </a>
                    ) : (
                      <span>&nbsp;</span>
                    )}
                  </td>
                )}
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </div>
  );
};

export default DraftsForReview;
