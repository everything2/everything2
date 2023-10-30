import React from 'react'

class ErrorBoundary extends React.Component {
  constructor(props) {
    super(props);
    this.state = { hasError: false };
  }

  static getDerivedStateFromError(error) {
    return { hasError: true };
  }

  render() {
    if (this.state.hasError) {
      return <font color="#CC0000"><b>Client Error!</b></font>;
    }

    return this.props.children; 
  }
}

export default ErrorBoundary;
