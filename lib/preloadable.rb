# Copyright (c) 2008-2009 Pluron, Inc.

#Module containing functions used by models which need to preload associations
#or attributes from SQL query results.
module Preloadable

    #Preloads attribute and writes it to virtual attribute
    def preload_attribute(attribute)
        preloaded_attribute = "preloaded_#{attribute}"
        if has_attribute?(preloaded_attribute)
            preloaded_attribute_value = send(:read_attribute_before_type_cast, preloaded_attribute)
            initialize_virtual_attribute(attribute.to_sym, preloaded_attribute_value)
        end
    end

    def preload_association(model, options = {:set_association_target => true})
        association_name = model.to_s.downcase
        return [false, nil] unless has_attribute? "preloaded_#{association_name}_id"

        if self["preloaded_#{association_name}_id"].blank?
            preloaded_model = nil
        else
            preloaded_model = model.allocate
            attributes = {}
            model.columns.each do |col|
                attributes[col.name] = read_attribute_before_type_cast("preloaded_#{association_name}_#{col.name}")
            end
            preloaded_model.instance_variable_set("@attributes", attributes)
            preloaded_model.instance_variable_set("@attributes_cache", Hash.new)
        end

        send("set_#{association_name}_target", preloaded_model) if options[:set_association_target]
        return [true, preloaded_model]
    end

    def preload
        return if @attributes_preloaded
        preload_associations
        preload_virtual_attributes
        @attributes_preloaded = true
    end

    def preload_virtual_attributes
        self.class.preloadable_attributes.each do |attr|
            preload_attribute(attr)
        end
    end

    def preload_associations
        self.class.preloadable_associations.each do |attr|
            preload_association(attr.to_s.classify.constantize)
        end
    end

    def self.append_features(base)
        super
        base.extend(PreloadableClassMethods)
    end



    module PreloadableClassMethods

        def preloadable_attributes
            @@preloadable_attributes
        end

        def preloadable_associations
            @@preloadable_associations
        end

        #Redefines attribute reader methods to first preload attributes from SQL query results
        #and then return them.
        #Important! the model should define preload_associations and preload_virtual_attributes methods
        #in order to have this functionality working.
        def preloadable_attribute(*args)
            args.each do |arg|
                @@preloadable_attributes ||= []
                @@preloadable_attributes << arg
                define_method(arg.to_sym) do |*args|
                    preload
                    super(*args)
                end
                define_method("#{arg}=".to_sym) do |*args|
                    preload
                    super(*args)
                end
            end
        end

        def preloadable_association(*args)
            args.each do |arg|
                @@preloadable_associations ||= []
                @@preloadable_associations << arg
                alias_method "orig_#{arg}".to_sym, arg.to_sym
                define_method(arg.to_sym) do |*args|
                    preload
                    send("orig_#{arg}", *args)
                end
                alias_method "orig_#{arg}=".to_sym, "#{arg}=".to_sym
                define_method("#{arg}=".to_sym) do |*args|
                    preload
                    send("old_#{arg}=", *args)
                end
            end
        end

    end

end

ActiveRecord::Base.class_eval do
    include Preloadable
end
