require "./scripts"

# Used to connect to a MongoDB database instance.
module Moongoon::Database
  macro extended
    # Either a BSON response or an Exception that is returned from a database request through the libmongoc driver.
    alias DatabaseResponse = BSON | Exception

    @@before_connect_blocks : Array(Proc(Nil)) = [] of Proc(Nil)
    @@after_connect_blocks : Array(Proc(Nil)) = [] of Proc(Nil)
    @@after_scripts_blocks : Array(Proc(Nil)) = [] of Proc(Nil)
    @@pool : Mongo::ClientPool?

    @@database_name : String = "database"
    @@pool_size_lock : Channel(Nil) = Channel(Nil).new
  end

  # Retrieves a dabatase object that owns one of the connections in the pool.
  #
  # ```
  # Moongoon.connection { |db|
  #   collection = db["some_collection"]
  #   data = collection.find query
  #   pp data
  # }
  # ```
  def connection(&block : Proc(Mongo::Database, DatabaseResponse?)) : BSON?
    @@pool.try { |pool|
      @@pool_size_lock.send(nil)
      client = pool.pop
      client.setup_stream
      result = yield client[@@database_name]
      pool.push client
      @@pool_size_lock.receive
      raise result if result.is_a? Exception
      result
    }
  end

  # NOTE: Similar to `self.connection` but also acquires a lock.
  #
  # Will acquire a lock named *lock_name*, polling the DB every *delay* to check the lock status.
  # If *abort_if_locked* is true the block will not be executed and this method will return if the lock is acquired already.
  #
  # ```
  # # If another connection uses the "query" lock, it will wait
  # # until this block has completed before perfoming its own work.
  # Moongoon.connection_with_lock "query" {
  #   collection = db["some_collection"]
  #   data = collection.find query
  #   pp data
  # }
  # ```
  def connection_with_lock(lock_name : String, *, delay = 0.5.seconds, abort_if_locked = false, &block : Proc(Mongo::Database, DatabaseResponse?))
    loop do
      begin
        # Acquire lock
        lock = connection { |db|
          db["_locks"].find_and_modify(
            {_id: lock_name}.to_bson,
            {"$setOnInsert": {date: Time.utc}}.to_bson,
            upsert: true
          )
        }
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
      connection { |db| block.call(db) }
    ensure
      # Unlock
      connection { |db|
        db["_locks"].remove({_id: lock_name}.to_bson)
      }
    end
  end

  # Connects to a MongoDB database.
  #
  # Moongoon handles a pool of *max_pool_size* connections and will reconnect if the connection is lost after *reconnection_delay*.
  #
  # ```
  # # Arguments are all optional, their default values are the ones below:
  # Moongoon.connect("mongodb://localhost:27017", "database", max_pool_size: 100, reconnection_delay: 5.seconds)
  # ```
  def connect(database_url : String = "mongodb://localhost:27017", database_name : String = "database", *, max_pool_size = 100, reconnection_delay = 5.seconds)
    @@database_name = database_name
    @@pool_size_lock = Channel(Nil).new(max_pool_size)

    @@before_connect_blocks.each &.call

    ::Moongoon::Log.info { "Connecting to MongoDB @ #{database_url}" }

    pool = Mongo::ClientPool.new database_url
    @@pool = pool

    client = pool.pop
    client.setup_stream

    ::Moongoon::Log.info { "Using database #{database_name}" }
    loop do
      begin
        status = client.server_status
        uptime = Time::Span.new seconds: status["uptime"].as(Float64).to_i32, nanoseconds: 0
        ::Moongoon::Log.info { "Connected to MongoDB. Server version: #{status["version"]}, uptime: #{uptime}" }
        break
      rescue error
        ::Moongoon::Log.error { "#{error}\nCould not connect to MongoDB, retrying in #{reconnection_delay} second(s)." }
        sleep reconnection_delay
      end
    end

    pool.push client

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
