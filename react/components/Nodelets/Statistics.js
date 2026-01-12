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
        <p className="nodelet-empty">
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
      <div className="statistics-stat-row">
        {icon && React.cloneElement(icon, { size: 12, className: 'statistics-stat-icon' })}
        <span className="statistics-stat-label">{label}: </span>
        <span className="statistics-stat-value">{value}</span>
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
