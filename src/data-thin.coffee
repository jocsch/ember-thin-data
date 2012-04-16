window.App = Em.Application.create()

App.Store = Em.Object.extend
  type: null
  map: null
  init: ->
    @_super()
    @path = "App.Stores.#{Ember.guidFor @type}"
    @map = {}
  add: (obj) ->
    guid = Ember.guidFor obj
    @set guid, obj
    @linkId(obj) if obj.id
    guid
  linkId: (obj) ->
    @map[obj.id] = obj
    obj.id
  #get: (uid) -> @[uid]
  getById: (id) -> @map[id]
  remove: (obj) ->
    guid = Ember.guidFor obj
    #set it to null as otherwise the observers do not kick in
    @set guid, null
    delete @[guid]
    delete @map[obj.id] if obj.id
    obj

App.Stores =
  getStore: (typ) ->
    guid = Ember.guidFor typ
    #@[guid] = Ember.Object.create({_path: "App.Stores.#{guid}"}) unless @[guid]
    @[guid] = App.Store.create({type: typ}) unless @[guid]
    @[guid]

App.Model = Em.Object.extend
  _partial: null
  _status: null
  _path: null
  init: ->
    @references = Em.A []
    @_status or= 'created'
    @_super()
    #@_path = "App.Stores.#{App.Stores.getStore(@constructor).path}.#{Ember.guidFor @}"
  _path: (->
    "#{App.Stores.getStore(@constructor).path}.#{Ember.guidFor @}"
    ).property()

App.ModelArray = Em.ArrayProxy.extend
  store: null
  destroy: ->
    @_super

  _observeStore: (str, modeluid, val) ->
    console.log 'notifed about change', arguments
    console.log @content
    #console.log item,i for item,i in @content when Ember.guidFor(item) == modeluid
    for item,i in @content when Ember.guidFor(item) == modeluid
      do (item, i) =>
        console.log @,i
        @removeAt i
        #remove Listener

  arrayDidChange: (array, index, removed, added) ->
    @_super(array, index, removed, added)
    #console.log("did: ", (a.get('id') for a in array), index, removed, added)
    console.log "added", (a.get('id') for a in array[index...index+added])
    Ember.addObserver(@store, Ember.guidFor(item), @, @_observeStore) for item in array[index...index+added]
    #Ember.addObserver(@store, Ember.guidFor(item), @, -> alert('stupoid')) for item in array[index...index+added]

  arrayWillChange: (array, index, removed, added) ->
    @_super(array, index, removed, added)
    #console.log("will: ", (a.get('id') for a in array), index, removed, added)
    console.log "remove", (a.get('id') for a in array[index...index+removed])
    Ember.removeObserver(@store, Ember.guidFor(item), @, @_observeStore) for item in array[index...index+added]


App.Controller = Em.Object.extend
  store: null
  type: null
  init: ->
    @store = App.Stores.getStore @type
    #@store = new App.Store()
    @deserializer = {}
    @_super()

  deserialize: (model, key, prop) ->
    model.set key, 
      if @deserializer[key]
        @deserializer[key] prop
      else
        prop
    model

  find: (id) ->
    if Em.isArray id 
      @findOne idx for idx in id
    else @findOne id

  findOne: (id) ->
    @store.getById(id) ? @type.create(_status: 'loading')

  load: (obj) ->
    if Em.isArray obj 
      @loadOne objx for objx in obj
    else @loadOne obj

  loadOne: (obj) ->
    model = @type.create(_status: 'loaded')
    for key, prop of obj 
      @deserialize model, key, prop
    @store.add model
    model

  remove: (obj) ->
    @store.remove obj
