import React from 'react'
import NodeletContainer from '../NodeletContainer'
import LinkNode from '../LinkNode'
import WriteupEntry from '../WriteupEntry'

const UsergroupWriteups = (props) => {
  // Hold the nodelet payload in state so a group switch can repaint in place
  // (see handleGroupChange) instead of reloading the whole page.
  const [data, setData] = React.useState(props.usergroupData)
  const [selectedGroup, setSelectedGroup] = React.useState(
    props.usergroupData?.currentGroup?.title || 'E2science'
  )

  // Re-sync if the parent hands down fresh server-rendered data.
  React.useEffect(() => {
    setData(props.usergroupData)
    if (props.usergroupData?.currentGroup?.title) {
      setSelectedGroup(props.usergroupData.currentGroup.title)
    }
  }, [props.usergroupData])

  if (!data) {
    return (
      <NodeletContainer
        id={props.id}
      title="Usergroup Writeups"
        showNodelet={props.showNodelet}
        nodeletIsOpen={props.nodeletIsOpen}
      >
        <p className="usergroup-writeups__empty">
          No usergroup data available
        </p>
      </NodeletContainer>
    )
  }

  const { currentGroup, writeups, availableGroups, isRestricted, isEditor } = data

  // Hide if restricted and user is not editor
  if (isRestricted && !isEditor) {
    return (
      <NodeletContainer
        id={props.id}
      title="Usergroup Writeups"
        showNodelet={props.showNodelet}
        nodeletIsOpen={props.nodeletIsOpen}
      >
        <p className="usergroup-writeups__empty">
          This usergroup is restricted
        </p>
      </NodeletContainer>
    )
  }

  // Switching groups: persist the choice as a user preference
  // (nodeletusergroup, for the next page load) and fetch that group's writeups
  // to repaint the nodelet in place. Both calls are independent — the content
  // endpoint takes the group id directly — so they run in parallel. Replaces
  // the legacy op=changeusergroup GET-form full-page reload (#4312).
  const handleGroupChange = (e) => {
    const newGroup = e.target.value
    setSelectedGroup(newGroup)

    const group = (availableGroups || []).find((g) => g.title === newGroup)

    // Persist the preference (fire-and-forget; the content fetch below is what
    // updates the visible nodelet).
    fetch('/api/preferences/set', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      credentials: 'include',
      body: JSON.stringify({ nodeletusergroup: newGroup })
    }).catch(() => {})

    if (!group) return

    fetch(`/api/usergroups/${group.node_id}/writeups`, { credentials: 'include' })
      .then((res) => (res.ok ? res.json() : null))
      .then((json) => {
        if (json && json.usergroupData) {
          setData(json.usergroupData)
        }
      })
      .catch(() => {})
  }

  return (
    <NodeletContainer id={props.id}
      title="Usergroup Writeups" showNodelet={props.showNodelet}
        nodeletIsOpen={props.nodeletIsOpen}>
      <p align="center" className="usergroup-writeups__header">
        <LinkNode nodeId={currentGroup.node_id} title={currentGroup.title} /> writeups
      </p>

      {writeups && writeups.length > 0 ? (
        <ul className="infolist usergroup-writeups__list">
          {writeups.map((writeup) => (
            <WriteupEntry
              key={`ugw_${writeup.node_id}`}
              entry={writeup}
              mode="full"
            />
          ))}
        </ul>
      ) : (
        <p className="usergroup-writeups__no-writeups">No writeups available</p>
      )}

      {availableGroups && availableGroups.length > 0 && (
        <div className="usergroup-writeups__form">
          <select
            name="newusergroup"
            aria-label="Show writeups from usergroup"
            value={selectedGroup}
            onChange={handleGroupChange}
            className="usergroup-writeups__select"
          >
            {availableGroups.map((group) => (
              <option key={group.node_id} value={group.title}>
                {group.title}
              </option>
            ))}
          </select>
        </div>
      )}
    </NodeletContainer>
  )
}

export default UsergroupWriteups
