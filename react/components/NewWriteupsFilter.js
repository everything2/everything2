import React from 'react'

const newWriteupsCount = [1,5,10,15,20,25,30,40]
const newWriteupsDefault = 10

const NewWriteupsFilter = ({limit,newWriteupsChange,noJunk,noJunkChange,user}) => {
    return <>{(user.guest)?(<></>):(
      <><select value={limit} onChange={(event) => newWriteupsChange(event.target.value)} >
        {newWriteupsCount.map((count, index) => {
        return <option value={count} key={"newwupref_"+count}>{count}</option>
        })}
      </select><label>{(user.editor)?(<><input type="checkbox" onChange={(event) => noJunkChange(event.target.checked)} defaultChecked={noJunk} />No junk</>):(<></>)}</label>
    </>)}</>
}

export default NewWriteupsFilter
