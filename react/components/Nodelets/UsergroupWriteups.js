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
        <p style={{ padding: '8px', fontSize: '12px', fontStyle: 'italic' }}>
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
        <p style={{ padding: '8px', fontSize: '12px', fontStyle: 'italic' }}>
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
      <p align="center" style={{ margin: '8px 0', fontSize: '12px' }}>
        <LinkNode nodeId={currentGroup.node_id} title={currentGroup.title} /> writeups
      </p>

      {writeups && writeups.length > 0 ? (
        <ul className="linklist" style={{ listStyle: 'none', paddingLeft: '8px', margin: '4px 0', fontSize: '12px' }}>
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
        <p style={{ padding: '8px', fontSize: '12px', fontStyle: 'italic' }}>No writeups available</p>
      )}

      {availableGroups && availableGroups.length > 0 && (
        <form method="GET" style={{ padding: '8px', marginTop: '8px' }}>
          <input type="hidden" name="op" value="changeusergroup" />
          <select
            name="newusergroup"
            value={selectedGroup}
            onChange={handleGroupChange}
            style={{ fontSize: '12px', width: '100%', marginBottom: '4px' }}
          >
            {availableGroups.map((group) => (
              <option key={group.node_id} value={group.title}>
                {group.title}
              </option>
            ))}
          </select>
          <input type="submit" name="sexisgood" value="show" style={{ fontSize: '11px' }} />
        </form>
      )}
    </NodeletContainer>
  )
}

export default UsergroupWriteups
