import React from 'react'
import { render } from '@testing-library/react'
import ServerTelemetry from './ServerTelemetry'
import fixture from '../../__fixtures__/pagestate/server_telemetry.json'
// Fixture-backed coverage (PageState 2a, #4255): real normalized /api/pagestate payload,
// pinning the int-typed contract (#4152/#4108).
describe('ServerTelemetry (real pagestate fixture)', () => {
  it('mounts against the captured payload', () => {
    const { container } = render(<ServerTelemetry data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    expect(container).toBeTruthy()
  })
  it('fixture has integer node_ids, never strings (#4152)', () => {
    expect(JSON.stringify(fixture).match(/"node_id":"\d/g)).toBeNull()
  })
  it('no React key warnings', () => {
    const errs = []
    const spy = jest.spyOn(console, 'error').mockImplementation((...a) => errs.push(a.join(' ')))
    render(<ServerTelemetry data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    spy.mockRestore()
    expect(errs.filter((x) => /unique "key"|each child in a list/i.test(x))).toEqual([])
  })
  it('renders the cron subsystem status block', () => {
    const cron = 'Cron subsystem: DEGRADED  --  1 failing\nLeader: host-x (ok, heartbeat 5s ago)'
    const { getByText, container } = render(<ServerTelemetry data={{ cron_status: cron }} />)
    expect(getByText('Cron Subsystem')).toBeTruthy()
    expect(container.textContent).toContain('Cron subsystem: DEGRADED')
  })
  it('renders the Starman app-workers panel', () => {
    const { container } = render(<ServerTelemetry data={{ worker_count: 14, apache_count: 2, app_workers: 'starman master --workers 14' }} />)
    expect(container.textContent).toContain('App Workers')
    expect(container.textContent).toContain('14 Starman')
  })
})
