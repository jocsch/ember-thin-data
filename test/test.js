window.App = Em.Application.create();
App.Person = TD.Model.extend({
  firstName: null,
  lastName: null
});
App.Group = TD.Model.extend({
  name: null,
  members: null
});
App.PController = TD.Controller.create({
  type: App.Person
});
App.GController = TD.Controller.create({
  type: App.Group,
  init: function() {
    this._super();
    return this.deserializer['members'] = function(ids) {
      return App.PController.find(ids);
    };
  }
});
App.PController.load([
  {
    id: 1,
    firstName: "abc",
    lastName: "def"
  }, {
    id: 2,
    firstName: "foo",
    lastName: "bar"
  }, {
    id: 3,
    firstName: "tinky",
    lastName: "no"
  }
]);
App.GController.load([
  {
    id: 1,
    name: "Group1",
    members: [1, 2]
  }, {
    id: 2,
    name: "Group2",
    members: [2, 3]
  }
]);
test("Test loaded people", function() {
  var store;
  store = App.PController.store;
  ok(store.getById(1) && store.getById(2) && store.getById(3), "Check correct nr of items");
  equal(store.getById(3).get('id'), 3, "Test id prop");
  equal(store.getById(3).get('firstName'), "tinky", "Test firstname prop");
  equal(store.getById(3).get('lastName'), "no", "Test lastname prop");
  equal(store.getById(3).get('_status'), "loaded", "Test status prop");
  return equal(store.getById(1).constructor, App.Person, "Check correct type loaded");
});
test("Test loaded groups", function() {
  var deepGroup, member, store;
  store = App.GController.store;
  ok(store.getById(1) && store.getById(2), "Check correct nr of items");
  deepGroup = store.getById(1);
  equal(deepGroup.constructor, App.Group, "Check group type");
  equal(deepGroup.get('id'), 1, "Test id prop");
  equal(deepGroup.get('name'), 'Group1', "Test id prop");
  equal(deepGroup.get('members').get('length'), 2, "Member array length");
  equal(deepGroup.get('_status'), 'loaded', "Test status prop");
  member = deepGroup.get('members').get('firstObject');
  equal(member.constructor, App.Person, "Check member type");
  return equal(member.get('_status'), "loaded", "Check member status");
});
test("Late id linking", function() {
  var guid, jP, store, tmpP;
  store = App.PController.store;
  jP = {
    firstName: "Bla",
    lastName: "Depp"
  };
  tmpP = App.PController.load(jP);
  guid = Ember.guidFor(tmpP);
  equal(store[guid], tmpP);
  tmpP.set('id', 91);
  store.linkId(tmpP);
  equal(store[guid], tmpP, "Should be same");
  equal(App.PController.findOne(91), tmpP);
  store.remove(tmpP);
  ok(!store[guid]);
  return ok(!store.map[91]);
});
test("Find", function() {
  var p1, p2, p99;
  p1 = App.PController.find(1);
  equal(p1.get("id"), 1);
  equal(p1.get("firstName"), "abc");
  equal(p1.get("_status"), "loaded");
  equal(p1.constructor, App.Person);
  p2 = App.PController.find(2);
  equal(p2.get("id"), 2);
  equal(p2.get("firstName"), "foo");
  equal(p2.constructor, App.Person);
  p99 = App.PController.find(99);
  equal(p99.get("id"), void 0, "Test object not in cache");
  return equal(p99.get("_status"), "loading", "Test status loading");
});
test("Same object is returned", function() {
  var con, g1, g2, m2, m2x, p2, p2x;
  p2 = App.PController.find(2);
  p2x = App.PController.find(2);
  g1 = App.GController.find(1);
  m2 = g1.get('members').filterProperty('id', 2)[0];
  g2 = App.GController.find(2);
  m2x = g2.get('members').filterProperty('id', 2).get('firstObject');
  ok(((p2 === p2x && p2x === m2) && m2 === m2x));
  con = Em.Object.create({
    nameBinding: m2x.get('_path') + '.firstName'
  });
  Em.run.sync();
  equal(con.get('name'), 'foo', "Binded property");
  p2.set('firstName', 'bar');
  Em.run.sync();
  equal(p2x.get('firstName'), 'bar', "Check direct reference");
  equal(m2x.get('firstName'), 'bar', "Check direct reference");
  equal(con.get('name'), 'bar', "Check that the binded property also is updated p2=m2x->con");
  p2.set('firstName', 'foo');
  return Em.run.sync();
});
test("Object has correct path", function() {
  var gStore, p1, p2, pStore;
  pStore = TD.Stores.getStore(App.Person);
  equal(pStore.get('path'), "TD.Stores." + (Em.guidFor(App.Person)));
  gStore = TD.Stores.getStore(App.Group);
  equal(gStore.get('path'), "TD.Stores." + (Em.guidFor(App.Group)));
  ok(pStore.get('path') !== gStore.get('path'));
  p1 = App.PController.find(1);
  equal(p1.get('_path'), "" + (pStore.get('path')) + "." + (Ember.guidFor(p1)));
  p2 = App.PController.find(2);
  equal(p2.get('_path'), "" + (pStore.get('path')) + "." + (Ember.guidFor(p2)));
  return ok(p1.get('_path') !== p2.get('_path'));
});
test("Proper array handling", function() {
  var con, p92, ps;
  App.PController.load({
    id: 92,
    firstName: 'dil',
    lastName: 'bert'
  });
  ps = App.PController.find([1, 2, 92]);
  equal(ps.get('length'), 3, "All 3 are returned");
  ps.removeAt(1);
  equal(ps.get('length'), 2);
  ps.insertAt(0, App.PController.find(2));
  equal(ps.get('length'), 3);
  con = Em.Object.create({
    acontent: ps,
    alength: (function() {
      return ps.get('length');
    }).property('acontent')
  });
  Em.run.sync();
  equal(con.get('alength'), 3, "Array is properly linked");
  ps.removeAt(1);
  Em.run.sync();
  equal(con.get('alength'), 2, "Only two elements are left");
  p92 = App.PController.find(92);
  App.PController.remove(p92);
  Em.run.sync();
  return equal(con.get('alength'), 1, "Directly from store removed element also dissappears in array and bindings of the array");
});