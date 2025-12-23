import React from 'react'
import { reportClientError } from '../utils/reportClientError'

class ErrorBoundary extends React.Component {
  constructor(props) {
    super(props);
    this.state = { hasError: false };
  }

  static getDerivedStateFromError(error) {
    return { hasError: true };
  }

  componentDidCatch(error, errorInfo) {
    // Report the error to our logging API
    const componentName = this.props.componentName || 'Unknown component';

    reportClientError('js_error', error.message, {
      action: `rendering ${componentName}`,
      component_stack: errorInfo?.componentStack
    }, error.stack);
  }

  render() {
    if (this.state.hasError) {
      return <font color="#CC0000"><b>Client Error!</b></font>;
    }

    return this.props.children;
  }
}

export default ErrorBoundary;
