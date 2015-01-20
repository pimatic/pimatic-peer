module.exports = (env) ->

  # Require the  bluebird promise library
  Promise = env.require 'bluebird'

  # Require the [cassert library](https://github.com/rhoot/cassert).
  assert = env.require 'cassert'


  class PerrtPlugin extends env.plugins.Plugin

    init: (app, @framework, @config) =>
      env.logger.info("Hello World")

  # ###Finally
  # Create a instance of my plugin
  peerPlugin = new PerrtPlugin
  # and return it to the framework.
  return peerPlugin