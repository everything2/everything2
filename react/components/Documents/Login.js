import React from 'react';

const Login = ({ data }) => {
  const { state, message, lastNodeId, siteName, user, defaultNode, lastNode } = data;

  // Get nodeId from window.e2.node.node_id (set by buildNodeInfoStructure)
  const nodeId = (typeof window !== 'undefined' && window.e2 && window.e2.node)
    ? window.e2.node.node_id
    : 109;

  // Success state - already logged in
  if (state === 'success') {
    return (
      <div style={{
        maxWidth: '600px',
        margin: '40px auto',
        padding: '30px',
        backgroundColor: '#f8f9f9',
        borderRadius: '8px',
        borderLeft: '4px solid #38495e'
      }}>
        <h2 style={{
          color: '#333333',
          marginTop: 0,
          marginBottom: '20px',
          fontSize: '24px'
        }}>
          Welcome back!
        </h2>
        <p style={{
          fontSize: '16px',
          lineHeight: '1.6',
          color: '#111111',
          marginBottom: '20px'
        }}>
          Hey, glad you're back! Where would you like to go?
        </p>
        <div style={{
          display: 'flex',
          flexDirection: 'column',
          gap: '12px'
        }}>
          <a
            href={`/user/${user.title.replace(/ /g, '+')}`}
            style={{
              display: 'block',
              padding: '12px 20px',
              backgroundColor: '#4060b0',
              color: 'white',
              textDecoration: 'none',
              borderRadius: '4px',
              textAlign: 'center',
              fontWeight: '500',
              transition: 'background-color 0.2s'
            }}
            onMouseOver={(e) => e.target.style.backgroundColor = '#38495e'}
            onMouseOut={(e) => e.target.style.backgroundColor = '#4060b0'}
          >
            Go to your home node
          </a>
          <a
            href={defaultNode ? `/title/${defaultNode.title.replace(/ /g, '+')}` : '/'}
            style={{
              display: 'block',
              padding: '12px 20px',
              backgroundColor: '#507898',
              color: 'white',
              textDecoration: 'none',
              borderRadius: '4px',
              textAlign: 'center',
              fontWeight: '500',
              transition: 'background-color 0.2s'
            }}
            onMouseOver={(e) => e.target.style.backgroundColor = '#38495e'}
            onMouseOut={(e) => e.target.style.backgroundColor = '#507898'}
          >
            Go to {defaultNode ? defaultNode.title : 'the homepage'}
          </a>
          {lastNode && (
            <a
              href={`/title/${lastNode.title.replace(/ /g, '+')}`}
              style={{
                display: 'block',
                padding: '12px 20px',
                backgroundColor: '#c5cdd7',
                color: '#111111',
                textDecoration: 'none',
                borderRadius: '4px',
                textAlign: 'center',
                fontWeight: '500',
                transition: 'background-color 0.2s'
              }}
              onMouseOver={(e) => e.target.style.backgroundColor = '#d3d3d3'}
              onMouseOut={(e) => e.target.style.backgroundColor = '#c5cdd7'}
            >
              Go back to {lastNode.title}
            </a>
          )}
        </div>
      </div>
    );
  }

  // Already logged in state
  if (state === 'already_logged_in') {
    return (
      <div style={{
        maxWidth: '600px',
        margin: '40px auto',
        padding: '30px',
        backgroundColor: '#f8f9f9',
        borderRadius: '8px',
        borderLeft: '4px solid #38495e'
      }}>
        <h2 style={{
          color: '#333333',
          marginTop: 0,
          marginBottom: '20px',
          fontSize: '24px'
        }}>
          Already logged in
        </h2>
        <p style={{
          fontSize: '16px',
          lineHeight: '1.6',
          color: '#111111'
        }}>
          Hey, <a href={`/user/${user.title.replace(/ /g, '+')}`} style={{ color: '#4060b0' }}>{user.title}</a>... you're already logged in!
        </p>
      </div>
    );
  }

  // Login form (default or error state)
  const welcomeMessage = state === 'error'
    ? 'Oops. You must have the wrong login or password or something:'
    : `Welcome to ${siteName}. Authenticate yourself:`;

  return (
    <div style={{
      maxWidth: '500px',
      margin: '40px auto',
      padding: '40px',
      backgroundColor: '#f8f9f9',
      borderRadius: '8px',
      boxShadow: '0 2px 4px rgba(0,0,0,0.1)',
      borderLeft: state === 'error' ? '4px solid #8b0000' : '4px solid #4060b0'
    }}>
      <h2 style={{
        color: '#333333',
        marginTop: 0,
        marginBottom: '10px',
        fontSize: '28px',
        fontWeight: '600'
      }}>
        Login
      </h2>

      <p style={{
        fontSize: '16px',
        lineHeight: '1.6',
        color: state === 'error' ? '#8b0000' : '#507898',
        marginBottom: '30px',
        fontWeight: state === 'error' ? '500' : 'normal'
      }}>
        {welcomeMessage}
      </p>

      <form method="POST" action={typeof window !== 'undefined' ? window.location.pathname : '/'}>
        <input type="hidden" name="op" value="login" />
        <input type="hidden" name="node_id" value={nodeId} />
        {lastNodeId > 0 && <input type="hidden" name="lastnode_id" value={lastNodeId} />}

        <div style={{ marginBottom: '20px' }}>
          <label
            htmlFor="user"
            style={{
              display: 'block',
              marginBottom: '8px',
              color: '#333333',
              fontSize: '14px',
              fontWeight: '500'
            }}
          >
            Username
          </label>
          <input
            type="text"
            name="user"
            id="user"
            maxLength="20"
            autoComplete="username"
            autoFocus
            style={{
              width: '100%',
              padding: '12px',
              fontSize: '16px',
              border: '1px solid #d3d3d3',
              borderRadius: '4px',
              boxSizing: 'border-box',
              transition: 'border-color 0.2s',
              outline: 'none'
            }}
            onFocus={(e) => e.target.style.borderColor = '#4060b0'}
            onBlur={(e) => e.target.style.borderColor = '#d3d3d3'}
          />
        </div>

        <div style={{ marginBottom: '20px' }}>
          <label
            htmlFor="passwd"
            style={{
              display: 'block',
              marginBottom: '8px',
              color: '#333333',
              fontSize: '14px',
              fontWeight: '500'
            }}
          >
            Password
          </label>
          <input
            type="password"
            name="passwd"
            id="passwd"
            maxLength="240"
            autoComplete="current-password"
            style={{
              width: '100%',
              padding: '12px',
              fontSize: '16px',
              border: '1px solid #d3d3d3',
              borderRadius: '4px',
              boxSizing: 'border-box',
              transition: 'border-color 0.2s',
              outline: 'none'
            }}
            onFocus={(e) => e.target.style.borderColor = '#4060b0'}
            onBlur={(e) => e.target.style.borderColor = '#d3d3d3'}
          />
        </div>

        <div style={{ marginBottom: '25px' }}>
          <label style={{
            display: 'flex',
            alignItems: 'center',
            cursor: 'pointer',
            fontSize: '14px',
            color: '#507898'
          }}>
            <input
              type="checkbox"
              name="expires"
              value="+10y"
              style={{
                marginRight: '8px',
                width: '16px',
                height: '16px',
                cursor: 'pointer'
              }}
            />
            Save me a permanent cookie, cowboy!
          </label>
        </div>

        <button
          type="submit"
          name="sexisgood"
          style={{
            width: '100%',
            padding: '14px',
            fontSize: '16px',
            fontWeight: '600',
            color: 'white',
            backgroundColor: '#4060b0',
            border: 'none',
            borderRadius: '4px',
            cursor: 'pointer',
            transition: 'background-color 0.2s',
            marginBottom: '20px'
          }}
          onMouseOver={(e) => e.target.style.backgroundColor = '#38495e'}
          onMouseOut={(e) => e.target.style.backgroundColor = '#4060b0'}
        >
          Log In
        </button>

        <div style={{
          paddingTop: '20px',
          borderTop: '1px solid #d3d3d3',
          textAlign: 'center',
          fontSize: '14px',
          color: '#507898'
        }}>
          <p style={{ marginBottom: '10px' }}>
            <a href="/title/Reset+password" style={{ color: '#4060b0', textDecoration: 'none' }}>
              Forgot your password or username?
            </a>
          </p>
          <p style={{ margin: 0 }}>
            Don't have an account? <a href="/title/Sign+up" style={{ color: '#4060b0', textDecoration: 'none', fontWeight: '500' }}>Create one</a>!
          </p>
        </div>
      </form>
    </div>
  );
};

export default Login;
