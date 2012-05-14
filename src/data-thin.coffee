window.TD = Em.Namespace.create()

TD.Store = Em.Object.extend
  type: null
  map: null
  init: ->
    @_super()
    @path = "TD.Stores.#{Ember.guidFor @type}"
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

TD.Stores =
  getStore: (typ) ->
    guid = Ember.guidFor typ
    @[guid] = TD.Store.create({type: typ}) unless @[guid]
    @[guid]

TD.Model = Em.Object.extend
  _partial: null
  _status: null
  _path: null
  init: ->
    #@references = Em.A []
    @_status or= 'created'
    @_super()
  _path: (->
    "#{TD.Stores.getStore(@constructor).path}.#{Ember.guidFor @}"
    ).property()

TD.ModelArray = Em.ArrayProxy.extend
  store: null
  destroy: ->
    @_super

  _observeStore: (str, modeluid, val) ->
    #console.log 'notifed about change', arguments
    #console.log @content
    #console.log item,i for item,i in @content when Ember.guidFor(item) == modeluid
    for item,i in @content when Ember.guidFor(item) == modeluid
      do (item, i) =>
        @removeAt i
        #console.log @,i

  arrayDidChange: (array, index, removed, added) ->
    @_super(array, index, removed, added)
    #console.log "added", (a.get('id') for a in array[index...index+added])
    Ember.addObserver(@store, Ember.guidFor(item), @, @_observeStore) for item in array[index...index+added]

  arrayWillChange: (array, index, removed, added) ->
    @_super(array, index, removed, added)
    #console.log "remove", (a.get('id') for a in array[index...index+removed])
    Ember.removeObserver(@store, Ember.guidFor(item), @, @_observeStore) for item in array[index...index+added]


TD.Controller = Em.Object.extend
  store: null
  type: null
  urls: null
  init: ->
    @store = TD.Stores.getStore @type
    #@store = new TD.Store()
    @deserializer = {}
    @urls or= {}
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
      arr = (@findOne idx for idx in id)
      TD.ModelArray.create(store: @store, content: arr)
    else @findOne id

  findOne: (id) ->
    obj = @store.getById(id) 
    if obj and obj.get('_status') isnt 'error'
      obj
    else
      obj = @type.create(_status: 'loading', id: id)
      @store.add obj
      @_get obj
      obj

  load: (obj) ->
    if Em.isArray obj
      @loadOne objx for objx in obj
    else @loadOne obj

  loadOne: (obj, model = @type.create()) ->
    model.set('_status', 'loaded')
    for key, prop of obj
      @deserialize model, key, prop
    @store.add model
    model

  remove: (obj) ->
    @store.remove obj

  _get: (obj, partial = 'basic') ->
    url = @urls[partial] 
    if not url
      console.error("No url defined for <#{@type}> and partial <#{partial}>")
    url = url.replace /%id/, obj.id
    $.get(url)
     .success( (resp) =>
                console.log resp, "success", arguments, obj
                @loadOne resp, obj
     )
     .error( ->
       obj.set '_status','error'
       console.log "failure", arguments
     )
