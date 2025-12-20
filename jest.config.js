module.exports = {
  // Test environment
  testEnvironment: 'jsdom',

  // Setup files
  setupFilesAfterEnv: ['<rootDir>/react/test-setup.js'],

  // Module paths
  roots: ['<rootDir>/react'],

  // Test match patterns
  testMatch: [
    '**/__tests__/**/*.js',
    '**/?(*.)+(spec|test).js'
  ],

  // Transform files with babel-jest
  transform: {
    '^.+\\.jsx?$': 'babel-jest',
  },

  // Module name mapper for static assets
  moduleNameMapper: {
    '\\.(css|less|scss|sass)$': '<rootDir>/react/__mocks__/styleMock.js',
    '\\.(jpg|jpeg|png|gif|ico|svg)$': '<rootDir>/react/__mocks__/fileMock.js',
  },

  // Coverage configuration
  collectCoverageFrom: [
    'react/**/*.{js,jsx}',
    '!react/index.js',
    '!react/**/*.test.{js,jsx}',
    '!react/**/__tests__/**',
    '!react/__mocks__/**',
  ],

  // Coverage thresholds (optional - can be adjusted as more tests are added)
  coverageThreshold: {
    global: {
      branches: 10,
      functions: 5,
      lines: 10,
      statements: 10,
    },
  },

  // Coverage reporters
  coverageReporters: ['text', 'lcov', 'html', 'json-summary'],

  // Coverage directory
  coverageDirectory: '<rootDir>/coverage/react',

  // Ignore patterns
  testPathIgnorePatterns: ['/node_modules/'],

  // Module file extensions
  moduleFileExtensions: ['js', 'jsx', 'json'],

  // Verbose output
  verbose: true,
};
