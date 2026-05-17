import React from 'react';

export default function E2SpermCounter({ data }) {
  const { total_sperm, online_sperm } = data;

  return (
    <div className="sperm-counter">
      <p>E2 Users world wide have</p>
      <p className="sperm-counter__number">
        {total_sperm}
      </p>
      <p>sperm swimming around.</p>

      <p className="sperm-counter__online-intro">Currently online there are</p>
      <p className="sperm-counter__number">
        {online_sperm}
      </p>
      <p>being wasted now, as you node.</p>
    </div>
  );
}
