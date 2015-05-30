module.exports = (env) ->

  # Require the  bluebird promise library
  Promise = env.require 'bluebird'

  # Require the [cassert library](https://github.com/rhoot/cassert).
  assert = env.require 'cassert'
  _ = env.require 'lodash'
  io = require "socket.io-client"


  class PeerPlugin extends env.plugins.Plugin

    init: (app, @framework, @config) =>

      deviceConfigDef = require './device-config-schema'

      @framework.deviceManager.registerDeviceClass("RemoteDevice", {
        configDef: deviceConfigDef.RemoteDevice, 
        createCallback: (config) => new RemoteDevice(config)
      })

      # this should be from config...
      @connect("localhost", 8899, "admin", "admin")


    connect: (host, port, username, password) ->
      u = encodeURIComponent(username)
      p = encodeURIComponent(password)
      socket = io("http://#{host}:#{port}/?username=#{u}&password=#{p}", {
        reconnection: yes
        reconnectionDelay: 1000
        reconnectionDelayMax: 3000
        timeout: 20000
        forceNew: yes
      })
      socket.on "connect", -> console.log "connect"
      socket.on "hello", (data) -> console.log "hello", data

      socket.on "devices", (devices) => 
        for d in devices
          @emit "deviceChanged", d 

      socket.on("deviceAttributeChanged", (attrEvent) => 
        @emit "deviceAttributeChanged", attrEvent
      )

      socket.on "disconnect", -> console.log "disconnect"
      socket.on "error", (error) -> console.log error
      socket.on "connect_error", (error) -> console.log error


  class RemoteDevice extends env.devices.Device

    constructor: (@config) ->
      @name = config.name
      @id = config.id

      @attributes = {}
      @actions = {}
      
      @createAttribute(attr) for attr in @config.attributes
      @createAction(act) for act in @config.actions
      @template = @config.template
      super()

      peerPlugin.on "deviceChanged", @deviceChangedListener = (device) =>
        unless device.id + "2" is @id
          return
        
        console.log "change", device.id
        # handle name
        config.name = device.name
        @updateName(device.name)
        
        changed = false
        if device.template isnt @config.template
          @config.template = device.template
          changed = true

        curAttrNames = _.map(@config.attributes, (attr) => attr.name )
        for attr in device.attributes
          unless attr.name in curAttrNames
            changed = true
          
        if @config.attributes.length isnt device.attributes.length
          changed = true

        @config.attributes = device.attributes
        @config.actions = device.actions

        if changed
          peerPlugin.framework.deviceManager.recreateDevice this

      peerPlugin.on "deviceAttributeChanged", @deviceAttributeChangedListener = (attrEvent) =>
        unless attrEvent.deviceId + "2" is @id
          return
        @emit attrEvent.attributeName, attrEvent.value

    createAttribute: (attr) ->
      @addAttribute(attr.name, attr)
      @_createGetter(attr.name, => Promise.resolve(@_attributesMeta[attr.name].value))

    createAction: (act) ->
      @actions[act.name] = act
      @[act.name] = (args...) =>
        console.log "called", act.name, args
        return Promise.resolve()

    destroy: ->
      peerPlugin.removeListener "deviceChanged", @deviceChangedListener
      peerPlugin.removeListener "deviceAttributeChanged", @deviceAttributeChangedListener
      super()

  # ###Finally
  # Create a instance of my plugin
  peerPlugin = new PeerPlugin

  # and return it to the framework.
  return peerPlugin