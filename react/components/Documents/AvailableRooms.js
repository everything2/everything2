import React from 'react';
import ParseLinks from '../ParseLinks';

/**
 * AvailableRooms - List of available chat rooms
 * Styles in CSS: .available-rooms__*
 */
const AvailableRooms = ({ data }) => {
  const { quip, rooms = [], error } = data;

  if (error) {
    return (
      <div className="available-rooms">
        <p className="available-rooms__error">{error}</p>
      </div>
    );
  }

  return (
    <div className="available-rooms">
      <p className="available-rooms__quip">
        <ParseLinks>{quip}</ParseLinks>
      </p>
      <p className="available-rooms__go-outside">
        ..or you could <a href="/?node=go%20outside">go outside</a>
      </p>
      <ul className="available-rooms__list">
        {rooms.map((room) => (
          <li key={room.node_id}>
            <a href={`/?node_id=${room.node_id}`}>{room.title}</a>
          </li>
        ))}
      </ul>
    </div>
  );
};

export default AvailableRooms;
