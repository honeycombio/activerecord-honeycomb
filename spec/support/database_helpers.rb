module DatabaseHelpers
  def connection
    @connection ||= ActiveRecord::Base.connection
  end

  def quote_table_name(table_name)
    connection.quote_table_name(table_name)
  end
end
