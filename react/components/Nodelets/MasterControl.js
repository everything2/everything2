import React from 'react'
import NodeletContainer from '../NodeletContainer'
import NodeletSection from '../NodeletSection'
import AdminSearchForm from '../MasterControl/AdminSearchForm'
import NodeToolset from '../MasterControl/NodeToolset'
import CESectionLinks from '../MasterControl/CESectionLinks'
import AdminSectionLinks from '../MasterControl/AdminSectionLinks'
import NodeNotes from '../MasterControl/NodeNotes'

const MasterControl = (props) => {
  if (!props.isEditor) {
    return (
      <NodeletContainer
        title="Master Control"
        showNodelet={props.showNodelet}
        nodeletIsOpen={props.nodeletIsOpen}
      >
        <p>Nothing for you here.</p>
      </NodeletContainer>
    )
  }

  return (
    <NodeletContainer
      title="Master Control"
      showNodelet={props.showNodelet}
      nodeletIsOpen={props.nodeletIsOpen}
    >
      {props.adminSearchForm && (
        <AdminSearchForm
          nodeId={props.adminSearchForm.nodeId}
          nodeType={props.adminSearchForm.nodeType}
          nodeTitle={props.adminSearchForm.nodeTitle}
          serverName={props.adminSearchForm.serverName}
          scriptName={props.adminSearchForm.scriptName}
          lastCommit={props.lastCommit}
        />
      )}

      {props.isAdmin && props.nodeToolsetData && (
        <NodeToolset
          nodeId={props.nodeToolsetData.nodeId}
          nodeTitle={props.nodeToolsetData.nodeTitle}
          nodeType={props.nodeToolsetData.nodeType}
          canDelete={props.nodeToolsetData.canDelete}
          currentDisplay={props.nodeToolsetData.currentDisplay}
          hasHelp={props.nodeToolsetData.hasHelp}
          isWriteup={props.nodeToolsetData.isWriteup}
          preventNuke={props.nodeToolsetData.preventNuke}
        />
      )}

      {props.nodeNotesData && (
        <NodeNotes
          nodeId={props.nodeNotesData.node_id}
          initialNotes={props.nodeNotesData.notes}
          currentUserId={props.currentUserId}
        />
      )}

      {props.isAdmin && props.adminSection && (
        <NodeletSection
          nodelet="epi"
          section="admins"
          title="Admin"
          display={props.epi_admins}
          toggleSection={props.toggleSection}
        >
          <AdminSectionLinks isBorged={props.adminSection.isBorged} />
        </NodeletSection>
      )}

      {props.ceSection && (
        <NodeletSection
          nodelet="epi"
          section="ces"
          title="CE"
          display={props.epi_ces}
          toggleSection={props.toggleSection}
        >
          <CESectionLinks
            currentMonth={props.ceSection.currentMonth}
            currentYear={props.ceSection.currentYear}
            isUserNode={props.ceSection.isUserNode}
            nodeId={props.ceSection.nodeId}
            nodeTitle={props.ceSection.nodeTitle}
          />
        </NodeletSection>
      )}
    </NodeletContainer>
  )
}

export default MasterControl
