# moongoon | [![Build Status](https://travis-ci.org/elbywan/moongoon.svg?branch=master)](https://travis-ci.org/elbywan/moongoon)

An object-document mapper (ODM) library written in Crystal which makes interacting with MongoDB a breeze.

This library relies on:
- [`cryomongo`](https://github.com/elbywan/cryomongo) as the underlying MongoDB driver.
- [`bson.cr`](https://github.com/elbywan/bson.cr) as the BSON implementation.

*For the moongoon version relying on the [`mongo.cr`](https://github.com/elbywan/mongo.cr) driver, please check the [mongo.cr](https://github.com/elbywan/moongoon/tree/mongo.cr) branch.*

## Installation

1. Add the dependency to your `shard.yml`:

```yaml
dependencies:
  moongoon:
    github: elbywan/moongoon
```

2. Run `shards install`

3. Profit! 💰

## Usage

### Minimal working example

```crystal
require "moongoon"

# A Model inherits from `Moongoon::Collection`
class User < Moongoon::Collection
  collection "users"

  index name: 1, age: 1, options: { unique: true }

  property name : String
  property age : Int32
  property pets : Array(Pet)

  # Nested models inherit from `Moongoon::Document`
  class Pet < Moongoon::Document
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

- [Initial connection](https://elbywan.github.io/moongoon/Moongoon/Database.html#connect(database_url:String="mongodb://localhost:27017",database_name:String="database",*,reconnection_delay=5.seconds)-instance-method)
- [Hooks](https://elbywan.github.io/moongoon/Moongoon/Database.html#after_connect(&block:Proc(Nil))-instance-method)
- [Low-level](https://elbywan.github.io/moongoon/Moongoon.html#client:Mongo::Client-class-method)

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

# In case you need to perform a low level query, use `Moongoon.client` or `Moongoon.database`.
# Here, *db* is a `cryomongo` Mongo::Database. (For more details, check the `cryomongo` documentation)
db = Moongoon.database
cursor = db["my_collection"].list_indexes
puts cursor.to_a.to_json
```

### Models

[**API documentation**](https://elbywan.github.io/moongoon/Moongoon/Collection.html)

- [Indexes](https://elbywan.github.io/moongoon/Moongoon/Collection.html#index(collection:String?=nil,database:String?=nil,options=NamedTuple.new,name:String?=nil,**keys):Nil-class-method)
- [Relationships](https://elbywan.github.io/moongoon/Moongoon/Collection.html#reference(field,*,model,many=false,delete_cascade=false,clear_reference=false,back_reference=nil)-macro)
- [Aggregations](https://elbywan.github.io/moongoon/Moongoon/Collection.html#aggregation_pipeline(*args)-class-method)
- [Versioning](https://elbywan.github.io/moongoon/Moongoon/Collection/Versioning.html#versioning(ref_field=nil,auto=false,&transform)-macro)

```crystal
require "moongoon"

class MyModel < Moongoon::Collection
  collection "models"

  # Note: the database can be changed - if different from the default one
  # database "database_name"

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
model_id = model.id!

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
class Moongoon::Database::Scripts::Test < Moongoon::Database::Scripts::Base
  # Scripts run in ascending order.
  # Default order if not specified is 1.
  order Time.utc(2020, 3, 11).to_unix

  def process(db : Mongo::Database)
    # Dummy code that will add a ban flag for users that are called 'John'.
    # This code uses the `cryomongo` syntax, but Models could
    # be used for convenience despite a small performance overhead.
    db["users"].update_many(
      filter: {name: "John"},
      update: {"$set": {"banned": true}}
    )
  end
end
```

## Contributing

1. Fork it (<https://github.com/elbywan/moongoon/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [elbywan](https://github.com/elbywan) - creator and maintainer
