# :nodoc:
module Moongoon::Traits::Database::Internal
  extend self

  # Query builders #

  protected def self.format_query(query, order_by)
    {
      "$query"   => query.to_bson,
      "$orderby" => order_by.to_bson,
    }
  end

  protected def self.format_aggregation(query, stages, fields = nil, order_by = nil, skip = 0, limit = 0)
    pipeline = [
      {"$match" => query}.to_bson,
    ]
    stages.each { |stage|
      pipeline << stage.to_bson
    }
    if fields
      pipeline << {"$project": fields}.to_bson
    end
    if order_by
      pipeline << {"$sort": order_by}.to_bson
    end
    if skip > 0
      pipeline << {"$skip": skip.to_i32}.to_bson
    end
    if limit > 0
      pipeline << {"$limit": limit.to_i32}.to_bson
    end
    pipeline
  end

  protected def self.build_id_filter(id)
    {"_id" => BSON::ObjectId.new id}.to_bson
  end

  protected def self.build_ids_filter(ids)
    {
      "_id" => {
        "$in" => ids.map { |id|
          BSON::ObjectId.new id
        },
      },
    }.to_bson
  end

  # Validation helpers #

  # Raises if the Model has a nil id field.
  private def id_check!
    raise ::Moongoon::Error::NotFound.new unless self._id
  end
end
