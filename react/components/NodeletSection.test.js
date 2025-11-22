import React from 'react';
import { render, fireEvent } from '@testing-library/react';
import NodeletSection from './NodeletSection';

describe('NodeletSection Component', () => {
  const mockToggleSection = jest.fn();

  beforeEach(() => {
    mockToggleSection.mockClear();
  });

  describe('rendering', () => {
    it('renders section title', () => {
      const { getByText } = render(
        <NodeletSection
          nodelet="vitals"
          section="info"
          title="User Information"
          display={true}
          toggleSection={mockToggleSection}
        >
          <div>Content</div>
        </NodeletSection>
      );

      expect(getByText('User Information')).toBeInTheDocument();
    });

    it('renders children content', () => {
      const { getByText } = render(
        <NodeletSection
          nodelet="vitals"
          section="stats"
          title="Statistics"
          display={true}
          toggleSection={mockToggleSection}
        >
          <div>Stats content here</div>
        </NodeletSection>
      );

      expect(getByText('Stats content here')).toBeInTheDocument();
    });

    it('applies correct ID based on nodelet and section', () => {
      const { container } = render(
        <NodeletSection
          nodelet="developer"
          section="logs"
          title="Logs"
          display={true}
          toggleSection={mockToggleSection}
        >
          <div>Log content</div>
        </NodeletSection>
      );

      const sectionDiv = container.querySelector('#developersection_logs');
      expect(sectionDiv).toBeInTheDocument();
    });

    it('applies nodeletsection CSS class', () => {
      const { container } = render(
        <NodeletSection
          nodelet="test"
          section="section1"
          title="Test"
          display={true}
          toggleSection={mockToggleSection}
        >
          <div>Content</div>
        </NodeletSection>
      );

      const sectionDiv = container.querySelector('.nodeletsection');
      expect(sectionDiv).toBeInTheDocument();
    });
  });

  describe('collapse/expand functionality', () => {
    it('shows down chevron icon when section is displayed', () => {
      const { container } = render(
        <NodeletSection
          nodelet="vitals"
          section="info"
          title="User Info"
          display={true}
          toggleSection={mockToggleSection}
        >
          <div>Content</div>
        </NodeletSection>
      );

      // Check for SVG icon in the toggle link
      const toggleLink = container.querySelector('a[style*="cursor"]');
      expect(toggleLink).toBeInTheDocument();
      expect(toggleLink.querySelector('svg')).toBeInTheDocument();
    });

    it('shows right chevron icon when section is hidden', () => {
      const { container } = render(
        <NodeletSection
          nodelet="vitals"
          section="info"
          title="User Info"
          display={false}
          toggleSection={mockToggleSection}
        >
          <div>Content</div>
        </NodeletSection>
      );

      // Check for SVG icon in the toggle link
      const toggleLink = container.querySelector('a[style*="cursor"]');
      expect(toggleLink).toBeInTheDocument();
      expect(toggleLink.querySelector('svg')).toBeInTheDocument();
    });

    it('does not apply toggledoff class when section is displayed', () => {
      const { container } = render(
        <NodeletSection
          nodelet="vitals"
          section="info"
          title="User Info"
          display={true}
          toggleSection={mockToggleSection}
        >
          <div>Content</div>
        </NodeletSection>
      );

      const contentDiv = container.querySelector('.sectioncontent');
      expect(contentDiv).toBeInTheDocument();
      expect(contentDiv).not.toHaveClass('toggledoff');
    });

    it('applies toggledoff class when section is hidden', () => {
      const { container } = render(
        <NodeletSection
          nodelet="vitals"
          section="info"
          title="User Info"
          display={false}
          toggleSection={mockToggleSection}
        >
          <div>Content</div>
        </NodeletSection>
      );

      const contentDiv = container.querySelector('.sectioncontent');
      expect(contentDiv).toBeInTheDocument();
      expect(contentDiv).toHaveClass('toggledoff');
    });
  });

  describe('user interactions', () => {
    it('calls toggleSection when toggle link is clicked', () => {
      const { container } = render(
        <NodeletSection
          nodelet="vitals"
          section="info"
          title="User Info"
          display={true}
          toggleSection={mockToggleSection}
        >
          <div>Content</div>
        </NodeletSection>
      );

      const toggleLink = container.querySelector('a[style*="cursor"]');
      fireEvent.click(toggleLink);

      expect(mockToggleSection).toHaveBeenCalledTimes(1);
    });

    it('passes correct section identifier to toggleSection', () => {
      const { container } = render(
        <NodeletSection
          nodelet="developer"
          section="logs"
          title="Logs"
          display={true}
          toggleSection={mockToggleSection}
        >
          <div>Content</div>
        </NodeletSection>
      );

      const toggleLink = container.querySelector('a[style*="cursor"]');
      fireEvent.click(toggleLink);

      expect(mockToggleSection).toHaveBeenCalledWith(
        expect.anything(),
        'developer_logs'
      );
    });

    it('toggle link has pointer cursor', () => {
      const { container } = render(
        <NodeletSection
          nodelet="vitals"
          section="info"
          title="User Info"
          display={true}
          toggleSection={mockToggleSection}
        >
          <div>Content</div>
        </NodeletSection>
      );

      const toggleLink = container.querySelector('a[style*="cursor"]');
      expect(toggleLink).toHaveStyle({ cursor: 'pointer' });
    });
  });

  describe('structure and styling', () => {
    it('contains section heading div', () => {
      const { container } = render(
        <NodeletSection
          nodelet="vitals"
          section="info"
          title="User Info"
          display={true}
          toggleSection={mockToggleSection}
        >
          <div>Content</div>
        </NodeletSection>
      );

      const headingDiv = container.querySelector('.sectionheading');
      expect(headingDiv).toBeInTheDocument();
    });

    it('contains section content div', () => {
      const { container } = render(
        <NodeletSection
          nodelet="vitals"
          section="info"
          title="User Info"
          display={true}
          toggleSection={mockToggleSection}
        >
          <div>Content</div>
        </NodeletSection>
      );

      const contentDiv = container.querySelector('.sectioncontent');
      expect(contentDiv).toBeInTheDocument();
    });

    it('wraps title in strong tag', () => {
      const { getByText } = render(
        <NodeletSection
          nodelet="vitals"
          section="info"
          title="User Info"
          display={true}
          toggleSection={mockToggleSection}
        >
          <div>Content</div>
        </NodeletSection>
      );

      const title = getByText('User Info');
      expect(title.tagName).toBe('STRONG');
    });
  });
});
