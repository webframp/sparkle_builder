module SparkleHelper
  # arg:: Object
  # Does a simple transition on types from Ruby to Javascript.
  def format_type_to_js(arg)
    case arg
    when Array
      "[#{arg.map{|value| format_type_to_js(value)}.join(',')}]"
    when Hash
      "{#{arg.map{ |key, value|
          k = key.is_a?(Symbol) ? key.to_s.camelize.sub(/^./, key.to_s[0,1].downcase) : format_type_to_js(key)
          "#{k}:#{format_type_to_js(value)}"
        }.join(',')}}"
    when Numeric
      arg.to_s
    when TrueClass
      arg.to_s
    when FalseClass
      arg.to_s
    when NilClass
      'null'
    when RawJS
      arg.to_s
    else
      arg.to_s.gsub(/\s+/, ' ') =~ %r{^\s*function\s*\(} ? arg.to_s : "'#{escape_javascript(arg.to_s)}'"
    end
  end

  class RawJS
    def initialize(s)
      @s = s
    end
    def to_s
      @s
    end
  end

end
