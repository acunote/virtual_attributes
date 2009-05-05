# Copyright (c) 2008-2009 Pluron, Inc.

#Module containing functions to define virtual attributes.
module VirtualAttributes

    def reload!
        self.class.virtual_attribute_names.each do |attr|
            unset_virtual_attribute attr
        end
        reload
    end

    def self.included(base)
        base.extend(ClassMethods)
        base.send(:create_introspection_methods)
        base.send(:rewrite_clone_method)
        base.send(:create_accessors)
    end

    module ClassMethods
        def virtual_attribute(name, options = {})
            name = name.to_sym
            @virtual_attribute_names ||= []
            @virtual_attribute_names << name

            define_before_create_callbacks(name, options[:default])
            define_after_save_callbacks(name, options[:on_change])
        end

        def virtual_attributes(*args)
            @virtual_attribute_names ||= []
            @virtual_attribute_names += args

            @virtual_attribute_names.each do |name|
                define_after_save_callbacks(name, nil)
            end
        end

        def virtual_attribute_names
            @virtual_attribute_names
        end

    private

        def create_accessors
            define_method(:read_virtual_attribute) do |attr_name|
                @virtual_attributes ||= {}
                if @virtual_attributes.has_key? attr_name
                    @virtual_attributes[attr_name]
                else
                    nil
                end
            end

            define_method(:read_old_virtual_attribute) do |attr_name|
                @old_virtual_attributes ||= {}
                if @old_virtual_attributes.has_key? attr_name
                    @old_virtual_attributes[attr_name]
                else
                    nil
                end
            end

            define_method(:write_virtual_attribute) do |attr_name, attr_value|
                @virtual_attributes ||= {}

                if @virtual_attributes.has_key? attr_name
                    @old_virtual_attributes ||= {}
                    @old_virtual_attributes[attr_name] = read_virtual_attribute(attr_name)
                end

                @virtual_attributes[attr_name] = attr_value

                @changed_virtual_attributes ||= {}
                @changed_virtual_attributes[attr_name] = true
            end

            define_method(:initialize_virtual_attribute) do |attr_name, attr_value|
                @virtual_attributes ||= {}
                @virtual_attributes[attr_name] = attr_value
            end
        end

        def define_before_create_callbacks(name, default)
            callback = "set_#{name}_virtual_attribute_before_create".to_sym
            define_method(callback) do
                unless virtual_attribute_set? name
                    if default.nil?
                        initialize_virtual_attribute(name, default)
                    else
                        write_virtual_attribute(name, default)
                    end
                end
            end
            before_create callback
        end

        def define_after_save_callbacks(name, on_change)
            callback = "execute_on_change_after_changing_#{name}_virtual_attribute".to_sym
            define_method(callback) do
                return unless virtual_attribute_changed?(name)
                if on_change.class == Symbol
                    self.send(on_change, read_virtual_attribute(name))
                elsif on_change.class == Proc
                    on_change.call(self, read_virtual_attribute(name))
                end
                @changed_virtual_attributes.delete(name)
                @old_virtual_attributes.delete(name) if old_virtual_attribute_set? name
            end
            after_save callback
        end

        def create_introspection_methods
            define_method(:virtual_attribute_set?) do |attr_name|
                @virtual_attributes ||= {}
                @virtual_attributes.has_key? attr_name
            end

            define_method(:old_virtual_attribute_set?) do |attr_name|
                @old_virtual_attributes ||= {}
                @old_virtual_attributes.has_key? attr_name
            end

            define_method(:virtual_attribute_changed?) do |attr_name|
                @changed_virtual_attributes ||= {}
                @changed_virtual_attributes[attr_name]
            end

            define_method(:unset_virtual_attribute) do |attr_name|
                @virtual_attributes ||= {}
                @virtual_attributes.delete(attr_name)
            end

            define_method(:virtual_attributes) do
                @virtual_attributes ||= {}
            end
        end

        def rewrite_clone_method
            define_method(:clone_with_virtual_attribute_copying) do
                new_object = clone_without_virtual_attribute_copying
                new_object.instance_variable_set(:@virtual_attributes, @virtual_attributes.clone) if @virtual_attributes
                new_object
            end
            alias_method_chain :clone, :virtual_attribute_copying
        end

    end

end
