import React from 'react'
import NodeletContainer from '../NodeletContainer'
import LinkNode from '../LinkNode'
import WriteupEntry from '../WriteupEntry'

const UsergroupWriteups = (props) => {
  const [selectedGroup, setSelectedGroup] = React.useState(
    props.usergroupData?.currentGroup?.title || 'E2science'
  )

  if (!props.usergroupData) {
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

  const { currentGroup, writeups, availableGroups, isRestricted, isEditor } = props.usergroupData

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

  const handleGroupChange = (e) => {
    setSelectedGroup(e.target.value)
  }

  return (
    <NodeletContainer id={props.id}
      title="Usergroup Writeups" showNodelet={props.showNodelet}
        nodeletIsOpen={props.nodeletIsOpen}>
      <p align="center" className="usergroup-writeups__header">
        <LinkNode nodeId={currentGroup.node_id} title={currentGroup.title} /> writeups
      </p>

      {writeups && writeups.length > 0 ? (
        <ul className="linklist usergroup-writeups__list">
          {writeups.map((writeup, index) => (
            <WriteupEntry
              key={index}
              entry={writeup}
              mode="simple"
              className=""
            />
          ))}
        </ul>
      ) : (
        <p className="usergroup-writeups__no-writeups">No writeups available</p>
      )}

      {availableGroups && availableGroups.length > 0 && (
        <form method="GET" className="usergroup-writeups__form">
          <input type="hidden" name="op" value="changeusergroup" />
          <select
            name="newusergroup"
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
          <input type="submit" name="sexisgood" value="show" className="usergroup-writeups__submit" />
        </form>
      )}
    </NodeletContainer>
  )
}

export default UsergroupWriteups
