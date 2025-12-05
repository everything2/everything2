import React from 'react';

export default function E2SpermCounter({ data }) {
  const { total_sperm, online_sperm } = data;

  return (
    <div style={{ padding: '20px', fontFamily: 'Arial, sans-serif', textAlign: 'center' }}>
      <p>E2 Users world wide have</p>
      <p style={{ fontSize: '3em', fontWeight: 'bold', margin: '20px 0' }}>
        {total_sperm}
      </p>
      <p>sperm swimming around.</p>

      <p style={{ marginTop: '40px' }}>Currently online there are</p>
      <p style={{ fontSize: '3em', fontWeight: 'bold', margin: '20px 0' }}>
        {online_sperm}
      </p>
      <p>being wasted now, as you node.</p>
    </div>
  );
}
