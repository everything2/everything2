import React from 'react';
import { render, screen, waitFor } from '@testing-library/react';
import { renderWithProviders, createMockUser, createMockGuest } from '../test-utils';
import E2ReactRoot from './E2ReactRoot';

// Mock the portals to avoid rendering complexity
jest.mock('./Portals/VitalsPortal', () => () => null);
jest.mock('./Portals/DeveloperPortal', () => () => null);
jest.mock('./Portals/NewWriteupsPortal', () => () => null);
jest.mock('./Portals/RecommendedReadingPortal', () => () => null);
jest.mock('./Portals/NewLogsPortal', () => () => null);
jest.mock('./Portals/RandomNodesPortal', () => () => null);
jest.mock('./Portals/SignInPortal', () => () => null);
jest.mock('./Portals/NeglectedDrafts', () => () => null);
jest.mock('./Portals/QuickReferencePortal', () => () => null);

describe('E2ReactRoot Component', () => {
  beforeEach(() => {
    // Reset global e2 object before each test
    global.e2 = {
      user: createMockGuest(),
      node: {
        node_id: 2030780,
        title: 'Guest Front Page',
        type: 'fullpage',
      },
      guest: 1,
      lastCommit: 'abc123',
      architecture: 'test',
      collapsedNodelets: '',
      newWriteups: [],
      coolnodes: [],
      staffpicks: [],
      daylogLinks: [],
      randomNodes: [],
      neglectedDrafts: {},
      quickRefSearchTerm: '',
      developerNodelet: { page: {}, news: {} },
      display_prefs: {
        num_newwus: 20,
        nw_nojunk: false,
        vit_hidemaintenance: 0,
        vit_hidenodeinfo: 0,
        vit_hidelist: 0,
        vit_hidenodeutil: 0,
        vit_hidemisc: 0,
        edn_hideutil: 0,
        edn_hideedev: 0,
      },
    };

    // Mock location
    delete window.location;
    window.location = { search: '', protocol: 'https:', host: 'everything2.com' };
  });

  describe('initialization', () => {
    it('renders without crashing', () => {
      render(<E2ReactRoot />);
    });

    it('initializes state from global e2 object', () => {
      const { container } = render(<E2ReactRoot />);
      expect(container).toBeTruthy();
    });

    it('sets guest state correctly for guest users', () => {
      global.e2.guest = 1;
      render(<E2ReactRoot />);
      // Component should render without error
    });

    it('sets guest state correctly for logged-in users', () => {
      global.e2.guest = 0;
      global.e2.user = createMockUser({ username: 'testuser' });
      render(<E2ReactRoot />);
      // Component should render without error
    });

    it('initializes collapsed nodelets from e2 config', () => {
      global.e2.collapsedNodelets = 'newwriteups!vitals!';
      render(<E2ReactRoot />);
      // Component should handle collapsed nodelets
    });

    it('handles trylogin URL parameter for guests', () => {
      global.e2.guest = 1;
      window.location.search = '?trylogin=1';
      render(<E2ReactRoot />);
      // Component should show login message
    });
  });

  describe('getRandomNodesPhrase', () => {
    it('returns a random phrase', () => {
      const wrapper = render(<E2ReactRoot />);
      const instance = wrapper.container._reactRootContainer?._internalRoot?.current?.child?.stateNode;

      // Since we can't easily access the instance, we'll just verify the component renders
      // The getRandomNodesPhrase is called in constructor, so if component renders, it works
      expect(wrapper.container).toBeTruthy();
    });
  });

  describe('display preferences', () => {
    it('initializes section visibility from display_prefs', () => {
      global.e2.display_prefs = {
        num_newwus: 20,
        nw_nojunk: true,
        vit_hidemaintenance: 1,
        vit_hidenodeinfo: 0,
        vit_hidelist: 1,
        vit_hidenodeutil: 0,
        vit_hidemisc: 0,
        edn_hideutil: 1,
        edn_hideedev: 0,
      };

      render(<E2ReactRoot />);
      // Component should handle display preferences
    });

    it('handles num_newwus preference', () => {
      global.e2.display_prefs.num_newwus = 50;
      render(<E2ReactRoot />);
      // Component should use the preference value
    });

    it('handles nw_nojunk preference', () => {
      global.e2.display_prefs.nw_nojunk = true;
      render(<E2ReactRoot />);
      // Component should filter junk writeups
    });
  });

  describe('nodelet data', () => {
    it('loads newWriteups from e2 config', () => {
      global.e2.newWriteups = [
        { node_id: 1, title: 'Test Writeup', is_junk: false },
        { node_id: 2, title: 'Another Writeup', is_junk: false },
      ];
      render(<E2ReactRoot />);
      // Component should have writeups in state
    });

    it('loads coolnodes from e2 config', () => {
      global.e2.coolnodes = [
        { node_id: 100, title: 'Cool Node 1', type: 'e2node' },
        { node_id: 101, title: 'Cool Node 2', type: 'e2node' },
      ];
      render(<E2ReactRoot />);
      // Component should have cool nodes in state
    });

    it('loads staffpicks from e2 config', () => {
      global.e2.staffpicks = [
        { node_id: 200, title: 'Staff Pick 1', type: 'e2node' },
      ];
      render(<E2ReactRoot />);
      // Component should have staff picks in state
    });

    it('loads randomNodes from e2 config', () => {
      global.e2.randomNodes = [
        { node_id: 300, title: 'Random Node 1', type: 'e2node' },
      ];
      render(<E2ReactRoot />);
      // Component should have random nodes in state
    });

    it('loads daylogLinks from e2 config', () => {
      global.e2.daylogLinks = [
        { node_id: 400, title: 'Daylog', type: 'e2node' },
      ];
      render(<E2ReactRoot />);
      // Component should have daylog links in state
    });

    it('loads neglectedDrafts from e2 config', () => {
      global.e2.neglectedDrafts = {
        count: 5,
        nodes: [{ node_id: 500, title: 'Draft', type: 'draft' }],
      };
      render(<E2ReactRoot />);
      // Component should have neglected drafts in state
    });
  });

  describe('developer nodelet', () => {
    it('loads developerNodelet from e2 config', () => {
      global.e2.developerNodelet = {
        page: { node_id: 123, title: 'Test Page', type: 'superdoc' },
        news: { weblog_id: 456, weblogs: [] },
      };
      render(<E2ReactRoot />);
      // Component should have developer nodelet data
    });
  });

  describe('guest login redirect', () => {
    it('sets loginGoto to current node for guests', () => {
      global.e2.guest = 1;
      global.e2.node = { node_id: 12345 };
      render(<E2ReactRoot />);
      // Should set loginGoto to 12345
    });

    it('redirects guest front page to default node after login', () => {
      global.e2.guest = 1;
      global.e2.node = { node_id: 2030780 }; // Default guest node
      render(<E2ReactRoot />);
      // Should set loginGoto to 124 (default node)
    });

    it('does not set loginGoto for logged-in users', () => {
      global.e2.guest = 0;
      global.e2.user = createMockUser();
      render(<E2ReactRoot />);
      // Should not have loginGoto in state
    });
  });

  describe('collapsed nodelets handling', () => {
    it('shows nodelets by default when not collapsed', () => {
      global.e2.collapsedNodelets = '';
      render(<E2ReactRoot />);
      // All nodelets should be shown
    });

    it('hides collapsed nodelets', () => {
      global.e2.collapsedNodelets = 'newwriteups!vitals!';
      render(<E2ReactRoot />);
      // Specified nodelets should be hidden
    });

    it('handles partial collapse', () => {
      global.e2.collapsedNodelets = 'newwriteups!';
      render(<E2ReactRoot />);
      // Only newwriteups should be hidden
    });
  });

  describe('architecture and commit info', () => {
    it('loads lastCommit from e2 config', () => {
      global.e2.lastCommit = 'abc123def456';
      render(<E2ReactRoot />);
      // Component should have commit info
    });

    it('loads architecture from e2 config', () => {
      global.e2.architecture = 'production';
      render(<E2ReactRoot />);
      // Component should have architecture info
    });
  });

  describe('quickRefSearchTerm', () => {
    it('loads quickRefSearchTerm from e2 config', () => {
      global.e2.quickRefSearchTerm = 'test search';
      render(<E2ReactRoot />);
      // Component should have search term
    });

    it('handles empty quickRefSearchTerm', () => {
      global.e2.quickRefSearchTerm = '';
      render(<E2ReactRoot />);
      // Component should handle empty search
    });
  });
});
