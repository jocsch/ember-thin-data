
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
    if (obj.id) this.linkId(obj);
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
    if (obj.id) delete this.map[obj.id];
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
  _status: null,
  _path: null,
  _partialbasic: (function() {
    return this.get('_status') === 'loaded';
  }).property('_status'),
  init: function() {
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
    return this._super();
  },
  _observeStore: function(str, modeluid, val) {
    var i, item, _len, _ref, _results,
      _this = this;
    _ref = this.content;
    _results = [];
    for (i = 0, _len = _ref.length; i < _len; i++) {
      item = _ref[i];
      if (Ember.guidFor(item) === modeluid) {
        _results.push((function(item, i) {
          return _this.removeAt(i);
        })(item, i));
      }
    }
    return _results;
  },
  _addObserver: function(item) {
    return Ember.addObserver(this.store, Ember.guidFor(item), this, this._observeStore);
  },
  contentArrayDidChange: function(array, index, removed, added) {
    var item, _i, _len, _ref, _results;
    this._super(array, index, removed, added);
    _ref = array.slice(index, (index + added));
    _results = [];
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      item = _ref[_i];
      _results.push(this._addObserver(item));
    }
    return _results;
  },
  contentArrayWillChange: function(array, index, removed, added) {
    var item, _i, _len, _ref, _results;
    this._super(array, index, removed, added);
    _ref = array.slice(index, (index + added));
    _results = [];
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      item = _ref[_i];
      _results.push(Ember.removeObserver(this.store, Ember.guidFor(item), this, this._observeStore));
    }
    return _results;
  },
  init: function() {
    this._super();
    return this.get('content').forEach(function(item) {
      return this._addObserver(item);
    }, this);
  }
});

TD.Controller = Em.Object.extend({
  store: null,
  type: null,
  urls: null,
  init: function() {
    this.store = TD.Stores.getStore(this.type);
    this.deserializer = {};
    this.urls || (this.urls = {});
    return this._super();
  },
  deserialize: function(model, key, prop) {
    model.set(key, this.deserializer[key] ? this.deserializer[key](prop) : prop);
    return model;
  },
  find: function(id, partial) {
    var arr, idx;
    if (partial == null) partial = 'basic';
    if (Em.isArray(id)) {
      arr = (function() {
        var _i, _len, _results;
        _results = [];
        for (_i = 0, _len = id.length; _i < _len; _i++) {
          idx = id[_i];
          _results.push(this.findOne(idx, partial));
        }
        return _results;
      }).call(this);
      return TD.ModelArray.create({
        store: this.store,
        content: arr
      });
    } else {
      return this.findOne(id, partial);
    }
  },
  findOne: function(id, partial) {
    var obj;
    if (partial == null) partial = 'basic';
    obj = this.store.getById(id);
    if (obj && obj.get('_status') !== 'error' && obj.get("_partial" + partial)) {
      return obj;
    } else {
      if (!obj) {
        obj = this.type.create({
          _status: 'loading',
          id: id
        });
        this.store.add(obj);
      }
      obj.set('_status', 'loading');
      this._get(obj, partial);
      return obj;
    }
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
  loadOne: function(obj, model) {
    var key, prop;
    if (model == null) model = this.type.create();
    model.set('_status', 'loaded');
    for (key in obj) {
      prop = obj[key];
      this.deserialize(model, key, prop);
    }
    this.store.add(model);
    return model;
  },
  remove: function(obj) {
    return this.store.remove(obj);
  },
  _get: function(obj, partial) {
    var url,
      _this = this;
    url = this.urls[partial];
    if (!url) {
      console.error("No url defined for <" + this.type + "> and partial <" + partial + ">");
      obj.set('_status', 'error');
      return;
    }
    url = url.replace(/%id/, obj.id);
    return $.get(url).success(function(resp) {
      return _this.loadOne(resp, obj);
    }).error(function() {
      obj.set('_status', 'error');
      return console.log("failure", arguments);
    });
  }
});
