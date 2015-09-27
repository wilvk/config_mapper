module ConfigMapper

  # A configuration container
  #
  class ConfigStruct

    class << self

      # Defines reader and writer methods for the specified attribute.
      #
      # A `:default` value may be specified; otherwise, the attribute is
      # considered mandatory.
      #
      # If a block is provided, it will invoked in the writer-method to
      # validate the argument.
      #
      # @param name [Symbol] attribute name
      # @param type [Symbol] name of type-coercion method
      # @options options [String] :default (nil) default value
      # @yield type-coercion block
      #
      def attribute(name, type = nil, options = {}, &coerce_block)
        name = name.to_sym
        if options.empty? && type.is_a?(Hash)
          options = type
          type = nil
        end
        coerce_block = method(type) if type
        if options.key?(:default)
          default_value = options.fetch(:default).freeze
          attribute_initializers[name] = proc { default_value }
        else
          required_attributes << name
        end
        attr_reader(name)
        if coerce_block
          define_method("#{name}=") do |arg|
            instance_variable_set("@#{name}", coerce_block.call(arg))
          end
        else
          attr_writer(name)
        end
      end

      # Defines a sub-component.
      #
      def component(name, component_class = ConfigStruct, &block)
        name = name.to_sym
        declared_components << name
        component_class = Class.new(component_class, &block) if block
        attribute_initializers[name] = component_class.method(:new)
        attr_reader name
      end

      # Defines an associative array of sub-components.
      #
      def component_map(name, component_class = ConfigStruct, &block)
        name = name.to_sym
        declared_component_maps << name
        component_class = Class.new(component_class, &block) if block
        attribute_initializers[name] = lambda do
          Hash.new do |h, key|
            h[key] = component_class.new
          end
        end
        attr_reader name
      end

      def required_attributes
        @required_attributes ||= []
      end

      def attribute_initializers
        @attribute_initializers ||= {}
      end

      def declared_components
        @declared_components ||= []
      end

      def declared_component_maps
        @declared_component_maps ||= []
      end

    end

    def initialize
      self.class.attribute_initializers.each do |name, initializer|
        instance_variable_set("@#{name}", initializer.call)
      end
    end

    def undefined_attributes
      result = self.class.required_attributes.map(&:to_s).reject do |name|
        instance_variable_defined?("@#{name}")
      end
      components.each do |component_name, value|
        next unless value.respond_to?(:undefined_attributes)
        result += value.undefined_attributes.map do |name|
          "#{component_name}.#{name}"
        end
      end
      result
    end

    private

    def components
      {}.tap do |result|
        self.class.declared_components.each do |name|
          result[name] = instance_variable_get("@#{name}")
        end
        self.class.declared_component_maps.each do |name|
          instance_variable_get("@#{name}").each do |key, value|
            result["#{name}[#{key.inspect}]"] = value
          end
        end
      end
    end

  end

end
