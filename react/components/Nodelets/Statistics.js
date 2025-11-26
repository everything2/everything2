import React from 'react'
import NodeletContainer from '../NodeletContainer'
import NodeletSection from '../NodeletSection'
import {
  FaStar,
  FaPen,
  FaTrophy,
  FaCoins,
  FaMagic,
  FaMedal,
  FaGem,
  FaEgg,
  FaAward,
  FaChartBar,
  FaHeart,
  FaChartLine
} from 'react-icons/fa'

const Statistics = (props) => {
  if (!props.statistics) {
    return (
      <NodeletContainer
        id={props.id}
      title="Statistics"
        showNodelet={props.showNodelet}
        nodeletIsOpen={props.nodeletIsOpen}
      >
        <p style={{ padding: '8px', fontSize: '12px', fontStyle: 'italic' }}>
          No statistics available
        </p>
      </NodeletContainer>
    )
  }

  const { personal = {}, fun = {}, advancement = {} } = props.statistics

  const renderStatRow = (label, value, icon) => {
    if (value === undefined || value === null) {
      return null
    }

    return (
      <div style={{ display: 'flex', alignItems: 'center', gap: '6px', marginBottom: '4px', paddingLeft: '8px' }}>
        {icon && React.cloneElement(icon, { size: 12, style: { color: '#666', flexShrink: 0 } })}
        <span style={{ color: '#666' }}>{label}: </span>
        <span style={{ fontWeight: 'bold', marginLeft: 'auto' }}>{value}</span>
      </div>
    )
  }

  return (
    <NodeletContainer id={props.id}
      title="Statistics" nodeletIsOpen={props.nodeletIsOpen} showNodelet={props.showNodelet}>
      {personal && Object.keys(personal).length > 0 && (
        <NodeletSection
          nodelet="stat"
          section="personal"
          title="Yours"
          display={props.stat_personal}
          toggleSection={props.toggleSection}
        >
          <div style={{ paddingTop: '4px' }}>
            {renderStatRow('XP', personal.xp, <FaStar />)}
            {renderStatRow('Writeups', personal.writeups, <FaPen />)}
            {renderStatRow('Level', personal.level, <FaTrophy />)}
            {personal.xpNeeded !== undefined && personal.xpNeeded > 0 && renderStatRow('XP needed', personal.xpNeeded, <FaChartLine />)}
            {personal.wusNeeded !== undefined && personal.wusNeeded > 0 && renderStatRow('WUs needed', personal.wusNeeded, <FaChartLine />)}
            {!personal.gpOptout && renderStatRow('GP', personal.gp, <FaGem />)}
          </div>
        </NodeletSection>
      )}

      {fun && Object.keys(fun).length > 0 && (
        <NodeletSection
          nodelet="stat"
          section="fun"
          title="Fun Stats"
          display={props.stat_fun}
          toggleSection={props.toggleSection}
        >
          <div style={{ paddingTop: '4px' }}>
            {renderStatRow('Node-Fu', fun.nodeFu, <FaMagic />)}
            {renderStatRow('Golden Trinkets', fun.goldenTrinkets, <FaTrophy />)}
            {renderStatRow('Silver Trinkets', fun.silverTrinkets, <FaMedal />)}
            {renderStatRow('Stars', fun.stars, <FaStar />)}
            {renderStatRow('Easter Eggs', fun.easterEggs, <FaEgg />)}
            {renderStatRow('Tokens', fun.tokens, <FaCoins />)}
          </div>
        </NodeletSection>
      )}

      {advancement && Object.keys(advancement).length > 0 && (
        <NodeletSection
          nodelet="stat"
          section="advancement"
          title="Old Merit System"
          display={props.stat_advancement}
          toggleSection={props.toggleSection}
        >
          <div style={{ paddingTop: '4px' }}>
            {renderStatRow('Merit', advancement.merit, <FaAward />)}
            {renderStatRow('LF', advancement.lf, <FaChartBar />)}
            {renderStatRow('Devotion', advancement.devotion, <FaHeart />)}
            {renderStatRow('Merit mean', advancement.meritMean, <FaChartBar />)}
            {renderStatRow('Merit stddev', advancement.meritStddev, <FaChartBar />)}
          </div>
        </NodeletSection>
      )}
    </NodeletContainer>
  )
}

export default Statistics
