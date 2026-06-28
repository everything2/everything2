import React from 'react';

/**
 * MacroFaq - Documentation for the /macro command system
 * Styles in CSS: .macro-faq__*
 *
 * Shows:
 * - How to use macros
 * - Variable substitution syntax
 * - FAQ section
 * - User's currently defined macros
 */
const MacroFaq = ({ data, user }) => {
  const {
    userMacros = [],
    contentEditorsId = 0,
    godsId = 0
  } = data;

  const isGuest = !!user?.guest;
  const isEditor = !!user?.editor;

  // Viewer's own username comes from the user prop (e2.user), deduped from
  // contentData per #4399. Guests have no username for the example.
  const username = isGuest ? '' : (user?.title || '');
  const usernameFormatted = username.replace(/ /g, '_');

  return (
    <div className="macro-faq">
      <h2 className="macro-faq__title">Macro FAQ</h2>

      {!isEditor && (
        <p className="macro-faq__notice">
          (Note: you are not allowed to use macros yet)
        </p>
      )}

      <p>
        Okay, okay, this isn't really a FAQ, more like a mini-lesson on how to
        use the <code>/macro</code> command. But isn't "macro FAQ" easier to
        remember than "macro mini-lesson-and-possibly-later-even-some-frequently-asked-questions"?
      </p>

      <h3 className="macro-faq__section-title">Use <code>/macro</code></h3>
      <p>
        A macro can be used in the chatterbox by typing:
        <br />
        <code>/macro</code> <var>macroname</var> [ <var>parameter1</var> [ <var>parameter2</var> [ ... ] ] ]
        <br />
        You first have to enable the macro(s) you wish to use, though, at{' '}
        <a href="/title/Admin%20Settings" className="macro-faq__link">Admin Settings</a>.
        For each macro you may want to use, check the appropriate box in the "Use?" column.
        If you don't want to use a macro any more, uncheck the box. If you desire,
        you can edit the macro to your liking.
      </p>

      <h3 className="macro-faq__section-title">Example</h3>
      <p>
        Here is an example of how to use the default "newbie" macro, which sends
        a private message to a user, telling them about{' '}
        <a href="/title/Everything%20University" className="macro-faq__link">Everything University</a> and{' '}
        <a href="/title/Everything%20FAQ" className="macro-faq__link">Everything FAQ</a>,
        and how to /msg you back.
      </p>
      <ol className="macro-faq__list">
        <li>Visit <a href="/title/Admin%20Settings" className="macro-faq__link">Admin Settings</a></li>
        <li>In the "Macros" section, find the "newbie" macro, and check that checkbox</li>
        <li>Press the "Submit" button</li>
        <li>
          In the chatterbox, type:{' '}
          <code>/macro newbie {usernameFormatted || 'your_username'} Duh, this is easy stuff!</code>
        </li>
        <li>Press the "Talk" button :)</li>
      </ol>
      <p>
        What you just did was send a basic E2-usage message to a newbie (in this case, you).
        In the default "newbie" macro setup, the messages are sent to the user specified
        in the first parameter (in this case, you). Anything you type afterwards are added
        to the first message.
      </p>

      <h3 className="macro-faq__section-title">Variable Substitution</h3>
      <p>
        Macros support the <code>/say</code> command, which treats everything after it
        as something you typed in the chatterbox. There are a few variables that you can use.
        Each variable must have a space on each side.
      </p>
      <ul className="macro-faq__list">
        <li>
          <code>$0</code> - Your username will be substituted (with underscores if your name has spaces)
        </li>
        <li>
          <code>$1</code>, <code>$2</code>, etc. - The first, second, etc. word you entered after the macro's name
        </li>
        <li>
          <code>$N+</code> - All words from position N onwards (e.g., <code>$3+</code> shows all words after the second)
        </li>
      </ul>

      <h3 className="macro-faq__section-title">Created Macros</h3>
      <p>
        This section will have some useful macros people have created.
        <br />
        <small>(If you have an idea for a useful macro, let the admins know!)</small>
      </p>

      <h3 className="macro-faq__section-title">Miscellaneous</h3>
      <p>
        <strong>Note:</strong> If you want to use a square bracket, [ and/or ] in the macro definition
        (in <a href="/title/Admin%20Settings" className="macro-faq__link">Admin Settings</a>),
        you'll have to type it as a curly brace, {'{'} and {'}'} instead.
        <br />
        <strong>Note:</strong> In most cases, the first parameter is the user you want to receive
        the macro text. If the user has a space in their name, change them into underscores.
      </p>

      <h3 className="macro-faq__section-title">FAQs</h3>
      <dl className="macro-faq__faq-list">
        <dt className="macro-faq__faq-question"><strong>Q:</strong> Who can use macros?</dt>
        <dd className="macro-faq__faq-answer">
          <strong>A:</strong> Currently, only{' '}
          {contentEditorsId > 0 ? (
            <a href={`/node/${contentEditorsId}`} className="macro-faq__link">Content Editors</a>
          ) : (
            'Content Editors'
          )}{' '}
          and{' '}
          {godsId > 0 ? (
            <a href={`/node/${godsId}`} className="macro-faq__link">gods</a>
          ) : (
            'gods'
          )}{' '}
          may use macros.
        </dd>

        <dt className="macro-faq__faq-question"><strong>Q:</strong> What happens if you call a macro recursively?</dt>
        <dd className="macro-faq__faq-answer">
          <strong>A:</strong> While it doesn't cause an infinite loop, it also doesn't seem
          to work as expected. So for now, don't. :-/
        </dd>
      </dl>

      <h3 className="macro-faq__section-title">Stored Macros</h3>
      <p>
        Here are all your currently defined macros. You can edit them at{' '}
        <a href="/title/Admin%20Settings" className="macro-faq__link">Admin Settings</a>.
      </p>

      {isGuest ? (
        <p className="macro-faq__notice">Log in to see your macros.</p>
      ) : userMacros.length === 0 ? (
        <p className="macro-faq__notice">You have no macros defined.</p>
      ) : (
        <table className="macro-faq__table">
          <thead>
            <tr>
              <th className="macro-faq__th">Name</th>
              <th className="macro-faq__th">Text</th>
            </tr>
          </thead>
          <tbody>
            {userMacros.map((macro, index) => (
              <tr key={index}>
                <td className="macro-faq__td-name">
                  <code>{macro.name}</code>
                </td>
                <td className="macro-faq__td-text">
                  <code className="macro-faq__macro-text">
                    {macro.text.split('\n').map((line, i) => (
                      <React.Fragment key={i}>
                        {line}
                        {i < macro.text.split('\n').length - 1 && <br />}
                      </React.Fragment>
                    ))}
                  </code>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}

      <p className="macro-faq__footer">
        If you have a question about macros, you can message an admin so this guide can be updated.
        You can also suggest ideas for better default macros.
      </p>
    </div>
  );
};

export default MacroFaq;
