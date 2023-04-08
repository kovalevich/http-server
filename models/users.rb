require 'json'
class Model
  def initialize(name)
    @name = name
  end

  def get_all
    data = File.read(file_name)
    JSON(data)
  end

  def get(id)
    items = get_all
    items.find { |i| i['id'] == id }
  end

  def create(item)
    all = get_all
    all << item
    File.write(file_name, JSON(all))
  end

  def file_name
    File.join('db_folder', @name)
  end
end

class User < Model
  def initialize
    super('users')
  end
end