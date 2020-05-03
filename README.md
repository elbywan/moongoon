# moongoon | [![Build Status](https://travis-ci.org/elbywan/moongoon.svg?branch=master)](https://travis-ci.org/elbywan/moongoon)

A MongoDB object-document mapper (ODM) library written in crystal which makes interacting with MongoDB or DocumentDB a breeze.

Uses the [`mongo.cr`](https://github.com/elbywan/mongo.cr) library under the hood that relies on the official [`MongoDB C Driver`](http://mongoc.org).

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     moongoon:
       github: elbywan/moongoon
   ```

2. **Important:** Install the official [`MongoDB C Driver`](http://mongoc.org/libmongoc/current/installing.html) shared library *(>= 1.15.1)*.

3. Run `shards install`

## Usage

### Minimal working example

```crystal
require "moongoon"

# A Model inherits from `Moongoon::Collection`
struct User < Moongoon::Collection
  collection "users"

  index name: 1, age: 1, options: { unique: true }

  property name : String
  property age : Int32
  property pets : Array(Pet)

  # Nested models inherit from `Moongoon::Document`
  struct Pet < Moongoon::Document
    property pet_name : String
  end
end

# Connect to the mongodb instance.
Moongoon.connect("mongodb://localhost:27017", database_name: "my_database")

# Initialize a model from arguments…
user = User.new(name: "Eric", age: 10, pets: [
  User::Pet.new(pet_name: "Mr. Kitty"),
  User::Pet.new(pet_name: "Fluffy")
])
# …or JSON data…
user = User.from_json(%(
  "name": "Eric",
  "age": 10,
  "pets": [
    { "pet_name": "Mr. Kitty" },
    { "pet_name": "Fluffy" }
  ]
))
# …or from querying the database.
user = User.find_one!({ name: "Eric" })

# Insert a model in the database.
user.insert

# Modify it.
user.name = "Kyle"
user.update

# Delete it.
user.remove
```

### Connecting

[**API documentation**](https://elbywan.github.io/moongoon/Moongoon/Database.html)

- [Initial connection](https://elbywan.github.io/moongoon/Moongoon/Database.html#connect(database_url%3AString%3D%26quot%3Bmongodb%3A%2F%2Flocalhost%3A27017%26quot%3B%2Cdatabase_name%3AString%3D%26quot%3Bdatabase%26quot%3B%2C*%2Cmax_pool_size%3D100%2Creconnection_delay%3D5.seconds)-instance-method)
- [Hooks](https://elbywan.github.io/moongoon/Moongoon/Database.html#after_connect(&block:Proc(Nil))-instance-method)
- [Low-level](https://elbywan.github.io/moongoon/Moongoon/Database.html#connection(&block:Proc(Mongo::Database,DatabaseResponse?)):BSON?-instance-method)

```crystal
require "moongoon"

Moongoon.before_connect {
  puts "Connecting…"
}
Moongoon.after_connect {
  puts "Connected!"
}

# … #

Moongoon.connect(
  database_url: "mongodb://address:27017",
  database_name: "my_database"
)

# In case you need to perform a low level query:
Moongoon.connection { |db|
  # "db" is a raw Mongo::Database instance.
  # Check `mongo.cr` code for more details:
  # https://github.com/elbywan/mongo.cr/blob/master/src/mongo/database.cr
  # https://github.com/elbywan/mongo.cr/blob/master/src/mongo/collection.cr
  cursor = db["my_collection"].find_indexes
  while index = cursor.next
    pp index
  end
}
```

### Models

[**API documentation**](https://elbywan.github.io/moongoon/Moongoon/Collection.html)

- [Indexes](https://elbywan.github.io/moongoon/Moongoon/Collection.html#index(keys:Hash(String,BSON::ValueType),collection:String=@@collection,options=Hash(String,BSON::ValueType).new,index_name:String?=nil):Nil-class-method)
- [Relationships](https://elbywan.github.io/moongoon/Moongoon/Collection.html#reference(field,*,model,many=false,delete_cascade=false,removal_sync=false,back_reference=nil)-macro)
- [Aggregations](https://elbywan.github.io/moongoon/Moongoon/Collection.html#aggregation_pipeline(*args)-class-method)
- [Versioning](https://elbywan.github.io/moongoon/Moongoon/Collection/Versioning.html#versioning(id_field=nil,auto=false)-macro)

```crystal
require "moongoon"

struct MyModel < Moongoon::Collection
  collection "models"

  # Define indexes
  index name: 1

  # Specify agregation pipeline stages that will automatically be used for queries.
  aggregation_pipeline(
    {
      "$addFields": {
        count: {
          "$size": "$array"
        }
      }
    },
    {
      "$project": {
        array: 0
      }
    }
  )

  # Collection fields
  property name : String
  property count : Int32?
  property array : Array(Int32)? = [1, 2, 3]
end

# …assuming moongoon is connected… #

MyModel.clear

model = MyModel.new(
  name: "hello"
).insert
model_id = model.id.not_nil!

puts MyModel.find_by_id(model_id).to_json
# => "{\"_id\":\"5ea052ce85ed2a2e1d0c87a2\",\"name\":\"hello\",\"count\":3}"

model.name = "good night"
model.update

puts MyModel.find_by_id(model_id).to_json
# => "{\"_id\":\"5ea052ce85ed2a2e1d0c87a2\",\"name\":\"good night\",\"count\":3}"

model.remove
puts MyModel.count
# => 0
```

### Running scripts

[**API documentation**](https://elbywan.github.io/moongoon/Moongoon/Database/Scripts/Base.html)

```crystal
# A script must inherit from `Moongoon::Database::Scripts::Base`
# Requiring the script before connecting to the database should be all it takes to register it.
#
# Scripts are then processed automatically.
struct Moongoon::Database::Scripts::Test < Moongoon::Database::Scripts::Base
  # Scripts run in ascending order.
  # Default order if not specified is 1.
  order Time.utc(2020, 3, 11).to_unix

  def process(db : Mongo::Database)
    # Dummy code that will add a ban flag for users that are called 'John'.
    # This code uses the `mongo.cr` driver shard syntax, but Models could
    # be used for convenience despite a small performance overhead.
    db["users"].update(
      selector: {name: "John"},
      update: {"$set": {"banned": true}},
      flags: LibMongoC::UpdateFlags::MULTI_UPDATE
    )
  end
end
```

## Contributing

1. Fork it (<https://github.com/your-github-user/moongoon/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [elbywan](https://github.com/your-github-user) - creator and maintainer
