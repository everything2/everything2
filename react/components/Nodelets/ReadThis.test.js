import React from 'react';
import { render, screen } from '@testing-library/react';
import ReadThis from './ReadThis';

// Mock child components
jest.mock('../LinkNode', () => {
  return function MockLinkNode({ title, display, type, id, params }) {
    return <span data-testid="link-node">{display || title}</span>;
  };
});

jest.mock('../NodeletContainer', () => {
  return function MockNodeletContainer({ title, children, showNodelet, nodeletIsOpen }) {
    return (
      <div data-testid="nodelet-container" data-title={title} data-open={nodeletIsOpen}>
        {children}
      </div>
    );
  };
});

jest.mock('../NodeletSection', () => {
  return function MockNodeletSection({ title, display, children, nodelet, section }) {
    return (
      <div
        data-testid="nodelet-section"
        data-title={title}
        data-display={display}
        data-nodelet={nodelet}
        data-section={section}
      >
        {children}
      </div>
    );
  };
});

describe('ReadThis Component', () => {
  const mockShowNodelet = jest.fn();
  const mockToggleSection = jest.fn();

  const defaultProps = {
    showNodelet: mockShowNodelet,
    nodeletIsOpen: true,
    cwu_show: true,
    edc_show: true,
    nws_show: true,
    toggleSection: mockToggleSection,
    coolnodes: [
      { coolwriteups_id: 1, parentTitle: 'Cool Node 1' },
      { coolwriteups_id: 2, parentTitle: 'Cool Node 2' }
    ],
    staffpicks: [
      { node_id: 3, title: 'Staff Pick 1' },
      { node_id: 4, title: 'Staff Pick 2' }
    ],
    news: [
      { node_id: 5, title: 'News Item 1' },
      { node_id: 6, title: 'News Item 2' }
    ]
  };

  beforeEach(() => {
    mockShowNodelet.mockClear();
    mockToggleSection.mockClear();
  });

  describe('rendering', () => {
    it('renders ReadThis nodelet container', () => {
      render(<ReadThis {...defaultProps} />);

      const container = screen.getByTestId('nodelet-container');
      expect(container).toBeInTheDocument();
      expect(container).toHaveAttribute('data-title', 'ReadThis');
    });

    it('renders all three sections', () => {
      render(<ReadThis {...defaultProps} />);

      const sections = screen.getAllByTestId('nodelet-section');
      expect(sections).toHaveLength(3);

      expect(sections[0]).toHaveAttribute('data-title', 'Cool Writeups');
      expect(sections[0]).toHaveAttribute('data-nodelet', 'rtn');
      expect(sections[0]).toHaveAttribute('data-section', 'cwu');

      expect(sections[1]).toHaveAttribute('data-title', 'Editor Selections');
      expect(sections[1]).toHaveAttribute('data-nodelet', 'rtn');
      expect(sections[1]).toHaveAttribute('data-section', 'edc');

      expect(sections[2]).toHaveAttribute('data-title', 'News');
      expect(sections[2]).toHaveAttribute('data-nodelet', 'rtn');
      expect(sections[2]).toHaveAttribute('data-section', 'nws');
    });

    it('renders Cool Writeups list items', () => {
      render(<ReadThis {...defaultProps} />);

      expect(screen.getByText('Cool Node 1')).toBeInTheDocument();
      expect(screen.getByText('Cool Node 2')).toBeInTheDocument();
    });

    it('renders Staff Picks list items', () => {
      render(<ReadThis {...defaultProps} />);

      expect(screen.getByText('Staff Pick 1')).toBeInTheDocument();
      expect(screen.getByText('Staff Pick 2')).toBeInTheDocument();
    });

    it('renders News list items', () => {
      render(<ReadThis {...defaultProps} />);

      expect(screen.getByText('News Item 1')).toBeInTheDocument();
      expect(screen.getByText('News Item 2')).toBeInTheDocument();
    });

    it('renders Cool Archive link', () => {
      render(<ReadThis {...defaultProps} />);

      expect(screen.getByText('Cool Archive')).toBeInTheDocument();
    });

    it('renders Page of Cool link', () => {
      render(<ReadThis {...defaultProps} />);

      expect(screen.getByText('Page of Cool')).toBeInTheDocument();
    });
  });

  describe('empty data handling', () => {
    it('handles empty coolnodes array', () => {
      const props = { ...defaultProps, coolnodes: [] };
      const { container } = render(<ReadThis {...props} />);

      expect(container).toBeInTheDocument();
    });

    it('handles empty staffpicks array', () => {
      const props = { ...defaultProps, staffpicks: [] };
      const { container } = render(<ReadThis {...props} />);

      expect(container).toBeInTheDocument();
    });

    it('handles empty news array', () => {
      const props = { ...defaultProps, news: [] };
      render(<ReadThis {...props} />);

      expect(screen.getByText('No news is good news')).toBeInTheDocument();
    });

    it('handles undefined news', () => {
      const props = { ...defaultProps, news: undefined };
      render(<ReadThis {...props} />);

      expect(screen.getByText('No news is good news')).toBeInTheDocument();
    });
  });

  describe('section visibility', () => {
    it('passes correct display prop to Cool Writeups section', () => {
      render(<ReadThis {...defaultProps} cwu_show={false} />);

      const sections = screen.getAllByTestId('nodelet-section');
      expect(sections[0]).toHaveAttribute('data-display', 'false');
    });

    it('passes correct display prop to Editor Selections section', () => {
      render(<ReadThis {...defaultProps} edc_show={false} />);

      const sections = screen.getAllByTestId('nodelet-section');
      expect(sections[1]).toHaveAttribute('data-display', 'false');
    });

    it('passes correct display prop to News section', () => {
      render(<ReadThis {...defaultProps} nws_show={false} />);

      const sections = screen.getAllByTestId('nodelet-section');
      expect(sections[2]).toHaveAttribute('data-display', 'false');
    });
  });

  describe('callback props', () => {
    it('passes showNodelet prop to NodeletContainer', () => {
      render(<ReadThis {...defaultProps} />);

      const container = screen.getByTestId('nodelet-container');
      expect(container).toBeInTheDocument();
      // showNodelet is passed to NodeletContainer
    });

    it('passes toggleSection to all sections', () => {
      render(<ReadThis {...defaultProps} />);

      const sections = screen.getAllByTestId('nodelet-section');
      expect(sections).toHaveLength(3);
      // Each section receives toggleSection callback
    });

    it('passes nodeletIsOpen prop correctly', () => {
      const { rerender } = render(<ReadThis {...defaultProps} nodeletIsOpen={true} />);
      let container = screen.getByTestId('nodelet-container');
      expect(container).toHaveAttribute('data-open', 'true');

      rerender(<ReadThis {...defaultProps} nodeletIsOpen={false} />);
      container = screen.getByTestId('nodelet-container');
      expect(container).toHaveAttribute('data-open', 'false');
    });
  });

  describe('data structure', () => {
    it('renders multiple coolnodes correctly', () => {
      const props = {
        ...defaultProps,
        coolnodes: [
          { coolwriteups_id: 1, parentTitle: 'Node 1' },
          { coolwriteups_id: 2, parentTitle: 'Node 2' },
          { coolwriteups_id: 3, parentTitle: 'Node 3' },
        ]
      };
      render(<ReadThis {...props} />);

      expect(screen.getByText('Node 1')).toBeInTheDocument();
      expect(screen.getByText('Node 2')).toBeInTheDocument();
      expect(screen.getByText('Node 3')).toBeInTheDocument();
    });

    it('renders multiple staffpicks correctly', () => {
      const props = {
        ...defaultProps,
        staffpicks: [
          { node_id: 1, title: 'Staff 1' },
          { node_id: 2, title: 'Staff 2' },
          { node_id: 3, title: 'Staff 3' },
        ]
      };
      render(<ReadThis {...props} />);

      expect(screen.getByText('Staff 1')).toBeInTheDocument();
      expect(screen.getByText('Staff 2')).toBeInTheDocument();
      expect(screen.getByText('Staff 3')).toBeInTheDocument();
    });

    it('renders multiple news items correctly', () => {
      const props = {
        ...defaultProps,
        news: [
          { node_id: 1, title: 'News 1' },
          { node_id: 2, title: 'News 2' },
          { node_id: 3, title: 'News 3' },
        ]
      };
      render(<ReadThis {...props} />);

      expect(screen.getByText('News 1')).toBeInTheDocument();
      expect(screen.getByText('News 2')).toBeInTheDocument();
      expect(screen.getByText('News 3')).toBeInTheDocument();
    });
  });

  describe('component structure', () => {
    it('wraps content in NodeletContainer', () => {
      render(<ReadThis {...defaultProps} />);

      const container = screen.getByTestId('nodelet-container');
      expect(container).toHaveAttribute('data-title', 'ReadThis');
    });

    it('creates sections in correct order', () => {
      render(<ReadThis {...defaultProps} />);

      const sections = screen.getAllByTestId('nodelet-section');
      expect(sections[0]).toHaveAttribute('data-section', 'cwu');
      expect(sections[1]).toHaveAttribute('data-section', 'edc');
      expect(sections[2]).toHaveAttribute('data-section', 'nws');
    });

    it('uses correct nodelet abbreviation for all sections', () => {
      render(<ReadThis {...defaultProps} />);

      const sections = screen.getAllByTestId('nodelet-section');
      sections.forEach(section => {
        expect(section).toHaveAttribute('data-nodelet', 'rtn');
      });
    });
  });

  describe('integration with other components', () => {
    it('renders LinkNode components for all data items', () => {
      render(<ReadThis {...defaultProps} />);

      const linkNodes = screen.getAllByTestId('link-node');
      // 2 coolnodes + 2 staffpicks + 2 news + 2 footer links = 8 total
      expect(linkNodes.length).toBeGreaterThanOrEqual(6);
    });

    it('renders footer links in nodeletfoot divs', () => {
      const { container } = render(<ReadThis {...defaultProps} />);

      const footers = container.querySelectorAll('.nodeletfoot');
      expect(footers).toHaveLength(2); // Cool Archive and Page of Cool
    });
  });
});
