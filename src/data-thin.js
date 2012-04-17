var __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };
window.TD = Em.Namespace.create();
TD.Store = Em.Object.extend({
  type: null,
  map: null,
  init: function() {
    this._super();
    this.path = "TD.Stores." + (Ember.guidFor(this.type));
    return this.map = {};
  },
  add: function(obj) {
    var guid;
    guid = Ember.guidFor(obj);
    this.set(guid, obj);
    if (obj.id) {
      this.linkId(obj);
    }
    return guid;
  },
  linkId: function(obj) {
    this.map[obj.id] = obj;
    return obj.id;
  },
  getById: function(id) {
    return this.map[id];
  },
  remove: function(obj) {
    var guid;
    guid = Ember.guidFor(obj);
    this.set(guid, null);
    delete this[guid];
    if (obj.id) {
      delete this.map[obj.id];
    }
    return obj;
  }
});
TD.Stores = {
  getStore: function(typ) {
    var guid;
    guid = Ember.guidFor(typ);
    if (!this[guid]) {
      this[guid] = TD.Store.create({
        type: typ
      });
    }
    return this[guid];
  }
};
TD.Model = Em.Object.extend({
  _partial: null,
  _status: null,
  _path: null,
  init: function() {
    this.references = Em.A([]);
    this._status || (this._status = 'created');
    return this._super();
  },
  _path: (function() {
    return "" + (TD.Stores.getStore(this.constructor).path) + "." + (Ember.guidFor(this));
  }).property()
});
TD.ModelArray = Em.ArrayProxy.extend({
  store: null,
  destroy: function() {
    return this._super;
  },
  _observeStore: function(str, modeluid, val) {
    var i, item, _len, _ref, _results;
    _ref = this.content;
    _results = [];
    for (i = 0, _len = _ref.length; i < _len; i++) {
      item = _ref[i];
      if (Ember.guidFor(item) === modeluid) {
        _results.push(__bind(function(item, i) {
          return this.removeAt(i);
        }, this)(item, i));
      }
    }
    return _results;
  },
  arrayDidChange: function(array, index, removed, added) {
    var item, _i, _len, _ref, _results;
    this._super(array, index, removed, added);
    _ref = array.slice(index, index + added);
    _results = [];
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      item = _ref[_i];
      _results.push(Ember.addObserver(this.store, Ember.guidFor(item), this, this._observeStore));
    }
    return _results;
  },
  arrayWillChange: function(array, index, removed, added) {
    var item, _i, _len, _ref, _results;
    this._super(array, index, removed, added);
    _ref = array.slice(index, index + added);
    _results = [];
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      item = _ref[_i];
      _results.push(Ember.removeObserver(this.store, Ember.guidFor(item), this, this._observeStore));
    }
    return _results;
  }
});
TD.Controller = Em.Object.extend({
  store: null,
  type: null,
  init: function() {
    this.store = TD.Stores.getStore(this.type);
    this.deserializer = {};
    return this._super();
  },
  deserialize: function(model, key, prop) {
    model.set(key, this.deserializer[key] ? this.deserializer[key](prop) : prop);
    return model;
  },
  find: function(id) {
    var arr, idx;
    if (Em.isArray(id)) {
      arr = (function() {
        var _i, _len, _results;
        _results = [];
        for (_i = 0, _len = id.length; _i < _len; _i++) {
          idx = id[_i];
          _results.push(this.findOne(idx));
        }
        return _results;
      }).call(this);
      return TD.ModelArray.create({
        store: this.store,
        content: arr
      });
    } else {
      return this.findOne(id);
    }
  },
  findOne: function(id) {
    var _ref;
    return (_ref = this.store.getById(id)) != null ? _ref : this.type.create({
      _status: 'loading'
    });
  },
  load: function(obj) {
    var objx, _i, _len, _results;
    if (Em.isArray(obj)) {
      _results = [];
      for (_i = 0, _len = obj.length; _i < _len; _i++) {
        objx = obj[_i];
        _results.push(this.loadOne(objx));
      }
      return _results;
    } else {
      return this.loadOne(obj);
    }
  },
  loadOne: function(obj) {
    var key, model, prop;
    model = this.type.create({
      _status: 'loaded'
    });
    for (key in obj) {
      prop = obj[key];
      this.deserialize(model, key, prop);
    }
    this.store.add(model);
    return model;
  },
  remove: function(obj) {
    return this.store.remove(obj);
  }
});