#setup test data
window.App = Em.Application.create()

App.Person = TD.Model.extend
  firstName: null
  lastName: null,
  _partialbasic: (->
    @get('firstName')?
  ).property 'lastName'

App.Group = TD.Model.extend
  name: null
  members: null
  admins: null
  _partialbasic: (->
    @get('name')?
  ).property 'name'
  _partialcomplete: (->
    @get('admins')?
  ).property 'name', 'admins'


App.PController = TD.Controller.create
  type: App.Person
  urls:
    basic: '/ember-thin-data/test/data/user/%id'

App.GController = TD.Controller.create
  type: App.Group
  urls: 
    basic: '/ember-thin-data/test/data/group/%id'
    complete: '/ember-thin-data/test/data/group-complete/%id'
  init: ->
    @_super()
    @deserializer['members'] = (ids) -> App.PController.find ids

App.PController.load [
    id: 1
    firstName: "abc"
    lastName: "def"
  ,
    id: 2
    firstName: "foo"
    lastName: "bar"
  ,
    id: 3
    firstName: "tinky"
    lastName: "no"
]

App.GController.load [
    id: 1
    name: "Group1"
    members: [1,2]
  ,
    id: 2
    name: "Group2"
    members: [2,3]
]


respondServerSuccess = (server, urlfrag, responseObject) ->
  server.respondWith "/ember-thin-data/test/data/#{urlfrag}/#{responseObject.id}", [200, { "Content-Type": "application/json" }, 
      JSON.stringify(responseObject)]

respondServerError = (server, urlfrag, id, code) ->
  server.respondWith "/ember-thin-data/test/data/#{urlfrag}/#{id}", [code, { "Content-Type": "application/json" }, ""]

checkP = (obj, id, fName, lName) ->
  equal obj.get('id'), id
  equal obj.get('firstName'), fName
  equal obj.get('lastName'), lName

test "Test loaded people", ->
  store = App.PController.store
  ok store.getById(1) and store.getById(2) and store.getById(3), "Check correct nr of items" 
  equal store.getById(3).get('id'), 3, "Test id prop"
  equal store.getById(3).get('firstName'), "tinky", "Test firstname prop"
  equal store.getById(3).get('lastName'), "no", "Test lastname prop"
  equal store.getById(3).get('_status'), "loaded", "Test status prop"
  equal store.getById(1).constructor, App.Person, "Check correct type loaded"

test "Test loaded groups", ->
  store = App.GController.store
  ok store.getById(1) and store.getById(2),  "Check correct nr of items" 
  deepGroup = store.getById(1)
  equal deepGroup.constructor, App.Group, "Check group type"
  equal deepGroup.get('id'), 1, "Test id prop"
  equal deepGroup.get('name'), 'Group1', "Test id prop"
  equal deepGroup.get('members').get('length'), 2, "Member array length"
  equal deepGroup.get('_status'), 'loaded', "Test status prop"
  member = deepGroup.get('members').get('firstObject')
  equal member.constructor, App.Person, "Check member type"
  equal member.get('_status'), "loaded", "Check member status"

test "Late id linking", ->
  store = App.PController.store
  jP = 
    firstName: "Bla",
    lastName: "Depp"

  tmpP = App.PController.load jP
  guid = Ember.guidFor tmpP
  equal store[guid], tmpP
  tmpP.set 'id', 91
  store.linkId tmpP
  equal store[guid], tmpP, "Should be same"
  equal App.PController.findOne(91), tmpP
  store.remove tmpP
  ok not store[guid]
  ok not store.map[91]


test "Find", ->
  p1 = App.PController.find 1
  equal p1.get("id"), 1
  equal p1.get("firstName"), "abc"
  equal p1.get("_status"), "loaded"
  equal p1.constructor, App.Person
  p2 = App.PController.find 2
  equal p2.get("id"), 2
  equal p2.get("firstName"), "foo"
  equal p2.constructor, App.Person
  server = @sandbox.useFakeServer()
  respondServerSuccess server, 'user', {id: 99, firstName: "new"}
  p99 = App.PController.find 99
  #equal p99.get("id"), undefined, "Test object not in cache"
  equal p99.get("_status"), "loading", "Test status loading"
  server.respond()

test "Same object is returned", ->
  p2 = App.PController.find 2
  p2x = App.PController.find 2
  g1 = App.GController.find 1
  m2 = g1.get('members').filterProperty('id', 2)[0]
  g2 = App.GController.find 2
  m2x = g2.get('members').filterProperty('id', 2).get 'firstObject'

  ok p2 == p2x == m2 == m2x

  con = Em.Object.create
    #this indirection is needed as a binding can only be established to a path
    #monitored: m2x
    #nameBinding: 'monitored.firstName'
    nameBinding: m2x.get('_path') + '.firstName'

  Em.run.sync()
  equal con.get('name'), 'foo', "Binded property"

  p2.set 'firstName', 'bar'
  Em.run.sync()
  equal p2x.get('firstName'), 'bar', "Check direct reference"
  equal m2x.get('firstName'), 'bar', "Check direct reference"

  equal con.get('name'), 'bar', "Check that the binded property also is updated p2=m2x->con"

  #reset
  p2.set 'firstName', 'foo'
  Em.run.sync()

test "Object has correct path", ->
  pStore = TD.Stores.getStore(App.Person)
  equal pStore.get('path'), "TD.Stores.#{Em.guidFor App.Person}"
  gStore = TD.Stores.getStore(App.Group)
  equal gStore.get('path'), "TD.Stores.#{Em.guidFor App.Group}"
  ok pStore.get('path') != gStore.get('path')
  p1 = App.PController.find 1
  equal p1.get('_path'), "#{pStore.get('path')}.#{Ember.guidFor p1}"
  p2 = App.PController.find 2
  equal p2.get('_path'), "#{pStore.get('path')}.#{Ember.guidFor p2}"
  ok p1.get('_path') != p2.get('_path')

test "Proper array handling", ->
  App.PController.load
    id: 92
    firstName: 'dil'
    lastName: 'bert'
  ps = App.PController.find [1,2,92]

  equal ps.get('length'), 3, "All 3 are returned"

  ps.removeAt(1)
  equal ps.get('length'), 2
  ps.insertAt(0, App.PController.find 2)
  equal ps.get('length'), 3

  con = Em.Object.create
    acontent: ps
    alength: (->
      ps.get('length')
    ).property('acontent.@each')
  Em.run.sync()
  equal con.get('alength'), 3, "Array is properly linked"
  ps.removeAt(1)
  Em.run.sync()
  equal con.get('alength'), 2,  "Only two elements are left"

  p92 = App.PController.find 92
  App.PController.remove p92
  Em.run.sync()
  equal con.get('alength'), 1,  "Directly from store removed element also dissappears in array and bindings of the array"

  #asyncTest "Remote content retrieval", ->
test "Remote content retrieval", ->
  #start()
  server = @sandbox.useFakeServer()
  respondServerSuccess server, 'user', {id: 55, firstName: 'new', lastName: 'newaswell'}
  p55 = App.PController.find 55
  equal p55.get('_status'), 'loading', 'Test status loading'
  server.respond()
  equal p55.get('_status'), 'loaded', 'Test status loaded'
  equal p55.get('id'), 55
  equal p55.get("firstName"), 'new'
  equal p55.get("lastName"), 'newaswell'

  #make sure it is not loaded a second time when the same level is requested
  @spy App.PController, '_get'
  p55v2 = App.PController.find 55
  equal App.PController._get.called, false
  equal p55, p55v2

test "Remote content retrieval failed", ->
  server = @sandbox.useFakeServer()
  respondServerError server, 'user', 101, 404 
  p101 = App.PController.find 101
  server.respond()
  equal p101.get('_status'), 'error', 'Test status error'

  #make sure it is loaded again when requested
  @spy App.PController, '_get'
  p101v2 = App.PController.find 101
  equal App.PController._get.called, true

test "Inline remote content retrieval", ->
  server = @sandbox.useFakeServer()
  respondServerSuccess server, 'group', {id: 33, name: 'newgroup', members: [77, 78]}
  respondServerSuccess server, 'user', {id: 77, firstName: 'mik', lastName: "muck"}
  respondServerSuccess server, 'user', {id: 78, firstName: 'ika', lastName: "rus"}
  window.g33 = App.GController.find 33
  server.respond()
  equal g33.get('name'), 'newgroup'
  equal g33.get('members').get('length'), 2
  p77 = g33.get('members').objectAt(0)
  checkP p77, 77, 'mik', 'muck'

  p78 = g33.get('members').objectAt(1)
  checkP p78, 78, 'ika', 'rus'


test "Inline content loading", ->
  altGController = TD.Controller.create
    type: App.Group
    urls: {basic: '/ember-thin-data/test/data/group/%id'}
    init: ->
      @_super()
      @deserializer['members'] = (ids) -> App.PController.load ids

  @spy App.PController, '_get'
  @spy App.GController, '_get'
  @spy altGController, '_get'

  altGController.load [
    id: 39
    name: "Group39"
    members: [
      id: 87 
      firstName: "nr87"
      lastName: "eighty"
    ,
      id: 88 
      firstName: "nr88"
      lastName: "double8"
    ]
  ]
 
  g39 = App.GController.find 39
  equal g39.get('id'), 39
  equal g39.get('name'), 'Group39'
  equal g39.get('members').get('length'), 2

  p87 = App.PController.find 87
  checkP p87, 87, 'nr87', 'eighty'

  p88 = App.PController.find 88
  checkP p88, 88, 'nr88', 'double8'

  equal g39.get('members').objectAt(0), p87
  equal g39.get('members').objectAt(1), p88

  #make sure no entry is loaded remotely
  equal App.PController._get.called, false
  equal App.GController._get.called, false
  equal altGController._get.called, false

test "Partial loading", ->
  server = @sandbox.useFakeServer()
  respondServerSuccess server, 'group-complete', {id: 1, admins: ['admin1']}
  @spy App.GController, '_get'
  g1 = App.GController.find 1, 'basic'
  equal App.GController._get.called, false, 'No call should happen as basic is already loaded'
  equal g1.get('admins'), null

  g1v1 = App.GController.find 1, 'complete'
  equal g1v1.get('_status'), 'loading'
  server.respond()
  equal g1v1.get('_status'), 'loaded'
  equal App.GController._get.called, true, 'Additional props should have been loaded'
  equal g1v1.get('admins').length, 1
  equal Em.guidFor(g1), Em.guidFor(g1v1), "Should be the same object"

test "Partial loading without partial information", ->
  g1 = App.GController.find 1, 'foo'
  equal g1.get('_status'), 'error'
  #undo error status because of partial loaded object
  g1.set('_status', 'loaded')

test "Objects loaded without URL should not be marked as error if they are available in the store", ->
  simpleCon =  TD.Controller.create
    type: App.Group
  g1 = simpleCon.find 1
  ok g1.get('_status') != 'error'
  g222 = simpleCon.find 222
  equal g222.get('_status'), 'error', 'Error should happen when the URL is not available and the object is not loaded'

test "Partial basic is by default always true when an object is loaded", ->
  App.Xyz = TD.Model.extend
    name: null
  simpleCon =  TD.Controller.create
    type: App.Xyz
  simpleCon.load [
    id: 1
  ]
  x1 = simpleCon.find 1
  equal x1.get("_partialbasic"),  true
