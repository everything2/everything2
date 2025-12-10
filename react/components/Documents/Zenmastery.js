import React from 'react'

/**
 * Zenmastery - CSS demonstration page for styling staff features
 * Shows static HTML with staff-only classes and IDs for zen stylesheet testing
 * All forms are neutered, all links go to homepage (for demo purposes)
 */
const Zenmastery = () => {
  return (
    <div style={styles.container}>
      <h2>About this page</h2>

      <p>Welcome to Zenmastery, the demonstration node where you can view staff-only options to
      style them properly in your Zen Stylesheet.  The nodelets below are encased in a DIV
      called <tt>id="zenmastery_sidebar"</tt>.  This will allow you to tinker with a false sidebar
      DIV without interfering with the real sidebar on your layout.</p>

      <p>For your convenience, the HTML has been cleaned up a bit to make it easier to find the IDs and
      Classes you need to reference.  All forms are still intact but they are neutered, they can't
      actually set or change anything.  All links go to the homepage.  These are for demonstration
      purposes only.</p>

      <p>Also see <a href="/?node_id=124" style={styles.link}>The Nodelets</a> for a list of all the available nodelets
      that are not currently in your sidebar.</p>

      <h3>New Writeups</h3>

      <p>The staff-only options in <a href="/?node_id=1663" style={styles.link}>New Writeups</a> are:</p>
      <dl>
        <dt>R:-5</dt><dd>Signals that a writeup currently has a negative rep (Not given a class)</dd>
        <dt>(h?)</dt><dd>Link to "hide" a writeup from New Writeups. Class: 'hide'</dd>
        <dt>(H: un-h!)</dt><dd>Link to "unhide" a writeup from new Writeups. Class: 'hide'</dd>
        <dt>(X)</dt><dd>Marks writeups that have been nuked (Not given a class)</dd>
      </dl>
      <p>(The same controls are also present in the <a href="/?node_id=2075267" style={styles.link}>New Logs nodelet</a>.)</p>

      <h3>Master Control</h3>

      <p>Master Control is a staff-only nodelet.  Most of it is self-explanatory, but the Node Notes are
      a special section that allows staff members to add commentary to a node to coordinate their
      efforts so they don't accidentally work at cross-purposes to each other.  For example one editor
      might note "I'm working with the author to improve this writeup." so another editor doesn't
      nuke it.</p>

      <h3>Front Page News/weblogs</h3>

      <p>Staff may be shown who linked a writeup or other document to a weblog or to the front page news
      if that person is not the author of the document. Imaginatively enough, the information is in a div
      with class 'linkedby'. They also get a link allowing them to remove the document from the weblog, with
      class 'remove'.</p>

      <div id="zenmastery_sidebar" style={styles.sidebar}>

        {/* New Writeups Nodelet */}
        <div className='nodelet' id='newwriteups' style={styles.nodelet}>
          <h2 className="nodelet_title" style={styles.nodeletTitle}>New Writeups</h2>
          <div className='nodelet_content' style={styles.nodeletContent}>
            <form>
              <input type="hidden" />
              <input type='hidden' />
              <input type="hidden" />
              <select>
                <option value="1">1</option>
                <option value="5">5</option>
                <option value="10">10</option>
                <option value="15">15</option>
                <option value="20">20</option>
                <option value="25" defaultValue>25</option>
                <option value="30">30</option>
                <option value="40">40</option>
              </select>
              <input type="submit" value='show' />
              <label>
                <input type="checkbox" name="nw_nojunk" />
                No junk
              </label>
              <div>
                <input type="hidden" />
              </div>
            </form>

            <ul className="infolist" style={styles.infolist}>
              <li className="contentinfo">
                <a className="title" href="/">writeup1</a>
                <span className="type">(<a href="/">idea</a>)</span>
                <cite>by <a href="/" className="author">rootbeer277</a></cite>
                <span className="admin">
                  <span className="hide">(<a href="/">h?</a>)</span>
                </span>
              </li>
              <li className="contentinfo">
                <a className="title" href="/">writeup2</a>
                <span className="type">(<a href="/">fiction</a>)</span>
                <cite>by <a href="/" className="author">rootbeer277</a></cite>
                <span className="admin">
                  <span className="hide">(<a href="/">h?</a>)</span>
                </span>
              </li>
              <li className="contentinfo">
                <a className="title" href="/">writeup3</a>
                <span className="type">(<a href="/">person</a>)</span>
                <cite>by <a href="/" className="author">rootbeer277</a></cite>
                <span className="admin">
                  <span className="hide">(<a href="/">h?</a>)</span>
                </span>
              </li>
              <li className="contentinfo">
                <a className="title" href="/">writeup4</a>
                <span className="type">(<a href="/">log</a>)</span>
                <cite>by <a href="/" className="author">rootbeer277</a></cite>
                <span className="admin">
                  <span className="hide">(<a href="/">h?</a>)</span>
                </span>
              </li>
              <li className="contentinfo">
                <a className="title" href="/">writeup5</a>
                <span className="type">(<a href="/">person</a>)</span>
                <cite>by <a href="/" className="author">rootbeer277</a></cite>
                <span className="admin">
                  R:-1
                  <span className="hide">(<a href="/">h?</a>)</span>
                </span>
              </li>
              <li className="contentinfo">
                <a className="title" href="/">writeup6</a>
                <span className="type">(<a href="/">person</a>)</span>
                <cite>by <a href="/" className="author">rootbeer277</a></cite>
                <span className="admin">
                  R:-1
                  <span className="hide">(<a href="/">h?</a>)</span>
                </span>
              </li>
              <li className="contentinfo">
                <a className="title" href="/">writeup7</a>
                <span className="type">(<a href="/">idea</a>)</span>
                <cite>by <a href="/" className="author">rootbeer277</a></cite>
                <span className="admin">
                  R:-1
                  <span className="hide">(<a href="/">h?</a>)</span>
                </span>
              </li>
              <li className="contentinfo hasvoted">
                <a className="title" href="/">writeup8</a>
                <span className="type">(<a href="/">person</a>)</span>
                <cite>by <a href="/" className="author">rootbeer277</a></cite>
                <span className="admin">
                  <span className="hide">(<a href="/">h?</a>)</span>
                </span>
              </li>
              <li className="contentinfo wu_hide">
                <a className="title" href="/">writeup9</a>
                <span className="type">(<a href="/">person</a>)</span>
                <cite>by <a href="/" className="author">rootbeer277</a></cite>
                <span className="admin">
                  <span className="hide">(H: <a href="/">un-h!</a>)</span>
                  (X)
                </span>
              </li>
              <li className="contentinfo">
                <a className="title" href="/">writeup10</a>
                <span className="type">(<a href="/">review</a>)</span>
                <cite>by <a href="/" className="author">rootbeer277</a></cite>
                <span className="admin">
                  <span className="hide">(<a href="/">h?</a>)</span>
                </span>
              </li>
              <li className="contentinfo wu_hide">
                <a className="title" href="/">writeup11</a>
                <span className="type">(<a href="/">dream</a>)</span>
                <cite>by <a href="/" className="author">rootbeer277</a></cite>
                <span className="admin">
                  R:-1
                  <span className="hide">(H: <a href="/">un-h!</a>)</span>
                </span>
              </li>
              <li className="contentinfo">
                <a className="title" href="/">writeup12</a>
                <span className="type">(<a href="/">idea</a>)</span>
                <cite>by <a href="/" className="author">rootbeer277</a></cite>
                <span className="admin">
                  <span className="hide">(<a href="/">h?</a>)</span>
                </span>
              </li>
            </ul>

            <div className="nodeletfoot morelink">(<a href="/node/superdoc/Writeups+by+Type">more</a>)</div>

          </div>
        </div>

        {/* Master Control Nodelet */}
        <div className='nodelet' id='mastercontrol' style={styles.nodelet}>
          <h2 className="nodelet_title" style={styles.nodeletTitle}>Master Control</h2>
          <div className='nodelet_content' style={styles.nodeletContent}>

            <div className="nodelet_section">
              <h4 className="ns_title">Node Info</h4>
              <span className="rightmenu">
                <span className='var_label'>node_id:</span> <span className='var_value'>1986688</span><br />
                <span className='var_label'>nodetype:</span> <span className='var_value'><a href="/index.pl">superdocnolinks</a></span><br />
                <span className='var_label'>Server:</span> <span className='var_value'>web5</span>
                <p></p>

                <form>
                  <label htmlFor="node">Name:</label>
                  <input type="text" name="node" defaultValue="zenmastery" size="18" maxLength="80" id="node" />
                  <input type="submit" value="go" />
                </form>

                <form>
                  <label htmlFor="node_id">ID:</label>
                  <input type="text" name="node_id" defaultValue="1986688" size="12" maxLength="80" id="node_id" />
                  <input type="submit" value="go" />
                </form>

              </span>
            </div>

            <div className='nodelet_section'>
              <h4 className='ns_title'>Node Toolset</h4>
              <ul>
                <li><a href='/index.pl'>Clone Node</a></li>
                <li><a href='/index.pl'>Edit Code</a></li>
                <li><a href="/index.pl">Node XML</a></li>
                <li><a href="/index.pl">Document Node?</a></li>
                <li style={{listStyle: 'none'}}><br /></li>
                <li><a href='/index.pl'>Delete Node</a></li>
              </ul>
            </div>

            <div className="nodelet_section" id="nodenotes">
              <h4 className="ns_title">Node Notes <em>(0)</em></h4>
              <form>
                <input type="hidden" />
                <input type="hidden" />
                <p>
                  <input type="checkbox" />
                  2009-05-15 <a href="/index.pl" className='populated'>rootbeer277</a>: Test chamber for <a href="/index.pl" className='populated'>zenmasters</a> to style staff features
                </p>
                <p align="right">
                  <input type="hidden" />
                  <input type="hidden" />
                  <input type="hidden" />
                  <input type="text" name="notetext" maxLength="255" size="22" /><br />
                  <input type="submit" value="(un)note" />
                </p>
              </form>
            </div>

            <div id="episection_admins" className="nodeletsection">
              <div className="sectionheading">
                [<a style={{textDecoration: 'none'}} className="ajax" href="/" title="collapse"><tt> - </tt></a>]
                <strong>Admin</strong>
              </div>

              <div className="sectioncontent">
                <ul>
                  <li><a href='/index.pl'>Edit These E2 Titles</a></li>
                  <li><a href='/index.pl'>Admin HOWTO</a></li>
                </ul>
              </div>
            </div>

            <div id="episection_ces" className="nodeletsection">
              <div className="sectionheading">
                [<a style={{textDecoration: 'none'}} className="ajax" href="/" title="collapse"><tt> - </tt></a>]
                <strong>CE</strong>
              </div>
              <div className="sectioncontent">
                <ul>
                  <li><a href='/index.pl'>25</a> | <a href='/index.pl'>Everything New Nodes</a></li>
                  <li><a href='/index.pl'>E2 Nuke Request</a></li>
                  <li><a href='/index.pl'>Nodeshells</a></li>
                  <li><a href='/index.pl'>Node Row</a></li>
                  <li><a href='/index.pl'>Recent Node Notes</a></li>
                  <li><a href='/index.pl'>Your insured writeups</a></li>
                  <li><a href='/index.pl'>Make Unvotable</a></li>
                  <li><a href='/index.pl'>Blind Voting Booth</a></li>
                  <li><a href='/index.pl'>Group discussions</a></li>
                  <li><a href='/index.pl'>Editor Log: May 2009</a></li>
                  <li><a href='/index.pl'>The Oracle</a></li>
                </ul>
              </div>
            </div>

          </div>
        </div>

      </div>
      <br /><br /><br />

      {/* Front Page News/Weblog Demo */}
      <div className="weblog">
        <div className="item">
          <div className="contentinfo contentheader">
            <a href="/" className="title">Welcome to Zenmastery</a>
            <cite>by <a href="/" className="author">rootbeer277</a></cite>
            <span className="date">Wed May 27 2009 at 9:56:10</span>
            <div className="linkedby">linked by <a href="/">DonJaime</a></div>
            <a className="remove" href="/">remove</a>
          </div>
          <div className="content">
            <p>Content goes here.</p>
          </div>
        </div>
        <div className="item">
          <div className="contentinfo contentheader">
            <a href="/" className="title">Zenmastery now Updated!</a>
            <cite>by <a href="/" className="author">DonJaime</a></cite>
            <span className="date">Sun May 17 2009 at 4:00:50</span>
            <a className="remove" href="/">remove</a>
          </div>
          <div className="content">
            <p>Content goes here.</p>
          </div>
        </div>
      </div>
    </div>
  )
}

const styles = {
  container: {
    fontSize: '13px',
    lineHeight: '1.6',
    color: '#111'
  },
  link: {
    color: '#4060b0',
    textDecoration: 'none'
  },
  sidebar: {
    marginTop: '20px',
    marginBottom: '20px'
  },
  nodelet: {
    marginBottom: '15px',
    border: '1px solid #dee2e6',
    borderRadius: '4px',
    backgroundColor: '#f8f9f9'
  },
  nodeletTitle: {
    fontSize: '14px',
    fontWeight: 'bold',
    padding: '8px 12px',
    margin: 0,
    backgroundColor: '#38495e',
    color: '#fff',
    borderTopLeftRadius: '4px',
    borderTopRightRadius: '4px'
  },
  nodeletContent: {
    padding: '12px'
  },
  infolist: {
    listStyle: 'none',
    padding: 0,
    margin: '10px 0'
  }
}

export default Zenmastery
