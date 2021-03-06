class AvroError < StandardError
  attr_reader :object

  def initialize(object)
    @object = object
  end
end

class ScsbError < StandardError
  attr_reader :object

  def initialize(object)
    @object = object
  end
end

class ScsbNoMatchError < ScsbError
  attr_reader :object

  def initialize(object)
    @object = object
  end
end
