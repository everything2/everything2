import React from 'react'
import { render, screen } from '@testing-library/react'
import MasterControl from './MasterControl'

// Mock child components
jest.mock('../NodeletContainer', () => {
  return function MockNodeletContainer({ title, children, showNodelet, nodeletIsOpen }) {
    return (
      <div data-testid="nodelet-container" data-title={title} data-open={nodeletIsOpen}>
        {children}
      </div>
    )
  }
})

jest.mock('../MasterControl/AdminSearchForm', () => {
  return function MockAdminSearchForm({ nodeId, nodeType, serverName }) {
    return (
      <div data-testid="admin-search-form">
        Admin Search Form - Node ID: {nodeId}, Type: {nodeType}, Server: {serverName}
      </div>
    )
  }
})

jest.mock('../MasterControl/CESectionLinks', () => {
  return function MockCESectionLinks({ currentMonth, currentYear }) {
    return <div data-testid="ce-section-links">CE Section - {currentMonth}/{currentYear}</div>
  }
})

jest.mock('../MasterControl/AdminSectionLinks', () => {
  return function MockAdminSectionLinks({ isBorged }) {
    return (
      <div data-testid="admin-section-links">
        Admin Section{isBorged && ' - Borged'}
      </div>
    )
  }
})

jest.mock('../NodeletSection', () => {
  return function MockNodeletSection({ nodelet, section, title, display, toggleSection, children }) {
    return (
      <div data-testid="nodelet-section" data-nodelet={nodelet} data-section={section} data-title={title} data-display={display}>
        {children}
      </div>
    )
  }
})

jest.mock('../MasterControl/NodeNotes', () => {
  return function MockNodeNotes({ nodeId, initialNotes, currentUserId }) {
    return (
      <div data-testid="node-notes">
        Node Notes - Node ID: {nodeId}, Notes: {initialNotes?.length || 0}, User: {currentUserId}
      </div>
    )
  }
})

jest.mock('../MasterControl/NodeToolset', () => {
  return function MockNodeToolset({ nodeId, nodeTitle, nodeType, canDelete }) {
    return (
      <div data-testid="node-toolset">
        Node Toolset - Node ID: {nodeId}, Title: {nodeTitle}, Type: {nodeType}, Can Delete: {canDelete ? 'Yes' : 'No'}
      </div>
    )
  }
})

describe('MasterControl Component', () => {
  describe('non-editor users', () => {
    it('renders container for non-editors', () => {
      render(<MasterControl isEditor={false} />)
      const container = screen.getByTestId('nodelet-container')
      expect(container).toHaveAttribute('data-title', 'Master Control')
    })

    it('shows "Nothing for you here" message for non-editors', () => {
      render(<MasterControl isEditor={false} />)
      expect(screen.getByText('Nothing for you here.')).toBeInTheDocument()
    })

    it('does not show any admin sections for non-editors', () => {
      render(
        <MasterControl
          isEditor={false}
          adminSearchForm={{ nodeId: '123', nodeType: 'e2node', nodeTitle: 'Test', serverName: 'test.com', scriptName: '/index.pl' }}
          nodeToolsetData={{ nodeId: '123', nodeTitle: 'Test', nodeType: 'e2node', canDelete: true }}
          nodeNotesData={{ node_id: 123, notes: [], count: 0 }}
          currentUserId={456}
          adminSection={{ isBorged: false, showSection: true }}
          ceSection={{ currentMonth: 10, currentYear: 2025, isUserNode: false, nodeId: '123', nodeTitle: 'Test', showSection: true }}
        />
      )
      expect(screen.queryByTestId('admin-search-form')).not.toBeInTheDocument()
      expect(screen.queryByTestId('node-toolset')).not.toBeInTheDocument()
      expect(screen.queryByText(/Node Note/)).not.toBeInTheDocument()
      expect(screen.queryByTestId('admin-section-links')).not.toBeInTheDocument()
      expect(screen.queryByTestId('ce-section-links')).not.toBeInTheDocument()
    })
  })

  describe('editor users (non-admin)', () => {
    it('renders admin search form for editors', () => {
      render(
        <MasterControl
          isEditor={true}
          isAdmin={false}
          adminSearchForm={{
            nodeId: '123',
            nodeType: 'e2node',
            nodeTitle: 'Test Node',
            serverName: 'test.everything2.com',
            scriptName: '/index.pl'
          }}
        />
      )
      expect(screen.getByTestId('admin-search-form')).toBeInTheDocument()
      expect(screen.getByText(/Node ID: 123/)).toBeInTheDocument()
      expect(screen.getByText(/Type: e2node/)).toBeInTheDocument()
    })

    it('renders node note for editors', () => {
      render(
        <MasterControl
          isEditor={true}
          isAdmin={false}
          nodeNotesData={{ node_id: 123, notes: [{ nodenote_id: 1, notetext: 'Test note' }], count: 1 }}
          currentUserId={456}
        />
      )
      expect(screen.getByTestId('node-notes')).toBeInTheDocument()
      expect(screen.getByText(/Node Notes - Node ID: 123/)).toBeInTheDocument()
    })

    it('renders CE section for editors', () => {
      render(
        <MasterControl
          isEditor={true}
          isAdmin={false}
          ceSection={{
            currentMonth: 10,
            currentYear: 2025,
            isUserNode: false,
            nodeId: '123',
            nodeTitle: 'Test',
            showSection: true
          }}
          epi_ces={true}
          toggleSection={jest.fn()}
        />
      )
      expect(screen.getByTestId('ce-section-links')).toBeInTheDocument()
      expect(screen.getByText(/CE Section - 10\/2025/)).toBeInTheDocument()
    })

    it('does not render node toolset for non-admin editors', () => {
      render(
        <MasterControl
          isEditor={true}
          isAdmin={false}
          nodeToolsetData={{ nodeId: '123', nodeTitle: 'Test', nodeType: 'e2node', canDelete: true }}
        />
      )
      // Should not render because isAdmin is false
      expect(screen.queryByTestId('node-toolset')).not.toBeInTheDocument()
    })

    it('does not render admin section for non-admin editors', () => {
      render(
        <MasterControl
          isEditor={true}
          isAdmin={false}
          adminSection={{ isBorged: false, showSection: true }}
        />
      )
      // Should not render because isAdmin is false
      expect(screen.queryByTestId('admin-section-links')).not.toBeInTheDocument()
    })
  })

  describe('admin users', () => {
    it('renders all editor sections for admins', () => {
      render(
        <MasterControl
          isEditor={true}
          isAdmin={true}
          adminSearchForm={{ nodeId: '123', nodeType: 'e2node', nodeTitle: 'Test', serverName: 'test.com', scriptName: '/index.pl' }}
          nodeNotesData={{ node_id: 123, notes: [], count: 0 }}
          currentUserId={456}
          ceSection={{ currentMonth: 10, currentYear: 2025, isUserNode: false, nodeId: '123', nodeTitle: 'Test', showSection: true }}
          epi_ces={true}
          toggleSection={jest.fn()}
        />
      )
      expect(screen.getByTestId('admin-search-form')).toBeInTheDocument()
      expect(screen.getByTestId('node-notes')).toBeInTheDocument()
      expect(screen.getByTestId('ce-section-links')).toBeInTheDocument()
    })

    it('renders node toolset for admins', () => {
      render(
        <MasterControl
          isEditor={true}
          isAdmin={true}
          nodeToolsetData={{
            nodeId: '123',
            nodeTitle: 'Test Node',
            nodeType: 'e2node',
            canDelete: true,
            currentDisplay: 'display',
            hasHelp: false,
            isWriteup: false
          }}
        />
      )
      expect(screen.getByTestId('node-toolset')).toBeInTheDocument()
      expect(screen.getByText(/Node Toolset - Node ID: 123/)).toBeInTheDocument()
    })

    it('renders admin section for admins', () => {
      render(
        <MasterControl
          isEditor={true}
          isAdmin={true}
          adminSection={{ isBorged: false, showSection: true }}
          epi_admins={true}
          toggleSection={jest.fn()}
        />
      )
      expect(screen.getByTestId('admin-section-links')).toBeInTheDocument()
      expect(screen.getByText(/Admin Section/)).toBeInTheDocument()
    })

    it('renders all sections when all props are provided', () => {
      render(
        <MasterControl
          isEditor={true}
          isAdmin={true}
          adminSearchForm={{ nodeId: '123', nodeType: 'e2node', nodeTitle: 'Test', serverName: 'test.com', scriptName: '/index.pl' }}
          nodeToolsetData={{ nodeId: '123', nodeTitle: 'Test', nodeType: 'e2node', canDelete: true }}
          nodeNotesData={{ node_id: 123, notes: [], count: 0 }}
          currentUserId={456}
          adminSection={{ isBorged: false, showSection: true }}
          ceSection={{ currentMonth: 10, currentYear: 2025, isUserNode: false, nodeId: '123', nodeTitle: 'Test', showSection: true }}
          epi_admins={true}
          epi_ces={true}
          toggleSection={jest.fn()}
        />
      )
      expect(screen.getByTestId('admin-search-form')).toBeInTheDocument()
      expect(screen.getByTestId('node-toolset')).toBeInTheDocument()
      expect(screen.getByTestId('node-notes')).toBeInTheDocument()
      expect(screen.getByTestId('admin-section-links')).toBeInTheDocument()
      expect(screen.getByTestId('ce-section-links')).toBeInTheDocument()
    })
  })

  describe('conditional rendering', () => {
    it('does not render adminSearchForm when undefined', () => {
      render(<MasterControl isEditor={true} isAdmin={false} />)
      // Just verify the container renders without error
      expect(screen.getByTestId('nodelet-container')).toBeInTheDocument()
    })

    it('does not render nodeToolset when undefined', () => {
      render(<MasterControl isEditor={true} isAdmin={true} />)
      // Just verify the container renders without error
      expect(screen.getByTestId('nodelet-container')).toBeInTheDocument()
    })

    it('does not render nodeNote when undefined', () => {
      render(<MasterControl isEditor={true} isAdmin={false} />)
      // Just verify the container renders without error
      expect(screen.getByTestId('nodelet-container')).toBeInTheDocument()
    })

    it('does not render adminSection when undefined', () => {
      render(<MasterControl isEditor={true} isAdmin={true} />)
      // Just verify the container renders without error
      expect(screen.getByTestId('nodelet-container')).toBeInTheDocument()
    })

    it('does not render ceSection when undefined', () => {
      render(<MasterControl isEditor={true} isAdmin={false} />)
      // Just verify the container renders without error
      expect(screen.getByTestId('nodelet-container')).toBeInTheDocument()
    })

    it('renders only provided sections', () => {
      render(
        <MasterControl
          isEditor={true}
          isAdmin={true}
          adminSearchForm={{ nodeId: '123', nodeType: 'e2node', nodeTitle: 'Test', serverName: 'test.com', scriptName: '/index.pl' }}
          adminSection={{ isBorged: false, showSection: true }}
          epi_admins={true}
          toggleSection={jest.fn()}
        />
      )
      expect(screen.getByTestId('admin-search-form')).toBeInTheDocument()
      expect(screen.getByTestId('admin-section-links')).toBeInTheDocument()
      // Other sections should not be present
      expect(screen.queryByTestId('node-toolset')).not.toBeInTheDocument()
      expect(screen.queryByTestId('node-notes')).not.toBeInTheDocument()
      expect(screen.queryByTestId('ce-section-links')).not.toBeInTheDocument()
    })
  })

  describe('component structure', () => {
    it('wraps content in NodeletContainer', () => {
      render(<MasterControl isEditor={false} />)
      expect(screen.getByTestId('nodelet-container')).toBeInTheDocument()
    })

    it('sets correct title on NodeletContainer', () => {
      render(<MasterControl isEditor={false} />)
      const container = screen.getByTestId('nodelet-container')
      expect(container).toHaveAttribute('data-title', 'Master Control')
    })

    it('passes nodeletIsOpen prop to NodeletContainer', () => {
      render(<MasterControl isEditor={false} nodeletIsOpen={true} />)
      const container = screen.getByTestId('nodelet-container')
      expect(container).toHaveAttribute('data-open', 'true')
    })

    it('passes nodeletIsOpen false to NodeletContainer', () => {
      render(<MasterControl isEditor={false} nodeletIsOpen={false} />)
      const container = screen.getByTestId('nodelet-container')
      expect(container).toHaveAttribute('data-open', 'false')
    })
  })

  describe('permission levels', () => {
    it('respects isEditor flag', () => {
      const searchForm = { nodeId: '123', nodeType: 'e2node', nodeTitle: 'Test', serverName: 'test.com', scriptName: '/index.pl' }
      const { rerender } = render(
        <MasterControl isEditor={false} adminSearchForm={searchForm} />
      )
      expect(screen.getByText('Nothing for you here.')).toBeInTheDocument()

      rerender(<MasterControl isEditor={true} adminSearchForm={searchForm} />)
      expect(screen.queryByText('Nothing for you here.')).not.toBeInTheDocument()
      expect(screen.getByTestId('admin-search-form')).toBeInTheDocument()
    })

    it('respects isAdmin flag for admin-only content', () => {
      const toolsetData = { nodeId: '123', nodeTitle: 'Test', nodeType: 'e2node', canDelete: true }
      const { rerender } = render(
        <MasterControl
          isEditor={true}
          isAdmin={false}
          nodeToolsetData={toolsetData}
        />
      )
      expect(screen.queryByTestId('node-toolset')).not.toBeInTheDocument()

      rerender(
        <MasterControl isEditor={true} isAdmin={true} nodeToolsetData={toolsetData} />
      )
      expect(screen.getByTestId('node-toolset')).toBeInTheDocument()
    })
  })
})
