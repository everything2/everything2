const path = require('path')

module.exports = {
  entry: path.resolve(__dirname, '../react', 'index.js'),
  mode: 'production',
  output: {
    path: path.resolve(__dirname, '../www/react'),
    filename: '[name].bundle.js'
  },
  module: {
    rules: [
      {
        test: /\.(jsx|js)$/,
        include: path.resolve(__dirname, '../react'),
        exclude: /node_modules/,
        use: [{
          loader: 'babel-loader',
          options: {
            presets: [
              ['@babel/preset-env', {
                "targets": "defaults"
              }],
              '@babel/preset-react'
            ]
          }
        }]
      },
      {
        test: /\.css$/i,
        use: ["style-loader","css-loader"],
      },
      {
        test: /\.(svg|png|gif|jpg|ico)$/i,
        include: path.resolve(__dirname, '../react/assets'),
        use: [{
          loader: 'file-loader',
          options: {
            outputPath: 'assets/',
            name: '[name].[ext]'
          }
        }]
      }
    ]
  }
}
