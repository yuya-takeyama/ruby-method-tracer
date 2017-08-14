require 'opentracing'

class Method
  module Tracer
    class ConfigError < StandardError; end

    class << self
      def included(klazz)
        klazz.extend(ClassMethods)
      end

      def extended(klazz)
        klazz.extend(ClassMethods)
      end

      def tracer
        @tracer || (raise ConfigError.new("Please configure the tracer using Method::Tracer.configure method"))
      end

      def active_span
        @active_span.respond_to?(:call) ? @active_span.call : @active_span
      end

      def configure(tracer: OpenTracing.global_tracer, active_span: nil)
        @tracer = tracer
        @active_span = active_span
      end

      def trace(operation_name, **args,  &block)
        args[:child_of] = active_span unless args.include?(:child_of)
        current_span = tracer.start_span(operation_name, **args)

        yield current_span
      rescue Exception => e
        if current_span
          current_span.set_tag('error', true)
          current_span.log(event: 'error', :'error.object' => e)
        end
        raise
      ensure
        current_span&.finish
      end

      def trace_method(klazz, method_name, **args, &block)
        trace("#{klazz.to_s}##{method_name.to_s}", **args, &block)
      end
    end

    module ClassMethods
      def guess_class_name
        return self.name if self.name && !self.name.empty?
        self.to_s
      end

      def trace_method(*methods)
        methods.each do |method_name|
          method_name_without_instrumentation = "#{method_name}_without_instrumentation".to_sym
          class_name = guess_class_name
          class_eval do
            alias_method method_name_without_instrumentation, method_name

            define_method(method_name) do |*args, &block|
              ::Method::Tracer.trace_method(class_name, method_name) do
                send(method_name_without_instrumentation, *args, &block)
              end
            end
          end
        end
      end
    end

  end
end
