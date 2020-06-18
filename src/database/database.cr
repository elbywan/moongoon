require "./scripts"

# Used to connect to a MongoDB database instance.
module Moongoon::Database
  macro extended
    @@before_connect_blocks : Array(Proc(Nil)) = [] of Proc(Nil)
    @@after_connect_blocks : Array(Proc(Nil)) = [] of Proc(Nil)
    @@after_scripts_blocks : Array(Proc(Nil)) = [] of Proc(Nil)

    # Retrieves the mongodb driver client that can be used to perform low level queries
    #
    # See: [https://github.com/elbywan/cryomongo](https://github.com/elbywan/cryomongo)
    #
    # ```
    # cursor = Moongoon.client["database"]["collection"].find({ "key": value })
    # puts cursor.to_a
    # ```
    class_getter! client : Mongo::Client

    # The name of the default database.
    class_getter! database_name : String

    # The default database instance that can be used to perform low level queries.
    #
    # See: [https://github.com/elbywan/cryomongo](https://github.com/elbywan/cryomongo)
    #
    # ```
    # db = Moongoon.database
    # collection = db["some_collection"]
    # data = collection.find query
    # pp data
    # ```
    class_getter database : Mongo::Database do
      client[database_name]
    end
  end

  # Acquires a database lock and yields the client and database objects.
  #
  # Will acquire a lock named *lock_name*, polling the DB every *delay* to check the lock status.
  # If *abort_if_locked* is true the block will not be executed and this method will return if the lock is acquired already.
  #
  # ```
  # # If another connection uses the "query" lock, it will wait
  # # until this block has completed before perfoming its own work.
  # Moongoon.connection_with_lock "query" { |client, db|
  #   collection = db["some_collection"]
  #   data = collection.find query
  #   pp data
  # }
  # ```
  def connection_with_lock(lock_name : String, *, delay = 0.5.seconds, abort_if_locked = false, &block : Proc(Mongo::Client, Mongo::Database, Nil))
    loop do
      begin
        # Acquire lock
        lock = database["_locks"].find_one_and_update(
          filter: {_id: lock_name},
          update: {"$setOnInsert": {date: Time.utc}},
          upsert: true,
          write_concern: Mongo::WriteConcern.new(w: "majority")
        )
        return if abort_if_locked && lock
        break unless lock
      rescue
        # Possible upsert concurrency error
      end
      # Wait until the lock is released
      sleep delay
    end
    begin
      # Perform the operation
      block.call(client, database)
    ensure
      # Unlock
      database["_locks"].delete_one(
        {_id: lock_name},
        write_concern: Mongo::WriteConcern.new(w: "majority")
      )
    end
  end

  # Connects to MongoDB.
  #
  # ```
  # # Arguments are all optional, their default values are the ones defined below:
  # Moongoon.connect("mongodb://localhost:27017", "database", reconnection_delay: 5.seconds)
  # ```
  def connect(database_url : String = "mongodb://localhost:27017",  database_name : String = "database", *, reconnection_delay = 5.seconds)
    @@database_name = database_name
    @@before_connect_blocks.each &.call

    ::Moongoon::Log.info { "Connecting to MongoDB @ #{database_url}" }

    client = Mongo::Client.new(database_url)
    @@client = client

    ::Moongoon::Log.info { "Using database #{database_name} as default." }
    loop do
      begin
        client.command(Mongo::Commands::Ping)
        # status = client.server_status
        # uptime = Time::Span.new seconds: status["uptime"].as(Float64).to_i32, nanoseconds: 0
        # ::Moongoon::Log.info { "Connected to MongoDB. Server version: #{status["version"]}, uptime: #{uptime}" }
        ::Moongoon::Log.info { "Connected to MongoDB." }
        break
      rescue error
        ::Moongoon::Log.error { "#{error}\nCould not connect to MongoDB, retrying in #{reconnection_delay} second(s)." }
        sleep reconnection_delay
      end
    end

    @@after_connect_blocks.each &.call
    Scripts.process
    @@after_scripts_blocks.each &.call
  end

  # Pass a block that will get executed before the server tries to connect to the database.
  #
  # ```
  # Moongoon::Database.before_connect {
  #   puts "Before connecting…"
  # }
  # ```
  def before_connect(&block : Proc(Nil))
    @@before_connect_blocks << block
  end

  # Pass a block that will get executed after the database has been successfully connected but before the scripts are run.
  #
  # ```
  # Moongoon::Database.after_connect_before_scripts {
  #   # ... #
  # }
  # ```
  def after_connect_before_scripts(&block : Proc(Nil))
    @@after_connect_blocks << block
  end

  # Pass a block that will get executed after the database has been successfully connected and after the scripts are run.
  #
  # ```
  # Moongoon::Database.after_connect {
  #   # ... #
  # }
  # ```
  def after_connect(&block : Proc(Nil))
    @@after_scripts_blocks << block
  end
end
