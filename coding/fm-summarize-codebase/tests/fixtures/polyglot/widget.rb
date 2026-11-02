# A shop.
module Shop
  class Widget < Base
    attr_reader :name

    # Creates a widget.
    def initialize(name)
      @name = name
      return unless name
    end

    def self.build(attrs = {})
      new(attrs[:name]).tap do |w|
        w.save if w.valid?
      end
    end

    def valid? = !name.nil?

    def to_s
      if name
        "Widget(#{name})"
      else
        "Widget"
      end
    end

    private

    def secret; end
  end

  def self.helper
    [1, 2].each { |x| puts x }
    while true do
      break
    end
  end
end
